#import "BHRDFullscreenPhotoCopy.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDPhotoClipboard.h"
#import "BHRDFullscreenPhotoResolver.h"
#import "BHRDFullscreenContext.h"
#import "BHRDMediaResolver.h"
#import "BHRDFullscreenDownloadControl.h"
#import "BHRDHomeHeaderView.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
static BOOL PhotoHost(UIViewController *controller);
@interface BHRDPhotoCopyOverlay : UIView
@property(nonatomic,strong) UIButton *button;
@property(nonatomic,strong) UIButton *toolsButton;
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
@property(atomic) NSUInteger generation;
@property(nonatomic,strong) dispatch_queue_t encodingQueue;
@property(nonatomic) BOOL stopped;
@property(nonatomic) BOOL copying;
@property(nonatomic,weak) UIAlertController *toolsSheet;
- (BOOL)refresh;
- (void)stop;
@end
@implementation BHRDPhotoCopyController
- (instancetype)init { if ((self=[super init])) _encodingQueue=dispatch_queue_create("com.caun.xsuixin.photo-copy",DISPATCH_QUEUE_SERIAL); return self; }
- (BOOL)blocked {
    for (UIViewController *c=self.owner; c; c=c.parentViewController) if (c.presentedViewController && !c.presentedViewController.isBeingDismissed) return YES;
    return NO;
}
- (void)setCopySymbol:(NSString *)symbol status:(NSString *)status {
    [self.overlay.button setTitle:nil forState:UIControlStateNormal];
    [self.overlay.button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    self.overlay.button.accessibilityValue=status;
}
- (void)cancel { self.copying=NO; ++self.generation; [self.fetch cancel]; self.fetch=nil; self.overlay.button.enabled=YES; [self setCopySymbol:@"doc.on.doc" status:nil]; }
- (BOOL)refresh {
    if (self.stopped) return NO;
    if (!PhotoHost(self.owner)) { [self stop]; return NO; }
    if (self.toolsSheet.presentingViewController && !self.toolsSheet.isBeingDismissed) { self.overlay.hidden=YES; return self.photo!=nil; }
    if ([self blocked]) { [self cancel]; self.overlay.hidden=YES; return NO; }
    BHRDPhotoSnapshot *photo=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded);
    BOOL changed=![photo.identity isEqual:self.photo.identity];
    if (changed) [self cancel];
    self.photo=photo;
    if (!photo) { [self.overlay removeFromSuperview]; return NO; }
    BHRDRemoveFloatingDownloadControl(self.owner);
    UIWindow *window=self.owner.viewIfLoaded.window;
    if (!self.overlay) {
        self.overlay=[BHRDPhotoCopyOverlay new]; self.overlay.backgroundColor=UIColor.clearColor;
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; self.overlay.button=button;
        [button setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
        [button setTitle:nil forState:UIControlStateNormal]; button.accessibilityLabel=@"复制当前全屏图片"; button.accessibilityHint=@"点按复制原图，长按或点右侧更多打开图片工具箱";
        button.tintColor=UIColor.whiteColor; button.backgroundColor=[UIColor colorWithWhite:0 alpha:0.72]; button.layer.cornerRadius=22;
        [button addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressTools:)]];
        [button addTarget:self action:@selector(copyPhoto) forControlEvents:UIControlEventTouchUpInside];
        [self.overlay addSubview:button];
        UIButton *tools=[UIButton buttonWithType:UIButtonTypeSystem]; self.overlay.toolsButton=tools;
        [tools setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
        tools.tintColor=UIColor.whiteColor; tools.backgroundColor=button.backgroundColor; tools.layer.cornerRadius=22;
        tools.accessibilityLabel=@"图片工具箱";
        [tools addTarget:self action:@selector(openTools) forControlEvents:UIControlEventTouchUpInside]; [self.overlay addSubview:tools];
    }
    if (self.overlay.superview!=window) { [self.overlay removeFromSuperview]; [window addSubview:self.overlay]; }
    self.overlay.hidden=NO; self.overlay.frame=window.bounds;
    CGFloat y=MAX(window.safeAreaInsets.top+12,MIN(window.bounds.size.height*0.65-22,window.bounds.size.height-window.safeAreaInsets.bottom-56));
    CGFloat right=window.bounds.size.width-window.safeAreaInsets.right-12;
    self.overlay.toolsButton.frame=CGRectMake(right-44,y,44,44);
    self.overlay.button.frame=CGRectMake(MAX(window.safeAreaInsets.left+12,right-96),y,44,44);
    self.overlay.button.enabled=!self.copying;
    [window bringSubviewToFront:self.overlay]; return YES;
}
- (void)feedback:(NSString *)title {
    [self setCopySymbol:[title hasPrefix:@"已"] ? @"checkmark" : @"exclamationmark.triangle" status:title];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,title);
    NSUInteger generation=self.generation; __weak BHRDPhotoCopyController *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC*2),dispatch_get_main_queue(),^{
        BHRDPhotoCopyController *controller=weakSelf;
        if (controller.generation==generation) [controller setCopySymbol:@"doc.on.doc" status:nil];
    });
}
- (void)longPressTools:(UILongPressGestureRecognizer *)gesture { if (gesture.state==UIGestureRecognizerStateBegan) [self openTools]; }
- (void)performTool:(NSInteger)tool identity:(NSString *)identity {
    UIAlertController *sheet=self.toolsSheet;
    __weak BHRDPhotoCopyController *weakSelf=self;
    void (^run)(void)=^{
        BHRDPhotoCopyController *controller=weakSelf; controller.toolsSheet=nil;
        if (!controller || controller.stopped || !PhotoHost(controller.owner)) return;
        [controller refresh];
        BHRDPhotoSnapshot *current=BHRDCurrentFullscreenPhoto(controller.owner.viewIfLoaded);
        if (![current.identity isEqual:identity] || [controller blocked]) return;
        switch (tool) {
            case 0: [controller copyPhoto]; break;
            case 1: [controller startCopyPrivate:NO loadedOnly:YES]; break;
            case 2: [controller startCopyPrivate:YES loadedOnly:NO]; break;
            case 3: if (current.url) { UIPasteboard.generalPasteboard.string=current.url.absoluteString; [controller feedback:@"已复制链接"]; } break;
            case 4: [controller showPhotoInfo]; break;
            default: break;
        }
    };
    if (sheet.isBeingDismissed && sheet.transitionCoordinator) {
        [sheet.transitionCoordinator animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) { run(); }];
    } else if (sheet.presentingViewController) [sheet dismissViewControllerAnimated:YES completion:run]; else run();
}
- (void)openTools {
    if (self.stopped || !PhotoHost(self.owner) || [self blocked]) return;
    BHRDPhotoSnapshot *photo=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded); if (!photo) return;
    [self cancel];
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"图片工具箱" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *titles=@[@"复制原图",@"复制当前显示（不联网）",@"临时复制（本机 10 分钟）",@"复制原图链接",@"图片信息"];
    __weak BHRDPhotoCopyController *weakSelf=self;
    for (NSUInteger i=0;i<titles.count;i++) {
        UIAlertAction *action=[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *item) { [weakSelf performTool:(NSInteger)i identity:photo.identity]; }];
        action.enabled=!(i==1 && !photo.image) && !(i==3 && !photo.url); [sheet addAction:action];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *item) { [weakSelf performTool:-1 identity:photo.identity]; }]];
    sheet.popoverPresentationController.sourceView=self.owner.view;
    CGRect anchor=[self.overlay.toolsButton convertRect:self.overlay.toolsButton.bounds toView:self.owner.view];
    sheet.popoverPresentationController.sourceRect=anchor;
    self.toolsSheet=sheet; self.overlay.hidden=YES;
    [self.owner presentViewController:sheet animated:YES completion:nil];
}
- (void)showPhotoInfo {
    if (self.stopped || !PhotoHost(self.owner) || [self blocked]) return;
    BHRDPhotoSnapshot *photo=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded); if (!photo) return;
    UIImage *image=photo.image;
    NSString *size=image ? [NSString stringWithFormat:@"当前加载：%.0f × %.0f 像素",image.size.width*image.scale,image.size.height*image.scale] : @"图片像素信息尚未加载";
    NSString *message=[NSString stringWithFormat:@"%@\n%@\n\n这里显示当前已加载图片的信息，服务器原图可能更大。",size,photo.url ? @"可以获取原图，也可长按复制原图链接。" : @"当前未读取到原图地址，可复制已加载图片。"];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"图片信息" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
    [self.owner presentViewController:alert animated:YES completion:nil];
}
- (void)writeSnapshot:(BHRDPhotoSnapshot *)snapshot data:(NSData *)data privateCopy:(BOOL)privateCopy generation:(NSUInteger)generation fallback:(BOOL)fallback {
    __weak BHRDPhotoCopyController *weakSelf=self;
    dispatch_async(self.encodingQueue,^{
        @autoreleasepool {
            if (!weakSelf || weakSelf.generation!=generation) return;
            NSData *payload=data; NSString *type=BHRDPhotoPasteboardType(data);
            if (![@[@"public.jpeg",@"public.png",@"com.compuserve.gif"] containsObject:type ?: @""]) {
                UIImage *image=data.length ? [UIImage imageWithData:data] : snapshot.image;
                payload=image ? UIImagePNGRepresentation(image) : nil;
                type=BHRDPhotoPasteboardType(payload);
            }
            dispatch_async(dispatch_get_main_queue(),^{
                BHRDPhotoCopyController *controller=weakSelf;
                if (!controller || controller.stopped || controller.generation!=generation) return;
                controller.copying=NO; controller.overlay.button.enabled=YES;
                BHRDPhotoSnapshot *current=BHRDCurrentFullscreenPhoto(controller.owner.viewIfLoaded);
                if (!BHRDPhotoCopyMayComplete(snapshot.identity,current.identity,generation,controller.generation,PhotoHost(controller.owner),[controller blocked])) { [controller refresh]; return; }
                if (!payload || !type) { [controller feedback:@"图片过大或无效"]; return; }
                if (!BHRDWritePhotoClipboard(payload,privateCopy)) { [controller feedback:@"复制失败"]; return; }
                [controller feedback:privateCopy ? @"已临时复制" : fallback ? @"已复制当前图" : @"已复制原图"];
            });
        }
    });
}
- (void)copyPhoto { [self startCopyPrivate:NO loadedOnly:NO]; }
- (void)startCopyPrivate:(BOOL)privateCopy loadedOnly:(BOOL)loadedOnly {
    if (self.copying || self.stopped || !PhotoHost(self.owner) || [self blocked]) return;
    BHRDPhotoSnapshot *snapshot=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded); if (!snapshot) return;
    [self cancel]; self.photo=snapshot; NSUInteger generation=self.generation;
    self.copying=YES; self.overlay.button.enabled=NO; [self setCopySymbol:@"hourglass" status:@"正在复制"];
    if (loadedOnly || !snapshot.url) { [self writeSnapshot:snapshot data:nil privateCopy:privateCopy generation:generation fallback:YES]; return; }
    __weak BHRDPhotoCopyController *weakSelf=self;
    self.fetch=[BHRDPhotoFetch fetchURL:snapshot.url completion:^(NSData *data,NSError *error) {
        BHRDPhotoCopyController *controller=weakSelf;
        if (!controller || controller.stopped || controller.generation!=generation) return;
        controller.fetch=nil;
        BHRDPhotoSnapshot *current=BHRDCurrentFullscreenPhoto(controller.owner.viewIfLoaded);
        if (!BHRDPhotoCopyMayComplete(snapshot.identity,current.identity,generation,controller.generation,PhotoHost(controller.owner),[controller blocked])) { [controller cancel]; [controller refresh]; return; }
        if (error && !snapshot.image) { controller.copying=NO; controller.overlay.button.enabled=YES; [controller feedback:@"获取失败，重试"]; return; }
        [controller writeSnapshot:snapshot data:error ? nil : data privateCopy:privateCopy generation:generation fallback:error!=nil];
    }];
}
- (void)stop { self.stopped=YES; [self.toolsSheet dismissViewControllerAnimated:NO completion:nil]; [self cancel]; [self.timer invalidate]; self.timer=nil; [self.overlay removeFromSuperview]; self.photo=nil; }
- (void)dealloc {
    NSTimer *timer=_timer; BHRDPhotoFetch *fetch=_fetch; UIView *overlay=_overlay;
    void (^cleanup)(void)=^{ [timer invalidate]; [fetch cancel]; [overlay removeFromSuperview]; };
    if (NSThread.isMainThread) cleanup(); else dispatch_async(dispatch_get_main_queue(),cleanup);
}
@end
static char PhotoCopyKey;
static BOOL PhotoHost(UIViewController *controller) {
    UIView *root=controller.viewIfLoaded; UIWindow *window=root.window;
    if (!BHRDIsFullscreenMediaController(controller) || !window) return NO;
    for (UIView *view=root; view; view=view.superview) if (view.hidden || view.alpha<=0.01) return NO;
    CGRect visible=CGRectIntersection([root convertRect:root.bounds toView:window],window.bounds);
    return !CGRectIsNull(visible) && visible.size.width>=window.bounds.size.width*0.8 && visible.size.height>=window.bounds.size.height*0.7;
}
BOOL BHRDRefreshFullscreenPhotoCopy(UIViewController *controller) {
    if (!PhotoHost(controller)) return NO;
    for (UIViewController *parent=controller.parentViewController; parent; parent=parent.parentViewController) if (PhotoHost(parent)) return NO;
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
    BHRDPhotoCopyController *state=objc_getAssociatedObject(controller,&PhotoCopyKey);
    if (state.toolsSheet.presentingViewController && controller.viewIfLoaded.window) return;
    [state stop];
    objc_setAssociatedObject(controller,&PhotoCopyKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
