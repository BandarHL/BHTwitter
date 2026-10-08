#import "BHRDFullscreenPhotoCopy.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDPhotoClipboard.h"
#import "BHRDFullscreenPhotoResolver.h"
#import "BHRDFullscreenContext.h"
#import "BHRDMediaResolver.h"
#import "BHRDFullscreenDownloadControl.h"
#import "BHRDHomeHeaderView.h"
#import "BHRDPhotoLibrarySave.h"
#import "BHRDAvatarDiagnostics.h"
#import "BHRDAcceptance.h"
#import "BHRDSafety.h"
#import "BHRDRuntimeStatus.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <math.h>
static BOOL PhotoHost(UIViewController *controller);
static NSData *DisplayedPhotoPayload(UIImage *image) {
    CGFloat pixels=image.size.width*image.scale*image.size.height*image.scale;
    if (!image || image.size.width<=0 || image.size.height<=0 || !isfinite(pixels) || pixels>BHRDPhotoPixelLimit) return nil;
    // Applying UIImage orientation here preserves rotated and mirrored display images.
    UIGraphicsImageRendererFormat *format=UIGraphicsImageRendererFormat.defaultFormat; format.scale=image.scale; format.opaque=NO;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];
    NSData *png=[renderer PNGDataWithActions:^(__unused UIGraphicsImageRendererContext *context) { [image drawInRect:(CGRect){CGPointZero,image.size}]; }];
    return BHRDPhotoLibraryPayload(png);
}
@interface BHRDPhotoCopyOverlay : UIView
@property(nonatomic,strong) UIButton *button;
@property(nonatomic,strong) UIButton *toolsButton;
@property(nonatomic,strong) UILabel *feedbackLabel;
@end
@implementation BHRDPhotoCopyOverlay
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { UIView *hit=[super hitTest:point withEvent:event]; return hit==self ? nil : hit; }
@end
@interface BHRDPhotoCopyController : NSObject
@property(nonatomic,weak) UIViewController *owner;
@property(nonatomic,strong) BHRDPhotoCopyOverlay *overlay;
@property(nonatomic,strong) BHRDPhotoSnapshot *photo;
@property(nonatomic,strong) BHRDPhotoFetch *fetch;
@property(nonatomic,strong) BHRDPhotoSaveJob *saveJob;
@property(nonatomic,copy) NSString *saveAcceptanceSession;
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
- (void)cancel {
    if (self.saveAcceptanceSession && !self.saveJob) [self recordSaveResult:[NSError errorWithDomain:BHRDPhotoSaveErrorDomain code:BHRDPhotoSaveCancelled userInfo:nil]];
    self.saveAcceptanceSession=nil;
    self.copying=NO; ++self.generation; [self.fetch cancel]; self.fetch=nil; [self.saveJob cancel]; self.saveJob=nil; self.overlay.button.enabled=YES; self.overlay.toolsButton.enabled=YES; self.overlay.feedbackLabel.hidden=YES; [self setCopySymbol:@"doc.on.doc" status:nil];
}
- (void)recordSaveResult:(NSError *)error {
    if (!self.saveAcceptanceSession) return;
    BHRDAvatarLog(@"photo_save_result",@{@"success":@NO,@"committed":@NO,@"acceptanceSession":self.saveAcceptanceSession,@"errorDomain":error.domain ?: @"",@"errorCode":@(error.code)});
    self.saveAcceptanceSession=nil;
}
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
        UILabel *feedback=[UILabel new]; self.overlay.feedbackLabel=feedback;
        feedback.textColor=UIColor.whiteColor; feedback.backgroundColor=[UIColor colorWithWhite:0 alpha:0.82];
        feedback.font=[UIFont systemFontOfSize:13]; feedback.textAlignment=NSTextAlignmentCenter; feedback.numberOfLines=2;
        feedback.layer.cornerRadius=10; feedback.clipsToBounds=YES; feedback.userInteractionEnabled=NO; feedback.hidden=YES;
        [self.overlay addSubview:feedback];
    }
    if (self.overlay.superview!=window) { [self.overlay removeFromSuperview]; [window addSubview:self.overlay]; }
    self.overlay.hidden=NO; self.overlay.frame=window.bounds;
    CGFloat y=MAX(window.safeAreaInsets.top+12,MIN(window.bounds.size.height*0.65-22,window.bounds.size.height-window.safeAreaInsets.bottom-56));
    CGFloat right=window.bounds.size.width-window.safeAreaInsets.right-12;
    self.overlay.toolsButton.frame=CGRectMake(right-44,y,44,44);
    self.overlay.button.frame=CGRectMake(MAX(window.safeAreaInsets.left+12,right-96),y,44,44);
    CGFloat feedbackWidth=MIN(280,window.bounds.size.width-window.safeAreaInsets.left-window.safeAreaInsets.right-24);
    self.overlay.feedbackLabel.frame=CGRectMake(MAX(window.safeAreaInsets.left+12,right-feedbackWidth),MAX(window.safeAreaInsets.top+12,y-56),feedbackWidth,48);
    self.overlay.button.enabled=!self.copying;
    self.overlay.toolsButton.enabled=!self.copying;
    [window bringSubviewToFront:self.overlay]; return YES;
}
- (void)feedback:(NSString *)title {
    [self setCopySymbol:[title hasPrefix:@"已"] ? @"checkmark" : @"exclamationmark.triangle" status:title];
    self.overlay.feedbackLabel.text=title; self.overlay.feedbackLabel.hidden=NO;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,title);
    NSUInteger generation=self.generation; __weak BHRDPhotoCopyController *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC*3),dispatch_get_main_queue(),^{
        BHRDPhotoCopyController *controller=weakSelf;
        if (controller.generation==generation) { controller.overlay.feedbackLabel.hidden=YES; [controller setCopySymbol:@"doc.on.doc" status:nil]; }
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
            case 3: if (BHRDWritePhotoLinkClipboard(current.url)) [controller feedback:@"已复制链接"]; break;
            case 4: [controller showPhotoInfo]; break;
            case 5: [controller startSavePhotoLoadedOnly:NO]; break;
            case 6: [controller startSavePhotoLoadedOnly:YES]; break;
            default: break;
        }
    };
    if (sheet.isBeingDismissed && sheet.transitionCoordinator) {
        [sheet.transitionCoordinator animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) { run(); }];
    } else if (sheet.presentingViewController) [sheet dismissViewControllerAnimated:YES completion:run]; else run();
}
- (void)openTools {
    if (self.copying || self.stopped || !PhotoHost(self.owner) || [self blocked]) return;
    BHRDPhotoSnapshot *photo=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded); if (!photo) return;
    [self cancel];
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"图片工具箱" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *titles=@[@"复制原图",@"复制当前显示（不联网）",@"临时复制（本机 10 分钟）",@"复制原图链接",@"图片信息"];
    __weak BHRDPhotoCopyController *weakSelf=self;
    UIAlertAction *save=[UIAlertAction actionWithTitle:@"保存原图到照片" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *item) { [weakSelf performTool:5 identity:photo.identity]; }];
    save.enabled=photo.url!=nil; [sheet addAction:save];
    UIAlertAction *saveLoaded=[UIAlertAction actionWithTitle:@"保存当前显示图片到照片（不联网）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *item) { [weakSelf performTool:6 identity:photo.identity]; }];
    saveLoaded.enabled=photo.image!=nil; [sheet addAction:saveLoaded];
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
- (BOOL)saveStillCurrent:(NSString *)identity generation:(NSUInteger)generation {
    if (self.stopped || self.generation!=generation || !PhotoHost(self.owner) || [self blocked]) return NO;
    return [BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded).identity isEqual:identity];
}
- (void)saveFailure:(NSError *)error {
    [self feedback:@"保存失败"];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"保存图片失败" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
    if ([error.domain isEqual:BHRDPhotoSaveErrorDomain] && error.code==BHRDPhotoSaveDenied) {
        [alert addAction:[UIAlertAction actionWithTitle:@"打开设置" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *item) {
            [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
        }]];
    }
    [self.owner presentViewController:alert animated:YES completion:nil];
}
- (void)finishPhotoOperation {
    self.copying=NO; self.overlay.button.enabled=YES; self.overlay.toolsButton.enabled=YES;
}
- (void)afterPrompt:(UIAlertController *)prompt run:(void (^)(void))run {
    __weak BHRDPhotoCopyController *weakSelf=self;
    void (^done)(void)=^{ weakSelf.toolsSheet=nil; if (run) run(); };
    if (prompt.isBeingDismissed && prompt.transitionCoordinator) {
        [prompt.transitionCoordinator animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) { done(); }];
    } else if (prompt.presentingViewController) [prompt dismissViewControllerAnimated:YES completion:done]; else done();
}
- (void)offerCurrentPhoto:(BHRDPhotoSnapshot *)snapshot generation:(NSUInteger)generation {
    [self finishPhotoOperation];
    if (!snapshot.image) {
        [self recordSaveResult:[NSError errorWithDomain:BHRDPhotoSaveErrorDomain code:BHRDPhotoSaveInvalidData userInfo:nil]];
        [self saveFailure:[NSError errorWithDomain:BHRDPhotoSaveErrorDomain code:BHRDPhotoSaveInvalidData userInfo:@{NSLocalizedDescriptionKey:@"无法获取原图，当前显示图片也尚未加载，请重试"}]]; return;
    }
    UIAlertController *prompt=[UIAlertController alertControllerWithTitle:@"原图未能保存" message:@"原图获取失败、格式不支持或超过 3200 万像素限制。是否改为保存当前显示图片？当前图可能尺寸更小。" preferredStyle:UIAlertControllerStyleAlert];
    __weak BHRDPhotoCopyController *weakSelf=self;
    [prompt addAction:[UIAlertAction actionWithTitle:@"保存当前显示图片" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *item) {
        BHRDPhotoCopyController *controller=weakSelf;
        [controller afterPrompt:controller.toolsSheet run:^{
            BHRDPhotoCopyController *current=weakSelf;
            if ([current saveStillCurrent:snapshot.identity generation:generation]) {
                // Continuing the same save must not create a synthetic cancel
                // or a second acceptance attempt when only the source changes.
                current.copying=YES; current.overlay.button.enabled=NO; current.overlay.toolsButton.enabled=NO;
                [current setCopySymbol:@"hourglass" status:@"正在保存当前图片到照片"];
                [current saveSnapshot:snapshot data:nil loadedOnly:YES generation:generation];
            }
        }];
    }]];
    [prompt addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *item) {
        BHRDPhotoCopyController *controller=weakSelf;
        [controller afterPrompt:controller.toolsSheet run:^{
            BHRDPhotoCopyController *current=weakSelf;
            if ([current saveStillCurrent:snapshot.identity generation:generation]) { [current recordSaveResult:[NSError errorWithDomain:BHRDPhotoSaveErrorDomain code:BHRDPhotoSaveCancelled userInfo:nil]]; [current setCopySymbol:@"doc.on.doc" status:nil]; }
        }];
    }]];
    self.toolsSheet=prompt; self.overlay.hidden=YES;
    [self.owner presentViewController:prompt animated:YES completion:nil];
}
- (void)commitSavePayload:(NSData *)payload snapshot:(BHRDPhotoSnapshot *)snapshot dimensions:(NSDictionary *)dimensions loadedOnly:(BOOL)loadedOnly generation:(NSUInteger)generation {
    if (![self saveStillCurrent:snapshot.identity generation:generation]) return;
    __weak BHRDPhotoCopyController *weakSelf=self;
    self.saveJob=[BHRDPhotoSaveJob saveData:payload hostInfo:NSBundle.mainBundle.infoDictionary acceptanceSession:self.saveAcceptanceSession stillCurrent:^BOOL {
        return [weakSelf saveStillCurrent:snapshot.identity generation:generation];
    } completion:^(BOOL success,NSError *error) {
        BHRDPhotoCopyController *current=weakSelf;
        if (![current saveStillCurrent:snapshot.identity generation:generation]) return;
        current.saveJob=nil; current.saveAcceptanceSession=nil; [current finishPhotoOperation];
        if (success) [current feedback:[NSString stringWithFormat:@"已保存%@到照片\n%@ × %@ 像素",loadedOnly ? @"当前图" : @"原图",dimensions[@"width"],dimensions[@"height"]]];
        else if (error.code!=BHRDPhotoSaveCancelled || ![error.domain isEqual:BHRDPhotoSaveErrorDomain]) [current saveFailure:error];
    }];
}
- (void)confirmSavePayload:(NSData *)payload snapshot:(BHRDPhotoSnapshot *)snapshot dimensions:(NSDictionary *)dimensions loadedOnly:(BOOL)loadedOnly generation:(NSUInteger)generation {
    UIAlertController *prompt=[UIAlertController alertControllerWithTitle:@"这张图片已保存过" message:@"本次打开 X 后已成功保存相同图片。再次保存会在照片中创建另一份。" preferredStyle:UIAlertControllerStyleAlert];
    __weak BHRDPhotoCopyController *weakSelf=self;
    [prompt addAction:[UIAlertAction actionWithTitle:@"仍然保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *item) {
        BHRDPhotoCopyController *controller=weakSelf;
        [controller afterPrompt:controller.toolsSheet run:^{ [weakSelf commitSavePayload:payload snapshot:snapshot dimensions:dimensions loadedOnly:loadedOnly generation:generation]; }];
    }]];
    [prompt addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *item) {
        BHRDPhotoCopyController *controller=weakSelf;
        [controller afterPrompt:controller.toolsSheet run:^{
            BHRDPhotoCopyController *current=weakSelf;
            if ([current saveStillCurrent:snapshot.identity generation:generation]) { [current recordSaveResult:[NSError errorWithDomain:BHRDPhotoSaveErrorDomain code:BHRDPhotoSaveCancelled userInfo:nil]]; [current finishPhotoOperation]; [current setCopySymbol:@"doc.on.doc" status:nil]; }
        }];
    }]];
    self.toolsSheet=prompt; self.overlay.hidden=YES;
    [self.owner presentViewController:prompt animated:YES completion:nil];
}
- (void)saveSnapshot:(BHRDPhotoSnapshot *)snapshot data:(NSData *)data loadedOnly:(BOOL)loadedOnly generation:(NSUInteger)generation {
    __weak BHRDPhotoCopyController *weakSelf=self;
    dispatch_async(self.encodingQueue,^{ @autoreleasepool {
        if (!weakSelf || weakSelf.generation!=generation) return;
        NSData *payload=loadedOnly ? DisplayedPhotoPayload(snapshot.image) : BHRDPhotoLibraryPayload(data);
        NSDictionary *dimensions=BHRDPhotoPixelDimensions(payload);
        NSString *contentKey=BHRDPhotoSaveContentKey(payload);
        dispatch_async(dispatch_get_main_queue(),^{
            BHRDPhotoCopyController *controller=weakSelf;
            if (![controller saveStillCurrent:snapshot.identity generation:generation]) return;
            BHRDAvatarLog(@"photo_save_prepare",@{@"bytes":@(payload.length),@"source":loadedOnly ? @"displayed" : @"original",@"acceptanceSession":controller.saveAcceptanceSession ?: @"",@"valid":@(payload!=nil),@"width":dimensions[@"width"] ?: @0,@"height":dimensions[@"height"] ?: @0});
            if (!payload) {
                if (!loadedOnly) [controller offerCurrentPhoto:snapshot generation:generation];
                else { [controller recordSaveResult:[NSError errorWithDomain:BHRDPhotoSaveErrorDomain code:BHRDPhotoSaveInvalidData userInfo:nil]]; [controller finishPhotoOperation]; [controller saveFailure:[NSError errorWithDomain:BHRDPhotoSaveErrorDomain code:BHRDPhotoSaveInvalidData userInfo:@{NSLocalizedDescriptionKey:@"当前图片无效或超过 3200 万像素限制，无法保存，请重试"}]]; }
                return;
            }
            if (BHRDPhotoWasSavedInSession(contentKey)) [controller confirmSavePayload:payload snapshot:snapshot dimensions:dimensions loadedOnly:loadedOnly generation:generation];
            else [controller commitSavePayload:payload snapshot:snapshot dimensions:dimensions loadedOnly:loadedOnly generation:generation];
        });
    }});
}
- (void)startSavePhotoLoadedOnly:(BOOL)loadedOnly {
    if (self.copying || self.stopped || !PhotoHost(self.owner) || [self blocked]) return;
    BHRDPhotoSnapshot *snapshot=BHRDCurrentFullscreenPhoto(self.owner.viewIfLoaded); if (!snapshot) return;
    [self cancel]; self.photo=snapshot; NSUInteger generation=self.generation;
    self.saveAcceptanceSession=BHRDAcceptanceCurrentSessionIdentifier();
    self.copying=YES; self.overlay.button.enabled=NO; self.overlay.toolsButton.enabled=NO; [self setCopySymbol:@"hourglass" status:@"正在保存到照片"];
    BHRDAvatarLog(@"photo_save_start",@{@"hasURL":@(snapshot.url!=nil),@"hasImage":@(snapshot.image!=nil),@"source":loadedOnly ? @"displayed" : @"original",@"acceptanceSession":self.saveAcceptanceSession ?: @""});
    if (loadedOnly || !snapshot.url) { [self saveSnapshot:snapshot data:nil loadedOnly:loadedOnly generation:generation]; return; }
    __weak BHRDPhotoCopyController *weakSelf=self;
    self.fetch=[BHRDPhotoFetch fetchURL:snapshot.url completion:^(NSData *data,NSError *error) {
        BHRDPhotoCopyController *controller=weakSelf;
        if (![controller saveStillCurrent:snapshot.identity generation:generation]) return;
        controller.fetch=nil;
        BHRDPhotoSnapshot *current=BHRDCurrentFullscreenPhoto(controller.owner.viewIfLoaded);
        BHRDPhotoSnapshot *selected=[BHRDPhotoSnapshot new]; selected.identity=snapshot.identity; selected.url=snapshot.url; selected.image=current.image ?: snapshot.image;
        BHRDAvatarLog(@"photo_save_fetch",@{@"bytes":@(data.length),@"acceptanceSession":controller.saveAcceptanceSession ?: @"",@"errorDomain":error.domain ?: @"",@"errorCode":@(error.code)});
        [controller saveSnapshot:selected data:error ? nil : data loadedOnly:NO generation:generation];
    }];
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
                UIImage *image=data.length ? (type ? [UIImage imageWithData:data] : nil) : snapshot.image;
                payload=image ? DisplayedPhotoPayload(image) : nil;
                type=BHRDPhotoPasteboardType(payload);
            }
            dispatch_async(dispatch_get_main_queue(),^{
                BHRDPhotoCopyController *controller=weakSelf;
                if (!controller || controller.stopped || controller.generation!=generation) return;
                controller.copying=NO; controller.overlay.button.enabled=YES; controller.overlay.toolsButton.enabled=YES;
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
    self.copying=YES; self.overlay.button.enabled=NO; self.overlay.toolsButton.enabled=NO; [self setCopySymbol:@"hourglass" status:@"正在复制"];
    if (loadedOnly || !snapshot.url) { [self writeSnapshot:snapshot data:nil privateCopy:privateCopy generation:generation fallback:YES]; return; }
    __weak BHRDPhotoCopyController *weakSelf=self;
    self.fetch=[BHRDPhotoFetch fetchURL:snapshot.url completion:^(NSData *data,NSError *error) {
        BHRDPhotoCopyController *controller=weakSelf;
        if (!controller || controller.stopped || controller.generation!=generation) return;
        controller.fetch=nil;
        BHRDPhotoSnapshot *current=BHRDCurrentFullscreenPhoto(controller.owner.viewIfLoaded);
        if (!BHRDPhotoCopyMayComplete(snapshot.identity,current.identity,generation,controller.generation,PhotoHost(controller.owner),[controller blocked])) { [controller cancel]; [controller refresh]; return; }
        if (error && !snapshot.image) { controller.copying=NO; controller.overlay.button.enabled=YES; controller.overlay.toolsButton.enabled=YES; [controller feedback:@"获取失败，重试"]; return; }
        [controller writeSnapshot:snapshot data:error ? nil : data privateCopy:privateCopy generation:generation fallback:error!=nil];
    }];
}
- (void)stop { self.stopped=YES; [self.toolsSheet dismissViewControllerAnimated:NO completion:nil]; [self cancel]; [self.timer invalidate]; self.timer=nil; [self.overlay removeFromSuperview]; self.photo=nil; }
- (void)dealloc {
    NSTimer *timer=_timer; BHRDPhotoFetch *fetch=_fetch; BHRDPhotoSaveJob *saveJob=_saveJob; UIView *overlay=_overlay;
    void (^cleanup)(void)=^{ [timer invalidate]; [fetch cancel]; [saveJob cancel]; [overlay removeFromSuperview]; };
    if (NSThread.isMainThread) cleanup(); else dispatch_async(dispatch_get_main_queue(),cleanup);
}
@end
static char PhotoCopyKey;
static BOOL PhotoHost(UIViewController *controller) {
    if (!BHRDTweakEnabled()) return NO;
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
    BOOL displayed=[state refresh];
    if (displayed) BHRDRecordCapability(@"全屏图片工具箱",@"已显示",@"已识别当前 X 图片全屏容器");
    return displayed;
}
void BHRDRemoveFullscreenPhotoCopy(UIViewController *controller) {
    BHRDPhotoCopyController *state=objc_getAssociatedObject(controller,&PhotoCopyKey);
    if (BHRDTweakEnabled() && state.toolsSheet.presentingViewController && controller.viewIfLoaded.window) return;
    [state stop];
    objc_setAssociatedObject(controller,&PhotoCopyKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
