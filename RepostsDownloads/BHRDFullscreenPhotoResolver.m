#import "BHRDFullscreenPhotoResolver.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDMediaResolver.h"
#import <AVFoundation/AVFoundation.h>
@implementation BHRDPhotoSnapshot @end
static BOOL Excluded(UIView *view) {
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    for (NSString *part in @[@"bhrd",@"backdrop",@"visualeffect",@"blur",@"inlineaction",@"statusview",@"videoplayer",@"videodisplay",@"playbutton"]) if ([name containsString:part]) return YES;
    return [view isKindOfClass:UIControl.class];
}
static NSURL *PhotoURL(UIView *view, UIView *root, BOOL *video) {
    for (NSUInteger depth=0; view && view!=root && depth<6; depth++,view=view.superview) {
        id model=BHRDMediaObject(view,@"viewModel"),media=BHRDMediaObject(model,@"mediaEntity");
        for (id source in @[view,model ?: NSNull.null,media ?: NSNull.null]) {
            id variants=BHRDMediaObject(BHRDMediaObject(source,@"videoInfo"),@"variants");
            if ([variants isKindOfClass:NSArray.class] && [variants count]) { *video=YES; return nil; }
            for (NSString *key in @[@"originalImageURL",@"fullSizeImageURL",@"imageURL",@"mediaURL",@"URL"]) {
                id value=BHRDMediaObject(source,key);
                NSURL *raw=[value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
                if ([raw.host.lowercaseString isEqual:@"video.twimg.com"] || ([raw.host.lowercaseString isEqual:@"pbs.twimg.com"] && [raw.path containsString:@"_video_thumb/"])) { *video=YES; return nil; }
                NSURL *url=BHRDOriginalPhotoURL(value); if (url) return url;
            }
        }
    }
    return nil;
}
BHRDPhotoSnapshot *BHRDCurrentFullscreenPhoto(UIView *root) {
    if (!root.window) return nil;
    CGPoint center=CGPointMake(CGRectGetMidX(root.bounds),CGRectGetMidY(root.bounds));
    NSMutableArray *pending=[NSMutableArray arrayWithObject:root]; NSUInteger budget=400;
    BHRDPhotoSnapshot *best=nil; CGFloat bestArea=0;
    while (pending.count && budget--) {
        UIView *view=pending.lastObject; [pending removeLastObject];
        if (view.hidden || view.alpha<=0.01) continue;
        CGRect rect=[view convertRect:view.bounds toView:root];
        if (!CGRectIntersectsRect(rect,root.bounds)) continue;
        // A live central video always wins over its poster image.
        for (CALayer *layer in [@[view.layer] arrayByAddingObjectsFromArray:view.layer.sublayers ?: @[]]) {
            if ([layer isKindOfClass:AVPlayerLayer.class] && ((AVPlayerLayer *)layer).player.currentItem && !layer.hidden && layer.opacity>0.01) {
                CGRect frame=[layer convertRect:layer.bounds toLayer:root.layer];
                if (frame.size.width>90 && frame.size.height>60 && CGRectContainsPoint(frame,center)) return nil;
            }
        }
        if (Excluded(view)) continue;
        if (view!=root && rect.size.width>=90 && rect.size.height>=60 && CGRectContainsPoint(rect,center)) {
            id value=BHRDMediaObject(view,@"image");
            UIImage *image=[value isKindOfClass:UIImage.class] ? value : nil;
            NSString *name=NSStringFromClass(view.class).lowercaseString;
            BOOL mediaView=[view isKindOfClass:UIImageView.class] || [name containsString:@"imagedisplay"] || [name containsString:@"photoview"];
            BOOL video=NO;
            NSURL *url=mediaView ? PhotoURL(view,root,&video) : nil;
            if (video) return nil;
            CGFloat area=CGRectIntersection(rect,root.bounds).size.width*CGRectIntersection(rect,root.bounds).size.height;
            if (mediaView && (url || image) && (!best || (url && !best.url) || ((url!=nil)==(best.url!=nil) && area>bestArea))) {
                best=[BHRDPhotoSnapshot new]; best.image=image; best.url=url;
                best.identity=url.absoluteString ?: [NSString stringWithFormat:@"image:%p",image.CGImage ?: (__bridge void *)image];
                bestArea=area;
            }
        }
        [pending addObjectsFromArray:view.subviews];
    }
    return best;
}
