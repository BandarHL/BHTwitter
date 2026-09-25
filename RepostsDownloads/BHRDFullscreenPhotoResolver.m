#import "BHRDFullscreenPhotoResolver.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDMediaResolver.h"
#import <AVFoundation/AVFoundation.h>
@implementation BHRDPhotoSnapshot @end
static NSValue *RectValue(CGRect rect) { return [NSValue value:&rect withObjCType:@encode(CGRect)]; }
static CGRect ReadRect(NSValue *value) { CGRect rect; [value getValue:&rect]; return rect; }
static BOOL Chrome(UIView *view) {
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    // Media can live inside a UIControl or SlideshowStatusView. Only prune
    // known chrome, never every Control/StatusView subtree.
    for (NSString *part in @[@"bhrd",@"backdrop",@"visualeffect",@"blur",@"inlineaction",@"author",@"username",@"replycomposer",@"quoted",@"quotetweet",@"playbutton"])
        if ([name containsString:part]) return YES;
    return NO;
}
static NSURL *PhotoURL(UIView *view, UIView *root, BOOL *video) {
    for (NSUInteger depth=0; view && depth<6; depth++,view=view.superview) {
        NSMutableArray *sources=[NSMutableArray arrayWithObject:view];
        NSHashTable *seen=[NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
        for (NSUInteger i=0;i<sources.count && i<24;i++) {
            id source=sources[i]; if ([seen containsObject:source]) continue; [seen addObject:source];
            id variants=BHRDMediaObject(BHRDMediaObject(source,@"videoInfo"),@"variants");
            if ([variants isKindOfClass:NSArray.class] && [variants count]) { *video=YES; return nil; }
            for (NSString *key in @[@"originalImageURL",@"fullSizeImageURL",@"imageURL",@"mediaURL",@"URL",@"url"]) {
                id value=BHRDMediaObject(source,key);
                NSURL *raw=[value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
                if ([raw.host.lowercaseString isEqual:@"video.twimg.com"] || ([raw.host.lowercaseString isEqual:@"pbs.twimg.com"] && [raw.path containsString:@"_video_thumb/"])) { *video=YES; return nil; }
                NSURL *url=BHRDOriginalPhotoURL(value); if (url) return url;
            }
            // Follow only a single displayed media object, never a post's image array.
            for (NSString *key in @[@"viewModel",@"imageViewModel",@"mediaEntity",@"currentMediaEntity",@"representedMediaEntity",@"imageRequest",@"imageResource",@"imageNode",@"asyncdisplaykit_node"]) {
                id child=BHRDMediaObject(source,key); if (child && child!=NSNull.null && ![child isKindOfClass:NSArray.class]) [sources addObject:child];
            }
        }
        if (view==root) break;
    }
    return nil;
}
static UIImage *LoadedImage(UIView *view) {
    NSArray *sources=@[view,BHRDMediaObject(view,@"imageNode") ?: NSNull.null,BHRDMediaObject(view,@"asyncdisplaykit_node") ?: NSNull.null];
    for (id source in sources) for (NSString *key in @[@"image",@"displayedImage",@"currentImage",@"loadedImage"]) {
        id image=BHRDMediaObject(source,key); if ([image isKindOfClass:UIImage.class]) return image;
    }
    // Texture/custom native image views often expose only CALayer.contents.
    // Copy the bitmap itself, not a screenshot containing controls or captions.
    id contents=view.layer.contents;
    if (contents && CFGetTypeID((__bridge CFTypeRef)contents)==CGImageGetTypeID()) {
        CGImageRef image=(__bridge CGImageRef)contents;
        if (CGImageGetWidth(image)>=64 && CGImageGetHeight(image)>=24) return [UIImage imageWithCGImage:image];
    }
    return nil;
}
BHRDPhotoSnapshot *BHRDCurrentFullscreenPhoto(UIView *root) {
    if (!root.window || CGRectIsEmpty(root.bounds)) return nil;
    CGPoint center=CGPointMake(CGRectGetMidX(root.bounds),CGRectGetMidY(root.bounds));
    NSMutableArray *pending=[NSMutableArray arrayWithObject:@{@"view":root,@"clip":RectValue(root.bounds)}];
    NSUInteger budget=600; BHRDPhotoSnapshot *best=nil; CGFloat bestArea=0;
    while (pending.count && budget--) {
        NSDictionary *node=pending.lastObject; [pending removeLastObject]; UIView *view=node[@"view"];
        if (view.hidden || view.alpha<=0.01 || Chrome(view)) continue;
        CGRect rect=[view convertRect:view.bounds toView:root], clip=ReadRect(node[@"clip"]);
        CGRect visible=CGRectIntersection(rect,clip);
        BOOL visibleView=!CGRectIsNull(visible) && !CGRectIsEmpty(visible);
        if (visibleView) {
            for (CALayer *layer in [@[view.layer] arrayByAddingObjectsFromArray:view.layer.sublayers ?: @[]]) {
                if ([layer isKindOfClass:AVPlayerLayer.class] && ((AVPlayerLayer *)layer).player.currentItem && !layer.hidden && layer.opacity>0.01) {
                    CGRect frame=CGRectIntersection([layer convertRect:layer.bounds toLayer:root.layer],clip);
                    if (frame.size.width>90 && frame.size.height>60 && CGRectContainsPoint(frame,center)) return nil;
                }
            }
            CGFloat area=visible.size.width*visible.size.height, fullArea=rect.size.width*rect.size.height;
            // A letterboxed/off-center photo can be above the screen midpoint.
            // Require substantial visibility rather than midpoint containment.
            BOOL horizontal=rect.size.width>0 && (visible.size.width/rect.size.width>=0.60 || visible.size.width>=root.bounds.size.width*0.85);
            BOOL dominant=horizontal && (area>=root.bounds.size.width*root.bounds.size.height*0.20 || (fullArea>0 && area/fullArea>=0.60));
            if (rect.size.width>=90 && rect.size.height>=40 && dominant) {
                UIImage *image=LoadedImage(view);
                NSString *name=NSStringFromClass(view.class).lowercaseString;
                BOOL mediaView=image || [view isKindOfClass:UIImageView.class] || [name containsString:@"imagedisplay"] || [name containsString:@"photoview"] || [name containsString:@"mediaview"];
                BOOL video=NO; NSURL *url=mediaView ? PhotoURL(view,root,&video) : nil;
                if (video && CGRectContainsPoint(visible,center)) return nil;
                if (!video && mediaView && (url || image) && (!best || (url && !best.url) || ((url!=nil)==(best.url!=nil) && area>bestArea))) {
                    best=[BHRDPhotoSnapshot new]; best.image=image; best.url=url;
                    best.identity=url.absoluteString ?: [NSString stringWithFormat:@"image:%p",image.CGImage ?: (__bridge void *)image]; bestArea=area;
                }
            }
        }
        CGRect childClip=view.clipsToBounds ? visible : clip;
        if (CGRectIsNull(childClip) || CGRectIsEmpty(childClip)) continue;
        for (UIView *child in view.subviews) [pending addObject:@{@"view":child,@"clip":RectValue(childClip)}];
    }
    return best;
}
