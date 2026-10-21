#import "BHRDSafety.h"
#import "BHRDManager.h"
#import "BHRDConfirmationGate.h"
#import <objc/runtime.h>
static void Confirm(NSString *key, NSString *message, void (^action)(void)) {
    static BHRDConfirmationGate *gate;
    if (!gate) gate = [BHRDConfirmationGate new];
    if (!BHRDPreference(key) || gate.depth) { action(); return; }
    if (![gate begin]) return;
    UIViewController *presenter = BHRDTopViewController();
    if (!presenter.view.window || presenter.isBeingDismissed || [presenter isKindOfClass:UIAlertController.class]) { [gate cancel]; return; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"X 随心" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *item) { [gate cancel]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction *item) { [gate approve:action]; }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}
%group Confirm0
%hook T1TweetComposeViewController
- (void)_t1_didTapSendButton:(id)button { Confirm(BHRDConfirmTweetKey, @"确定发送这条推文吗？", ^{ %orig(button); }); }
%end
%end
%group Confirm1
%hook T1TweetComposeViewController
- (void)_t1_handleTweet { Confirm(BHRDConfirmTweetKey, @"确定发送这条推文吗？", ^{ %orig; }); }
%end
%end
%group Confirm2
%hook TUIFollowControl
- (void)_followUser:(id)user event:(id)event { Confirm(BHRDConfirmFollowKey, @"确定关注这个账号吗？", ^{ %orig(user, event); }); }
%end
%end
%group Confirm3
%hook TTAStatusInlineFavoriteButton
- (void)didTap { Confirm(BHRDConfirmLikeKey, @"确定切换这条推文的点赞状态吗？", ^{ %orig; }); }
%end
%end
%group Confirm4
%hook T1StatusInlineFavoriteButton
- (void)didTap { Confirm(BHRDConfirmLikeKey, @"确定切换这条推文的点赞状态吗？", ^{ %orig; }); }
%end
%end
%group Confirm5
%hook T1ImmersiveExploreCardView
- (void)handleDoubleTap:(id)event { Confirm(BHRDConfirmLikeKey, @"确定对这条内容执行点赞操作吗？", ^{ %orig(event); }); }
%end
%end
%group Confirm6
%hook T1TweetDetailsViewController
- (void)_t1_toggleFavoriteOnCurrentStatus { Confirm(BHRDConfirmLikeKey, @"确定切换这条推文的点赞状态吗？", ^{ %orig; }); }
%end
%end
%ctor {
    if (!BHRDFeatureHooksEnabledAtLaunch()) return;
    if (class_getInstanceMethod(objc_getClass("T1TweetComposeViewController"), NSSelectorFromString(@"_t1_didTapSendButton:"))) { %init(Confirm0); }
    if (class_getInstanceMethod(objc_getClass("T1TweetComposeViewController"), NSSelectorFromString(@"_t1_handleTweet"))) { %init(Confirm1); }
    if (class_getInstanceMethod(objc_getClass("TUIFollowControl"), NSSelectorFromString(@"_followUser:event:"))) { %init(Confirm2); }
    if (class_getInstanceMethod(objc_getClass("TTAStatusInlineFavoriteButton"), NSSelectorFromString(@"didTap"))) { %init(Confirm3); }
    if (class_getInstanceMethod(objc_getClass("T1StatusInlineFavoriteButton"), NSSelectorFromString(@"didTap"))) { %init(Confirm4); }
    if (class_getInstanceMethod(objc_getClass("T1ImmersiveExploreCardView"), NSSelectorFromString(@"handleDoubleTap:"))) { %init(Confirm5); }
    if (class_getInstanceMethod(objc_getClass("T1TweetDetailsViewController"), NSSelectorFromString(@"_t1_toggleFavoriteOnCurrentStatus"))) { %init(Confirm6); }
}
