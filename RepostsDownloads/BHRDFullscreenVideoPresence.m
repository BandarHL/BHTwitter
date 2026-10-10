#import "BHRDFullscreenVideoPresence.h"
#import "BHRDFullscreenContext.h"
#import "BHRDMediaResolver.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
static BOOL CurrentMediaIsPhoto(UIView *view);

static NSValue *PresenceBox(CGRect rect) { return [NSValue value:&rect withObjCType:@encode(CGRect)]; }
static CGRect PresenceRect(NSValue *value) { CGRect rect=CGRectZero; [value getValue:&rect]; return rect; }
static BOOL PresenceVisible(CGRect rect) { return !CGRectIsNull(rect) && !CGRectIsEmpty(rect); }
static BOOL PresenceExcluded(NSString *name) {
    for (NSString *part in @[@"bhrd",@"quoted",@"quotetweet",@"replycomposer",@"backdrop",@"visualeffect",@"blur"])
        if ([name containsString:part]) return YES;
    return NO;
}
BOOL BHRDHasSelectedFullscreenPhoto(id controller) {
    if (!NSThread.isMainThread || !BHRDIsFullscreenMediaController(controller)) return NO;
    UIView *root=BHRDMediaObject(controller,@"viewIfLoaded");
    if (![root isKindOfClass:UIView.class] || !root.window || !PresenceVisible(root.bounds)) return NO;
    CGPoint center=CGPointMake(CGRectGetMidX(root.bounds),CGRectGetMidY(root.bounds));
    NSMutableArray *pending=[NSMutableArray arrayWithObject:@{@"view":root,@"clip":PresenceBox(root.bounds)}]; NSUInteger budget=700;
    while (pending.count && budget--) {
        NSDictionary *entry=pending.lastObject; [pending removeLastObject]; UIView *view=entry[@"view"];
        NSString *name=NSStringFromClass(view.class).lowercaseString;
        if (view.hidden || view.alpha<=0.01 || PresenceExcluded(name)) continue;
        CGRect clip=PresenceRect(entry[@"clip"]),rect=[view convertRect:view.bounds toView:root],visible=CGRectIntersection(rect,clip);
        BOOL page=view!=root && ([name containsString:@"immersivecard"] || [name containsString:@"slideshowstatus"]) &&
            view.bounds.size.height>=root.bounds.size.height*0.55 && view.bounds.size.width>=root.bounds.size.width*0.65;
        if (page && (!PresenceVisible(visible) || !CGRectContainsPoint(visible,center))) continue;
        if ((page || view==root) && PresenceVisible(visible) && CurrentMediaIsPhoto(view)) return YES;
        CGRect childClip=view.clipsToBounds ? visible : clip; if (!PresenceVisible(childClip)) continue;
        for (UIView *child in view.subviews) [pending addObject:@{@"view":child,@"clip":PresenceBox(childClip)}];
    }
    return NO;
}
static BOOL PresenceSurface(NSString *name) {
    for (NSString *part in @[@"thumbnail",@"poster",@"preview",@"image"]) if ([name containsString:part]) return NO;
    return [name containsString:@"video"] || [name containsString:@"player"] || [name containsString:@"mediaplayback"];
}
static BOOL PresenceControls(NSString *name) {
    for (NSString *part in @[@"videocontrol",@"playercontrol",@"playbackcontrol",@"videoscrubber",@"playbackscrubber",@"videoprogress",@"transportcontrol",@"videooverlay"])
        if ([name containsString:part]) return YES;
    return NO;
}
static BOOL CurrentMediaIsVideo(UIView *view) {
    NSMutableArray *sources=[NSMutableArray array];
    for (NSString *key in @[@"currentMediaEntity",@"media"])
        { id media=BHRDMediaObject(view,key); if (media) [sources addObject:media]; }
    id current=BHRDMediaObject(BHRDMediaObject(view,@"viewModel"),@"currentMediaEntity");
    if (current) [sources addObject:current];
    for (id media in sources) if (BHRDMediaObject(media,@"videoInfo")) return YES;
    return NO;
}
static BOOL CurrentMediaIsPhoto(UIView *view) {
    NSMutableArray *sources=[NSMutableArray array];
    for (NSString *key in @[@"currentMediaEntity",@"media"])
        { id media=BHRDMediaObject(view,key); if (media) [sources addObject:media]; }
    id current=BHRDMediaObject(BHRDMediaObject(view,@"viewModel"),@"currentMediaEntity"); if (current) [sources addObject:current];
    for (id media in sources) {
        for (NSString *key in @[@"type",@"mediaType"]) {
            id type=BHRDMediaObject(media,key);
            if ([type isKindOfClass:NSString.class] && [@[@"photo",@"image"] containsObject:[type lowercaseString]]) return YES;
        }
        if (BHRDMediaObject(media,@"videoInfo")) continue;
        for (NSString *key in @[@"mediaURL",@"imageURL",@"URL",@"url"]) {
            id value=BHRDMediaObject(media,key);
            NSURL *url=[value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
            if ([url.host.lowercaseString isEqual:@"pbs.twimg.com"] && [url.path hasPrefix:@"/media/"]) return YES;
        }
    }
    return NO;
}

BOOL BHRDHasVisibleFullscreenVideo(id controller) {
    if (!NSThread.isMainThread || !BHRDIsFullscreenMediaController(controller)) return NO;
    UIView *root=BHRDMediaObject(controller,@"viewIfLoaded");
    if (![root isKindOfClass:UIView.class] || !root.window || !PresenceVisible(root.bounds)) return NO;
    for (UIView *ancestor=root; ancestor; ancestor=ancestor.superview)
        if (ancestor.hidden || ancestor.alpha<=0.01) return NO;
    CGPoint center=CGPointMake(CGRectGetMidX(root.bounds),CGRectGetMidY(root.bounds));
    NSMutableArray *pending=[NSMutableArray arrayWithObject:@{@"view":root,@"clip":PresenceBox(root.bounds)}];
    NSMutableSet *seenLayers=[NSMutableSet set];
    NSUInteger viewBudget=700;
    while (pending.count && viewBudget--) {
        NSDictionary *entry=pending.lastObject; [pending removeLastObject]; UIView *view=entry[@"view"];
        NSString *name=NSStringFromClass(view.class).lowercaseString;
        if (view.hidden || view.alpha<=0.01 || PresenceExcluded(name)) continue;
        CGRect clip=PresenceRect(entry[@"clip"]), rect=[view convertRect:view.bounds toView:root];
        CGRect visible=CGRectIntersection(rect,clip);
        BOOL page=view!=root && ([name containsString:@"immersivecard"] || [name containsString:@"slideshowstatus"]) &&
            view.bounds.size.height>=root.bounds.size.height*0.55 && view.bounds.size.width>=root.bounds.size.width*0.65;
        // Ignore preloaded neighboring pages. A swiping/loading current page
        // may still show its button; the tap resolver validates selection anew.
        if (page && (!PresenceVisible(visible) || !CGRectContainsPoint(visible,center))) continue;
        if (PresenceVisible(visible) && (page || view==root) && CurrentMediaIsPhoto(view)) continue;
        if (PresenceVisible(visible)) {
            CGFloat area=rect.size.width*rect.size.height, shown=visible.size.width*visible.size.height;
            BOOL mainSurface=visible.size.width>=MIN(160,root.bounds.size.width*0.60) && visible.size.height>=60 && area>0 && shown/area>=0.60;
            if (mainSurface && PresenceSurface(name)) return YES;
            if (mainSurface && CurrentMediaIsVideo(view)) return YES;
            if (PresenceControls(name) && visible.size.width>=20 && visible.size.height>=12) return YES;
            if (mainSurface) for (NSString *key in @[@"currentPlayer",@"player",@"videoPlayer",@"avPlayer"])
                if (BHRDMediaObject(view,key)) return YES;
            NSMutableSet *childLayers=[NSMutableSet set];
            for (UIView *child in view.subviews) [childLayers addObject:[NSValue valueWithNonretainedObject:child.layer]];
            NSMutableArray *layers=[NSMutableArray arrayWithObject:@{@"layer":view.layer,@"clip":PresenceBox(clip)}];
            NSUInteger layerBudget=64;
            while (layers.count && layerBudget--) {
                NSDictionary *node=layers.lastObject; [layers removeLastObject]; CALayer *layer=node[@"layer"];
                NSValue *pointer=[NSValue valueWithNonretainedObject:layer];
                if ([seenLayers containsObject:pointer] || layer.hidden || layer.opacity<=0.01) continue;
                [seenLayers addObject:pointer];
                CGRect layerClip=PresenceRect(node[@"clip"]);
                CGRect layerShown=CGRectIntersection([layer convertRect:layer.bounds toLayer:root.layer],layerClip);
                if ([layer isKindOfClass:AVPlayerLayer.class] && ((AVPlayerLayer *)layer).player && PresenceVisible(layerShown) && layerShown.size.width>=90 && layerShown.size.height>=60) return YES;
                CGRect nextClip=layer.masksToBounds ? layerShown : layerClip;
                if (!PresenceVisible(nextClip)) continue;
                for (CALayer *child in layer.sublayers ?: @[])
                    if (![childLayers containsObject:[NSValue valueWithNonretainedObject:child]]) [layers addObject:@{@"layer":child,@"clip":PresenceBox(nextClip)}];
            }
        }
        CGRect childClip=view.clipsToBounds ? visible : clip;
        if (!PresenceVisible(childClip)) continue;
        for (UIView *child in view.subviews) [pending addObject:@{@"view":child,@"clip":PresenceBox(childClip)}];
    }
    return NO;
}
