#import "BHRDDownloadProgress.h"
#import "BHRDManager.h"
JGProgressHUD *BHRDShowDownloadProgress(NSString *title, void (^cancel)(void)) {
    JGProgressHUD *hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
    hud.position = JGProgressHUDPositionBottomCenter;
    hud.interactionType = JGProgressHUDInteractionTypeBlockTouchesOnHUDView;
    hud.layoutMargins = UIEdgeInsetsMake(12, 16, 12, 16);
    hud.textLabel.text = title;
    hud.detailTextLabel.text = @"点击此提示取消 · 页面可继续滑动";
    hud.indicatorView.accessibilityLabel = @"正在下载";
    hud.tapOnHUDViewBlock = ^(JGProgressHUD *tapped) { if (cancel) cancel(); };
    UIView *view = BHRDTopViewController().view;
    // Stay reachable if the user navigates away while a download is running.
    [hud showInView:view.window ?: view];
    return hud;
}
void BHRDUpdateDownloadProgress(JGProgressHUD *hud, NSString *detail) {
    hud.detailTextLabel.text = [NSString stringWithFormat:@"%@ · 点击取消", detail];
}
void BHRDDismissDownloadProgress(JGProgressHUD *hud) {
    hud.tapOnHUDViewBlock = nil;
    [hud dismissAnimated:NO];
}
