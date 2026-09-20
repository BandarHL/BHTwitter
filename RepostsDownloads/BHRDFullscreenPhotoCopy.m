#import "BHRDFullscreenPhotoCopy.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDFullscreenPhotoResolver.h"
#import "BHRDMediaResolver.h"
#import "BHRDFullscreenDownloadControl.h"
#import "BHRDHomeHeaderView.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
@interface BHRDPhotoCopyOverlay : UIView
@property(nonatomic,strong) UIButton *button;
@end
@implementation BHRDPhotoCopyOverlay
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { UIView *hit=[super hitTest:point withEvent:event]; return hit==self ? nil : hit; }
@end
@interface BHRDPhotoCopyController : NSObject
@property(nonatomic,weak) UIViewController *owner;
@property(nonatomic,strong) BHRDPhotoCopyOverlay *overlay;
@property(nonatomic,strong) BHRDPhotoSnapshot *photo;
@property(nonatomic,strong) BHRDPhotoFetch *fetch;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) BOOL stopped;
- (BOOL)refresh;
- (void)stop;
@end
@implementation BHRDPhotoCopyController
- (BOOL)blocked {
    for (UIViewController *c=self.owner; c; c=c.parentViewController) if (c.presentedViewController && !c.presentedViewController.isBeingDismissed) return YES;
    return NO;
}
- (void)cancel { ++self.generation; [self.fetch cancel]; self.fetch=nil; self.overlay.button.enabled=YES; [self.overlay.button setTitle:@"复制图片" forState:UIControlStateNormal]; }
- (BOOL)refresh {
    if (self.stopped) return NO;
    if (!self.owner.viewIfLoaded.window) { [self stop]; return NO; }
    if ([self blocked]) { [self cancel]; self.overlay.hidden=YES; return NO; }
    BHRDPhotoSnapshot *photo=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded);
    if (![photo.identity isEqual:self.photo.identity]) [self cancel];
    self.photo=photo;
    if (!photo) { [self.overlay removeFromSuperview]; return NO; }
    BHRDRemoveFloatingDownloadControl(self.owner);
    UIWindow *window=self.owner.viewIfLoaded.window;
    if (!self.overlay) {
        self.overlay=[BHRDPhotoCopyOverlay new]; self.overlay.backgroundColor=UIColor.clearColor;
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; self.overlay.button=button;
        [button setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
        [button setTitle:@"复制图片" forState:UIControlStateNormal]; button.accessibilityLabel=@"复制当前全屏图片";
        button.tintColor=UIColor.whiteColor; button.backgroundColor=[UIColor colorWithWhite:0 alpha:0.72]; button.layer.cornerRadius=22;
        button.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [button addTarget:self action:@selector(copyPhoto) forControlEvents:UIControlEventTouchUpInside];
        [self.overlay addSubview:button];
    }
    if (self.overlay.superview!=window) { [self.overlay removeFromSuperview]; [window addSubview:self.overlay]; }
    self.overlay.hidden=NO; self.overlay.frame=window.bounds;
    CGFloat y=MAX(window.safeAreaInsets.top+12,MIN(window.bounds.size.height*0.65-22,window.bounds.size.height-window.safeAreaInsets.bottom-56));
    self.overlay.button.frame=CGRectMake(MAX(window.safeAreaInsets.left+12,window.bounds.size.width-window.safeAreaInsets.right-128),y,112,44);
    self.overlay.button.enabled=self.fetch==nil;
    [window bringSubviewToFront:self.overlay]; return YES;
}
- (void)feedback:(NSString *)title {
    [self.overlay.button setTitle:title forState:UIControlStateNormal];
    NSUInteger generation=self.generation; __weak BHRDPhotoCopyController *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC*2),dispatch_get_main_queue(),^{
        BHRDPhotoCopyController *controller=weakSelf;
        if (controller.generation==generation) [controller.overlay.button setTitle:@"复制图片" forState:UIControlStateNormal];
    });
}
- (void)copyPhoto {
    if (self.fetch || self.stopped || [self blocked]) return;
    BHRDPhotoSnapshot *snapshot=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded); if (!snapshot) return;
    [self cancel]; self.photo=snapshot; NSUInteger generation=self.generation;
    if (!snapshot.url) { if (snapshot.image) { UIPasteboard.generalPasteboard.image=snapshot.image; [self feedback:@"已复制图片"]; } return; }
    self.overlay.button.enabled=NO; [self.overlay.button setTitle:@"正在获取…" forState:UIControlStateNormal];
    __weak BHRDPhotoCopyController *weakSelf=self;
    self.fetch=[BHRDPhotoFetch fetchURL:snapshot.url completion:^(NSData *data,NSError *error) {
        BHRDPhotoCopyController *controller=weakSelf;
        if (!controller || controller.stopped || controller.generation!=generation) return;
        controller.fetch=nil; controller.overlay.button.enabled=YES;
        BHRDPhotoSnapshot *current=BHRDCurrentFullscreenPhoto(controller.owner.viewIfLoaded);
        if (!BHRDPhotoCopyMayComplete(snapshot.identity,current.identity,generation,controller.generation,controller.owner.viewIfLoaded.window!=nil,[controller blocked])) { [controller refresh]; return; }
        NSString *type=BHRDPhotoPasteboardType(data);
        if (!error && type) {
            if ([@[@"public.jpeg",@"public.png",@"com.compuserve.gif"] containsObject:type]) [UIPasteboard.generalPasteboard setData:data forPasteboardType:type];
            else { UIImage *image=[UIImage imageWithData:data]; if (!image) { [controller feedback:@"复制失败"]; return; } UIPasteboard.generalPasteboard.image=image; }
            [controller feedback:@"已复制原图"];
        } else if (snapshot.image) { UIPasteboard.generalPasteboard.image=snapshot.image; [controller feedback:@"已复制当前图"]; }
        else [controller feedback:@"获取失败，重试"];
    }];
}
- (void)stop { self.stopped=YES; [self cancel]; [self.timer invalidate]; self.timer=nil; [self.overlay removeFromSuperview]; self.photo=nil; }
- (void)dealloc { [_timer invalidate]; [_fetch cancel]; [_overlay removeFromSuperview]; }
@end
static char PhotoCopyKey;
static BOOL PhotoController(UIViewController *controller) {
    for (Class cls=controller.class; cls; cls=class_getSuperclass(cls)) {
        NSString *name=NSStringFromClass(cls);
        if ([name containsString:@"SlideshowViewController"] || [name containsString:@"PhotoViewer"] || [name containsString:@"ImageViewer"]) return YES;
    }
    return NO;
}
BOOL BHRDRefreshFullscreenPhotoCopy(UIViewController *controller) {
    if (!PhotoController(controller)) return NO;
    for (UIViewController *parent=controller.parentViewController; parent; parent=parent.parentViewController) if (PhotoController(parent)) return NO;
    UIView *root=controller.viewIfLoaded; UIWindow *window=root.window;
    if (!window || root.bounds.size.width<window.bounds.size.width*0.8 || root.bounds.size.height<window.bounds.size.height*0.7) return NO;
    BHRDPhotoCopyController *state=objc_getAssociatedObject(controller,&PhotoCopyKey);
    if (!state || state.stopped) {
        state=[BHRDPhotoCopyController new]; state.owner=controller;
        objc_setAssociatedObject(controller,&PhotoCopyKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak BHRDPhotoCopyController *weakState=state;
        state.timer=[NSTimer timerWithTimeInterval:0.4 repeats:YES block:^(__unused NSTimer *timer) {
            BHRDPhotoCopyController *current=weakState; BOOL hadPhoto=current.photo!=nil;
            BOOL hasPhoto=[current refresh];
            if (hadPhoto && !hasPhoto && !current.stopped && ![current blocked]) BHRDRefreshFullscreenController(current.owner);
        }];
        [NSRunLoop.mainRunLoop addTimer:state.timer forMode:NSRunLoopCommonModes];
    }
    return [state refresh];
}
void BHRDRemoveFullscreenPhotoCopy(UIViewController *controller) {
    BHRDPhotoCopyController *state=objc_getAssociatedObject(controller,&PhotoCopyKey); [state stop];
    objc_setAssociatedObject(controller,&PhotoCopyKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
