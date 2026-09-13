#import "BHRDFullscreenDownloadControl.h"
#import "BHRDLayoutGeometry.h"
#import <objc/runtime.h>

@interface BHRDFloatingOverlay : UIView
@property(nonatomic, weak) UIViewController *owner;
@property(nonatomic, strong) UIButton *button;
@property(nonatomic, strong) BHRDFullscreenActionRouter *router;
@end
@implementation BHRDFloatingOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = UIColor.clearColor;
        _button = [UIButton buttonWithType:UIButtonTypeSystem];
        [_button setTitle:@"下载" forState:UIControlStateNormal];
        [_button setImage:[UIImage systemImageNamed:@"square.and.arrow.down"] forState:UIControlStateNormal];
        _button.tintColor = UIColor.whiteColor;
        _button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
        _button.layer.cornerRadius = 22;
        _button.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 8, 12);
        _button.imageEdgeInsets = UIEdgeInsetsMake(0, -6, 0, 0);
        _button.accessibilityLabel = @"下载当前全屏视频";
        [_button addTarget:self action:@selector(activate) forControlEvents:UIControlEventPrimaryActionTriggered];
        [self addSubview:_button];
    }
    return self;
}
- (void)activate { [self.router activate]; }
- (BOOL)modalIsVisible {
    for (UIViewController *controller = self.owner; controller; controller = controller.parentViewController) {
        if (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) return YES;
    }
    return NO;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIEdgeInsets safe = self.window.safeAreaInsets;
    self.button.frame = BHRDFloatingDownloadFrame(self.bounds, safe.top, safe.left, safe.bottom, safe.right);
    self.button.hidden = !self.owner.viewIfLoaded.window || !self.router.isEnabled || !self.router.isEnabled() || [self modalIsVisible];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // This overlay never consumes video gestures outside its single button.
    if (!self.router.isEnabled || !self.router.isEnabled() || [self modalIsVisible]) return nil;
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
@end
static char BHRDFloatingOverlayKey, BHRDOwnerOverlayKey;
void BHRDRemoveFloatingDownloadControl(UIViewController *owner) {
    BHRDFloatingOverlay *overlay = [(NSHashTable *)objc_getAssociatedObject(owner, &BHRDOwnerOverlayKey) anyObject];
    if (overlay.owner != owner) return;
    UIWindow *window = overlay.window;
    [overlay removeFromSuperview];
    if (objc_getAssociatedObject(window, &BHRDFloatingOverlayKey) == overlay) objc_setAssociatedObject(window, &BHRDFloatingOverlayKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(owner, &BHRDOwnerOverlayKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
void BHRDUpdateFloatingDownloadControl(UIViewController *owner, BOOL active, BHRDFullscreenActionRouter *router) {
    UIWindow *window = owner.viewIfLoaded.window;
    if (!active || !window) { BHRDRemoveFloatingDownloadControl(owner); return; }
    BHRDFloatingOverlay *overlay = objc_getAssociatedObject(window, &BHRDFloatingOverlayKey);
    if (!overlay) {
        overlay = [[BHRDFloatingOverlay alloc] initWithFrame:window.bounds];
        objc_setAssociatedObject(window, &BHRDFloatingOverlayKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [window addSubview:overlay];
    }
    NSHashTable *handle = [NSHashTable weakObjectsHashTable];
    [handle addObject:overlay];
    objc_setAssociatedObject(owner, &BHRDOwnerOverlayKey, handle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    overlay.owner = owner;
    overlay.router = router;
    overlay.frame = window.bounds;
    [overlay setNeedsLayout];
    [window bringSubviewToFront:overlay];
}
