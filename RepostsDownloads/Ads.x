#import "BHRDPreferences.h"
#import "BHRDAdFilter.h"
#import <objc/runtime.h>
%group AdCards
%hook TFNTwitterStatus
- (BOOL)isCardHidden { return BHRDPreference(BHRDHideAdsKey) && BHRDIsPromotedModel(self) ? YES : %orig; }
%end
%end
%group AdFeatures
%hook TPSTwitterFeatureSwitches
- (BOOL)boolForKey:(NSString *)key {
    if (BHRDPreference(BHRDHideAdsKey) && [key isKindOfClass:NSString.class] &&
        ([key hasPrefix:@"ad_formats_"] || [key hasPrefix:@"ad_"] || [key containsString:@"_ads_"] || [key isEqualToString:@"ads_enabled"])) return NO;
    return %orig;
}
%end
%end
%group VideoAds
%hook TFNTwitterAccount
- (BOOL)isVideoDynamicAdEnabled { return BHRDPreference(BHRDHideAdsKey) ? NO : %orig; }
%end
%end
%ctor {
    if (class_getInstanceMethod(objc_getClass("TFNTwitterStatus"), @selector(isCardHidden))) { %init(AdCards); }
    if (class_getInstanceMethod(objc_getClass("TPSTwitterFeatureSwitches"), @selector(boolForKey:))) { %init(AdFeatures); }
    if (class_getInstanceMethod(objc_getClass("TFNTwitterAccount"), @selector(isVideoDynamicAdEnabled))) { %init(VideoAds); }
}
