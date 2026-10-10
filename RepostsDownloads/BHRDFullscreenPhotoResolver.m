#import "BHRDFullscreenPhotoResolver.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDMediaResolver.h"
#import "BHRDAvatarDiagnostics.h"
#import <AVFoundation/AVFoundation.h>
#import <math.h>
#if BHRD_AVATAR_DIAGNOSTICS
#import <objc/runtime.h>
#endif
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
static UIImage *LoadedImage(UIView *view, NSString **sourceName) {
    NSArray *sources=@[view,BHRDMediaObject(view,@"imageNode") ?: NSNull.null,BHRDMediaObject(view,@"asyncdisplaykit_node") ?: NSNull.null];
    for (NSUInteger i=0;i<sources.count;i++) for (NSString *key in @[@"image",@"displayedImage",@"currentImage",@"loadedImage"]) {
        id image=BHRDMediaObject(sources[i],key);
        if ([image isKindOfClass:UIImage.class]) { if (sourceName) *sourceName=[(i==0 ? @"view" : i==1 ? @"imageNode" : @"asyncdisplaykit_node") stringByAppendingFormat:@".%@",key]; return image; }
    }
    // Texture/custom native image views often expose only CALayer.contents.
    // Copy the bitmap itself, not a screenshot containing controls or captions.
    id contents=view.layer.contents;
    if (contents && CFGetTypeID((__bridge CFTypeRef)contents)==CGImageGetTypeID()) {
        CGImageRef image=(__bridge CGImageRef)contents;
        if (CGImageGetWidth(image)>=64 && CGImageGetHeight(image)>=24) { if (sourceName) *sourceName=@"layer.contents"; return [UIImage imageWithCGImage:image]; }
    }
    return nil;
}
#if BHRD_AVATAR_DIAGNOSTICS
@interface BHRDPhotoDiagnosticSample : NSObject
@property(nonatomic) NSUInteger count;
@property(nonatomic) NSTimeInterval lastTime;
@property(nonatomic,copy) NSString *identity;
@end
@implementation BHRDPhotoDiagnosticSample @end
@interface BHRDPhotoDiagnosticState : NSObject
@property(nonatomic,strong) NSMapTable<UIView *,BHRDPhotoDiagnosticSample *> *samples;
@property(nonatomic,weak) UIView *selectedView;
@property(nonatomic) NSTimeInterval collectionEnd;
@property(nonatomic) NSUInteger total;
@end
@implementation BHRDPhotoDiagnosticState @end
static char PhotoDiagnosticKey;
static NSString *URLProbeReason(id value) {
    if (!value) return @"absent";
    if (![value isKindOfClass:NSURL.class] && ![value isKindOfClass:NSString.class]) return @"unsupported_type";
    NSURL *url=[value isKindOfClass:NSURL.class] ? value : [NSURL URLWithString:value];
    if (!url) return @"invalid_url";
    if ([url.host.lowercaseString isEqual:@"video.twimg.com"] || ([url.host.lowercaseString isEqual:@"pbs.twimg.com"] && [url.path containsString:@"_video_thumb/"])) return @"video_media";
    if (![url.scheme.lowercaseString isEqual:@"https"]) return @"unsupported_scheme";
    if (![url.host.lowercaseString isEqual:@"pbs.twimg.com"]) return @"unsupported_host";
    if (![url.path hasPrefix:@"/media/"] && ![url.path hasPrefix:@"/profile_images/"]) return @"unsupported_path";
    return BHRDOriginalPhotoURL(value) ? @"accepted" : @"unsupported_format";
}
static NSDictionary *Probe(NSString *getter, id value, NSString *reason) {
    return @{@"getter":getter,@"present":@(value!=nil),@"type":value ? NSStringFromClass([value class]) : @"",@"reason":reason};
}
static void DiagnoseSelectedPhoto(UIView *root, UIView *selected, BHRDPhotoSnapshot *photo, NSString *bitmapSource) {
    NSTimeInterval remaining=BHRDAvatarDetailedCollectionRemaining();
    if (remaining<=0) { objc_setAssociatedObject(root,&PhotoDiagnosticKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
    if (!selected || !photo) return;
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime, collectionEnd=now+remaining;
    BHRDPhotoDiagnosticState *state=objc_getAssociatedObject(root,&PhotoDiagnosticKey);
    if (!state || fabs(state.collectionEnd-collectionEnd)>1) {
        state=[BHRDPhotoDiagnosticState new]; state.samples=[NSMapTable weakToStrongObjectsMapTable]; state.collectionEnd=collectionEnd;
        objc_setAssociatedObject(root,&PhotoDiagnosticKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL selectionChanged=state.selectedView!=selected; state.selectedView=selected;
    BHRDPhotoDiagnosticSample *sample=[state.samples objectForKey:selected];
    if (!sample) { sample=[BHRDPhotoDiagnosticSample new]; [state.samples setObject:sample forKey:selected]; }
    // At most three samples per selected view and 48 per fullscreen owner in
    // one detailed-collection window. Polling cannot continuously fill logs.
    if (sample.count>=3 || state.total>=48) return;
    BOOL imageChanged=![sample.identity isEqual:photo.identity];
    NSTimeInterval delay=sample.count==1 ? 1 : 3;
    if (sample.count && !selectionChanged && !imageChanged && now-sample.lastTime<delay) return;
    sample.count++; sample.lastTime=now; sample.identity=photo.identity; state.total++;
    NSMutableArray *pending=[NSMutableArray array], *sources=[NSMutableArray array];
    for (UIView *view=selected; view && pending.count<6; view=view.superview) {
        [pending addObject:@{@"object":view,@"parentDepth":@(pending.count),@"path":@[]}];
        if (view==root) break;
    }
    NSHashTable *seen=[NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    NSUInteger index=0;
    while (index<pending.count && sources.count<16) {
        NSDictionary *entry=pending[index++]; id source=entry[@"object"];
        if ([seen containsObject:source]) continue; [seen addObject:source];
        NSMutableArray *probes=[NSMutableArray array];
        for (NSString *key in @[@"originalImageURL",@"fullSizeImageURL",@"imageURL",@"mediaURL",@"URL",@"url"]) {
            id value=BHRDMediaObject(source,key); [probes addObject:Probe(key,value,URLProbeReason(value))];
        }
        id videoInfo=BHRDMediaObject(source,@"videoInfo"), variants=BHRDMediaObject(videoInfo,@"variants");
        [probes addObject:Probe(@"videoInfo",videoInfo,videoInfo ? @"present" : @"absent")];
        [probes addObject:Probe(@"videoInfo.variants",variants,[variants isKindOfClass:NSArray.class] ? @"array_not_inspected" : variants ? @"unsupported_type" : @"absent")];
        for (NSString *key in @[@"viewModel",@"imageViewModel",@"mediaEntity",@"currentMediaEntity",@"representedMediaEntity",@"imageRequest",@"imageResource",@"imageNode",@"asyncdisplaykit_node"]) {
            id child=BHRDMediaObject(source,key); BOOL array=[child isKindOfClass:NSArray.class];
            BOOL follow=child && child!=NSNull.null && !array;
            [probes addObject:Probe(key,child,array ? @"array_ignored" : follow ? @"single_binding" : @"absent")];
            if (follow && pending.count<48) [pending addObject:@{@"object":child,@"parentDepth":entry[@"parentDepth"],@"path":[entry[@"path"] arrayByAddingObject:key]}];
        }
        [sources addObject:@{@"class":NSStringFromClass([source class]),@"parentDepth":entry[@"parentDepth"],@"path":entry[@"path"],@"probes":probes}];
    }
    UIImage *image=photo.image;
    CGFloat width=image.size.width*image.scale, height=image.size.height*image.scale;
    BOOL knownPixels=isfinite(width) && isfinite(height) && width>0 && height>0;
    NSMutableDictionary *fields=[@{@"selectedClass":NSStringFromClass(selected.class),@"sample":@(sample.count),@"selectionChanged":@(selectionChanged),@"imageChanged":@(imageChanged),@"hasImage":@(image!=nil),@"hasOriginalAddress":@(photo.url!=nil),@"bitmapSource":bitmapSource ?: @"",@"pixelDimensionsKnown":@(knownPixels),@"width":@(knownPixels ? width : 0),@"height":@(knownPixels ? height : 0),@"sources":sources,@"truncated":@(index<pending.count)} mutableCopy];
    // Only fixed getter names, class names, booleans and pixel counts enter
    // this record. Never include URLs, object descriptions or post identities.
    while (sources.count && [NSJSONSerialization dataWithJSONObject:fields options:0 error:NULL].length>24000) { [sources removeLastObject]; fields[@"truncated"]=@YES; }
    BHRDAvatarLog(@"fullscreen_photo_resolution",fields);
}
#endif
BHRDPhotoSnapshot *BHRDCurrentFullscreenPhoto(UIView *root) {
    if (!root.window || CGRectIsEmpty(root.bounds)) return nil;
    CGPoint center=CGPointMake(CGRectGetMidX(root.bounds),CGRectGetMidY(root.bounds));
    NSMutableArray *pending=[NSMutableArray arrayWithObject:@{@"view":root,@"clip":RectValue(root.bounds)}];
    NSUInteger budget=600; BHRDPhotoSnapshot *best=nil; CGFloat bestArea=0;
    UIView *bestView=nil; NSString *bestBitmapSource=nil;
#if BHRD_AVATAR_DIAGNOSTICS
    BOOL detailed=BHRDAvatarDetailedCollectionRemaining()>0;
#else
    BOOL detailed=NO;
#endif
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
                NSString *bitmapSource=nil; UIImage *image=LoadedImage(view,detailed ? &bitmapSource : NULL);
                NSString *name=NSStringFromClass(view.class).lowercaseString;
                BOOL mediaView=image || [view isKindOfClass:UIImageView.class] || [name containsString:@"imagedisplay"] || [name containsString:@"photoview"] || [name containsString:@"mediaview"];
                BOOL video=NO; NSURL *url=mediaView ? PhotoURL(view,root,&video) : nil;
                if (video && CGRectContainsPoint(visible,center)) return nil;
                if (!video && mediaView && (url || image) && (!best || (url && !best.url) || ((url!=nil)==(best.url!=nil) && area>bestArea))) {
                    best=[BHRDPhotoSnapshot new]; best.image=image; best.url=url;
                    best.identity=url.absoluteString ?: [NSString stringWithFormat:@"image:%p",image.CGImage ?: (__bridge void *)image]; bestArea=area;
                    bestView=view; bestBitmapSource=bitmapSource;
                }
            }
        }
        CGRect childClip=view.clipsToBounds ? visible : clip;
        if (CGRectIsNull(childClip) || CGRectIsEmpty(childClip)) continue;
        for (UIView *child in view.subviews) [pending addObject:@{@"view":child,@"clip":RectValue(childClip)}];
    }
#if BHRD_AVATAR_DIAGNOSTICS
    DiagnoseSelectedPhoto(root,bestView,best,bestBitmapSource);
#else
    (void)bestView; (void)bestBitmapSource;
#endif
    return best;
}
