#import "BHRDFullscreenDownloadControl.h"
#import "BHRDLayoutGeometry.h"
#import "BHRDAvatarDiagnostics.h"
#import "BHRDRuntimeStatus.h"
#import <objc/runtime.h>

@interface BHRDFloatingOverlay : UIView
@property(nonatomic, weak) UIViewController *owner;
@property(nonatomic, strong) UIButton *button;
@property(nonatomic, strong) BHRDFullscreenActionRouter *router;
@property(nonatomic, copy) NSString *visibilityStamp;
@end
@implementation BHRDFloatingOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = UIColor.clearColor;
        _button = [UIButton buttonWithType:UIButtonTypeSystem];
        [_button setTitle:nil forState:UIControlStateNormal];
        [_button setImage:[UIImage systemImageNamed:@"square.and.arrow.down"] forState:UIControlStateNormal];
        _button.tintColor = UIColor.whiteColor;
        _button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
        _button.layer.cornerRadius = 22;
        _button.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
        _button.imageEdgeInsets = UIEdgeInsetsZero;
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
    BOOL displayed=!self.button.hidden && self.window!=nil && self.button.frame.size.width>0 && self.button.frame.size.height>0;
    NSString *stamp=[NSString stringWithFormat:@"%d:%@:%@",displayed,NSStringFromClass(self.owner.class),NSStringFromCGRect(self.button.frame)];
    if (![self.visibilityStamp isEqual:stamp]) {
        self.visibilityStamp=stamp;
        BHRDAvatarLog(@"fullscreen_download_visibility",@{@"displayed":@(displayed),@"attached":@(self.window!=nil),@"ownerClass":self.owner ? NSStringFromClass(self.owner.class) : @"",
            @"modal":@([self modalIsVisible]),@"frame":@[@(self.button.frame.origin.x),@(self.button.frame.origin.y),@(self.button.frame.size.width),@(self.button.frame.size.height)]});
        BHRDRecordCapability(@"全屏右侧下载入口",displayed ? @"已显示" : @"当前暂隐",@"独立纯图标按钮；显示依据播放视图，点击才解析下载参数。");
    }
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
