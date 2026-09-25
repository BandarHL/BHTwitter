#import "BHRDFullscreenContext.h"
#import "BHRDModelAccess.h"
#import <objc/runtime.h>
@interface BHRDFullscreenSourceReference : NSObject
@property(nonatomic,weak) id view;
@end
@implementation BHRDFullscreenSourceReference @end
static char ClassKey,SourceKey;
void BHRDRegisterFullscreenMediaSource(id controller,id view) {
    if (!controller) return;
    BHRDFullscreenSourceReference *source=[BHRDFullscreenSourceReference new]; source.view=view;
    objc_setAssociatedObject(controller,&SourceKey,source,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
BOOL BHRDIsFullscreenMediaController(id controller) {
    if (!controller) return NO;
    Class actual=object_getClass(controller); NSNumber *known=objc_getAssociatedObject(actual,&ClassKey);
    if (!known) {
        BOOL match=NO;
        for (Class cls=actual; cls; cls=class_getSuperclass(cls)) {
            NSString *name=NSStringFromClass(cls);
            for (NSString *part in @[@"ImmersiveFullScreenViewController",@"ImmersiveViewController",@"SlideshowViewController",@"PhotoViewer",@"ImageViewer"])
                if ([name containsString:part]) match=YES;
        }
        known=@(match); objc_setAssociatedObject(actual,&ClassKey,known,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (known.boolValue) return YES;
    // Existing native immersive action bars can verify an otherwise unnamed host.
    // A weak, attached source is required; reused generic controllers do not stay marked.
    BHRDFullscreenSourceReference *reference=objc_getAssociatedObject(controller,&SourceKey);
    id view=reference.view, root=BHRDModelValue(controller,@"viewIfLoaded");
    id window=BHRDModelValue(view,@"window");
    if (!window || window!=BHRDModelValue(root,@"window")) return NO;
    for (NSUInteger depth=0; view && depth<64; depth++,view=BHRDModelValue(view,@"superview")) if (view==root) return YES;
    return NO;
}
