#import "BHRDSafety.h"
#import "BHRDSettingsViewController.h"
#import "BHRDDiagnosticsViewController.h"
#import "BHRDAcceptanceViewController.h"
#import "BHRDAcceptance.h"
#import "BHRDAvatarDiagnostics.h"
#import "BHRDRepostPresentation.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
static UIViewController *RecoveryTop(UIWindow *window) {
    UIViewController *top=window.rootViewController;
    for (NSUInteger i=0;top && i<16;i++) {
        if (top.presentedViewController && !top.presentedViewController.isBeingDismissed) top=top.presentedViewController;
        else if ([top isKindOfClass:UINavigationController.class]) top=[(UINavigationController *)top visibleViewController];
        else if ([top isKindOfClass:UITabBarController.class]) top=[(UITabBarController *)top selectedViewController];
        else break;
    }
    return top;
}
static void RecoveryDismiss(UIAlertController *sheet,UIWindow *window,void (^operation)(UIViewController *)) {
    void (^run)(void)=^{ UIViewController *owner=RecoveryTop(window); if (owner && ![owner isKindOfClass:UIAlertController.class]) operation(owner); };
    if (sheet.presentingViewController) [sheet dismissViewControllerAnimated:YES completion:run];
    else dispatch_async(dispatch_get_main_queue(),run);
}
@interface BHRDRecoveryAction : NSObject
@property(nonatomic,weak) UIWindow *window;
- (void)open:(UILongPressGestureRecognizer *)gesture;
@end
@implementation BHRDRecoveryAction
- (void)open:(UILongPressGestureRecognizer *)gesture {
    if (gesture && gesture.state!=UIGestureRecognizerStateBegan) return;
    NSString *session=BHRDAcceptanceCurrentSessionIdentifier(), *source=gesture ? @"three_finger" : @"paused_boot";
    UIViewController *top=RecoveryTop(self.window);
    if (!top || !top.view.window || [top isKindOfClass:UIAlertController.class]) {
        if (gesture) BHRDAvatarLog(@"recovery_invoked",@{@"source":source,@"presented":@NO,@"acceptanceSession":session,@"errorDomain":@"XSuixinRecovery",@"errorCode":@1});
        return;
    }
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"X 随心恢复菜单" message:@"可暂停插件或打开设置。暂停后重启 X 会跳过功能注入；恢复后也请重启 X。" preferredStyle:UIAlertControllerStyleActionSheet];
    __weak BHRDRecoveryAction *weakSelf=self;
    __weak UIAlertController *weakSheet=sheet;
    [sheet addAction:[UIAlertAction actionWithTitle:BHRDIsPaused() ? @"恢复插件（重启 X）" : @"暂停全部功能（重启 X）" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSError *error=nil; BHRDSetPaused(!BHRDIsPaused(),&error); BHRDRefreshHiddenReposts();
        UIAlertController *notice=[UIAlertController alertControllerWithTitle:error ? @"操作失败" : @"已保存" message:error.localizedDescription ?: @"请彻底退出并重新打开 X。已有设置和文件保留。" preferredStyle:UIAlertControllerStyleAlert];
        [notice addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
        RecoveryDismiss(weakSheet,weakSelf.window,^(UIViewController *owner) { [owner presentViewController:notice animated:YES completion:nil]; });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"打开 X 随心设置" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        RecoveryDismiss(weakSheet,weakSelf.window,^(UIViewController *owner) { [owner presentViewController:[[UINavigationController alloc] initWithRootViewController:[BHRDSettingsViewController new]] animated:YES completion:nil]; });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"查看诊断日志" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        RecoveryDismiss(weakSheet,weakSelf.window,^(UIViewController *owner) { [owner presentViewController:[[UINavigationController alloc] initWithRootViewController:[BHRDDiagnosticsViewController new]] animated:YES completion:nil]; });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"实际运行验收" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        RecoveryDismiss(weakSheet,weakSelf.window,^(UIViewController *owner) { [owner presentViewController:[[UINavigationController alloc] initWithRootViewController:[BHRDAcceptanceViewController new]] animated:YES completion:nil]; });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView=top.view;
    sheet.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(top.view.bounds),CGRectGetMidY(top.view.bounds),1,1);
    [top presentViewController:sheet animated:YES completion:^{
        BOOL shown=sheet.presentingViewController!=nil && sheet.view.window!=nil;
        BHRDAvatarLog(@"recovery_invoked",@{@"source":source,@"presented":@(shown),@"acceptanceSession":session,@"errorDomain":shown ? @"" : @"XSuixinRecovery",@"errorCode":shown ? @0 : @2});
    }];
}
@end
static char RecoveryKey;
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIWindow *window=self.viewIfLoaded.window;
    if (!window || window.windowLevel!=UIWindowLevelNormal || objc_getAssociatedObject(window,&RecoveryKey)) return;
    BHRDRecoveryAction *action=[BHRDRecoveryAction new]; action.window=window;
    objc_setAssociatedObject(window,&RecoveryKey,action,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UILongPressGestureRecognizer *gesture=[[UILongPressGestureRecognizer alloc] initWithTarget:action action:@selector(open:)];
    gesture.numberOfTouchesRequired=3; gesture.minimumPressDuration=1.5; gesture.cancelsTouchesInView=NO;
    [window addGestureRecognizer:gesture];
    if (!BHRDFeatureHooksEnabledAtLaunch()) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{ [action open:nil]; });
    }
}
%end
%ctor {
    BHRDAcceptanceObserveLaunch(BHRDIsPaused(),BHRDFeatureHooksEnabledAtLaunch());
    %init;
}
