#import "BHRDPreferences.h"
#import "BHRDAdFilter.h"
#import "BHRDAdRuntime.h"
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>
%group AdCards
%hook TFNTwitterStatus
- (BOOL)isCardHidden { return BHRDPreference(BHRDHideAdsKey) && BHRDIsPromotedModel(self) ? YES : %orig; }
%end
%end
%group VideoAds
%hook TFNTwitterAccount
- (BOOL)isVideoDynamicAdEnabled { return BHRDPreference(BHRDHideAdsKey) ? NO : %orig; }
%end
%end
%ctor {
    if (class_getInstanceMethod(objc_getClass("TFNTwitterStatus"), @selector(isCardHidden))) { %init(AdCards); }
    if (class_getInstanceMethod(objc_getClass("TFNTwitterAccount"), @selector(isVideoDynamicAdEnabled))) { %init(VideoAds); }
    BHRDInstallAdRuntimeHooks(MSHookMessageEx);
    // Retry once after launch and once after late framework registration.
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification) {
        BHRDInstallAdRuntimeHooks(MSHookMessageEx);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{ BHRDInstallAdRuntimeHooks(MSHookMessageEx); });
    }];
}
