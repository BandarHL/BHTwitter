#import "BHRDPreferences.h"
#import "BHRDAdFilter.h"
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
}
