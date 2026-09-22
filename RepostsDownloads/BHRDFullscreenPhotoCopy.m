#import "BHRDFullscreenPhotoCopy.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDPhotoClipboard.h"
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
@property(atomic) NSUInteger generation;
@property(nonatomic,strong) dispatch_queue_t encodingQueue;
@property(nonatomic) BOOL stopped;
@property(nonatomic) BOOL copying;
- (BOOL)refresh;
- (void)stop;
@end
@implementation BHRDPhotoCopyController
- (instancetype)init { if ((self=[super init])) _encodingQueue=dispatch_queue_create("com.caun.xsuixin.photo-copy",DISPATCH_QUEUE_SERIAL); return self; }
- (BOOL)blocked {
    for (UIViewController *c=self.owner; c; c=c.parentViewController) if (c.presentedViewController && !c.presentedViewController.isBeingDismissed) return YES;
    return NO;
}
- (void)cancel { self.copying=NO; ++self.generation; [self.fetch cancel]; self.fetch=nil; self.overlay.button.enabled=YES; [self.overlay.button setTitle:@"复制图片" forState:UIControlStateNormal]; }
- (BOOL)refresh {
    if (self.stopped) return NO;
    if (!self.owner.viewIfLoaded.window) { [self stop]; return NO; }
    if ([self blocked]) { [self cancel]; self.overlay.hidden=YES; return NO; }
    BHRDPhotoSnapshot *photo=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded);
    BOOL availabilityChanged=(photo.image!=nil)!=(self.photo.image!=nil);
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
        [button setTitle:@"复制图片" forState:UIControlStateNormal]; button.accessibilityLabel=@"复制当前全屏图片"; button.accessibilityHint=@"点按复制原图，长按打开图片工具箱";
        button.tintColor=UIColor.whiteColor; button.backgroundColor=[UIColor colorWithWhite:0 alpha:0.72]; button.layer.cornerRadius=22;
        button.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        button.showsMenuAsPrimaryAction=NO;
        [button addTarget:self action:@selector(copyPhoto) forControlEvents:UIControlEventTouchUpInside];
        [self.overlay addSubview:button];
    }
    if (self.overlay.superview!=window) { [self.overlay removeFromSuperview]; [window addSubview:self.overlay]; }
    self.overlay.hidden=NO; self.overlay.frame=window.bounds;
    CGFloat y=MAX(window.safeAreaInsets.top+12,MIN(window.bounds.size.height*0.65-22,window.bounds.size.height-window.safeAreaInsets.bottom-56));
    self.overlay.button.frame=CGRectMake(MAX(window.safeAreaInsets.left+12,window.bounds.size.width-window.safeAreaInsets.right-128),y,112,44);
    self.overlay.button.enabled=!self.copying;
    if (changed || availabilityChanged || !self.overlay.button.menu) self.overlay.button.menu=[self toolsMenu];
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
- (UIMenu *)toolsMenu {
    __weak BHRDPhotoCopyController *weakSelf=self;
    UIAction *original=[UIAction actionWithTitle:@"复制原图" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(__unused UIAction *action) { [weakSelf copyPhoto]; }];
    UIAction *loaded=[UIAction actionWithTitle:@"复制当前显示（不联网）" image:[UIImage systemImageNamed:@"photo"] identifier:nil handler:^(__unused UIAction *action) { [weakSelf startCopyPrivate:NO loadedOnly:YES]; }];
    loaded.attributes=self.photo.image ? 0 : UIMenuElementAttributesDisabled;
    UIAction *temporary=[UIAction actionWithTitle:@"临时复制（本机 10 分钟）" image:[UIImage systemImageNamed:@"timer"] identifier:nil handler:^(__unused UIAction *action) { [weakSelf startCopyPrivate:YES loadedOnly:NO]; }];
    UIAction *link=[UIAction actionWithTitle:@"复制原图链接" image:[UIImage systemImageNamed:@"link"] identifier:nil handler:^(__unused UIAction *action) {
        BHRDPhotoCopyController *controller=weakSelf;
        if (controller.stopped || [controller blocked]) return;
        BHRDPhotoSnapshot *current=BHRDCurrentFullscreenPhoto(controller.owner.viewIfLoaded);
        if (current.url) { [controller cancel]; UIPasteboard.generalPasteboard.string=current.url.absoluteString; [controller feedback:@"已复制链接"]; }
    }];
    link.attributes=self.photo.url ? 0 : UIMenuElementAttributesDisabled;
    UIAction *info=[UIAction actionWithTitle:@"图片信息" image:[UIImage systemImageNamed:@"info.circle"] identifier:nil handler:^(__unused UIAction *action) { [weakSelf showPhotoInfo]; }];
    return [UIMenu menuWithTitle:@"图片工具箱" children:@[original,loaded,temporary,link,info]];
}
- (void)showPhotoInfo {
    if (self.stopped || [self blocked]) return;
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
                if (!BHRDPhotoCopyMayComplete(snapshot.identity,current.identity,generation,controller.generation,controller.owner.viewIfLoaded.window!=nil,[controller blocked])) { [controller refresh]; return; }
                if (!payload || !type) { [controller feedback:@"图片过大或无效"]; return; }
                if (!BHRDWritePhotoClipboard(payload,privateCopy)) { [controller feedback:@"复制失败"]; return; }
                [controller feedback:privateCopy ? @"已临时复制" : fallback ? @"已复制当前图" : @"已复制原图"];
            });
        }
    });
}
- (void)copyPhoto { [self startCopyPrivate:NO loadedOnly:NO]; }
- (void)startCopyPrivate:(BOOL)privateCopy loadedOnly:(BOOL)loadedOnly {
    if (self.copying || self.stopped || [self blocked]) return;
    BHRDPhotoSnapshot *snapshot=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded); if (!snapshot) return;
    [self cancel]; self.photo=snapshot; NSUInteger generation=self.generation;
    self.copying=YES; self.overlay.button.enabled=NO; [self.overlay.button setTitle:@"正在复制…" forState:UIControlStateNormal];
    if (loadedOnly || !snapshot.url) { [self writeSnapshot:snapshot data:nil privateCopy:privateCopy generation:generation fallback:YES]; return; }
    __weak BHRDPhotoCopyController *weakSelf=self;
    self.fetch=[BHRDPhotoFetch fetchURL:snapshot.url completion:^(NSData *data,NSError *error) {
        BHRDPhotoCopyController *controller=weakSelf;
        if (!controller || controller.stopped || controller.generation!=generation) return;
        controller.fetch=nil;
        BHRDPhotoSnapshot *current=BHRDCurrentFullscreenPhoto(controller.owner.viewIfLoaded);
        if (!BHRDPhotoCopyMayComplete(snapshot.identity,current.identity,generation,controller.generation,controller.owner.viewIfLoaded.window!=nil,[controller blocked])) { [controller cancel]; [controller refresh]; return; }
        if (error && !snapshot.image) { controller.copying=NO; controller.overlay.button.enabled=YES; [controller feedback:@"获取失败，重试"]; return; }
        [controller writeSnapshot:snapshot data:error ? nil : data privateCopy:privateCopy generation:generation fallback:error!=nil];
    }];
}
- (void)stop { self.stopped=YES; [self cancel]; [self.timer invalidate]; self.timer=nil; [self.overlay removeFromSuperview]; self.photo=nil; }
- (void)dealloc {
    NSTimer *timer=_timer; BHRDPhotoFetch *fetch=_fetch; UIView *overlay=_overlay;
    void (^cleanup)(void)=^{ [timer invalidate]; [fetch cancel]; [overlay removeFromSuperview]; };
    if (NSThread.isMainThread) cleanup(); else dispatch_async(dispatch_get_main_queue(),cleanup);
}
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
