#import "BHRDSafety.h"
#import "BHRDRuntimeStatus.h"
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
    if (!BHRDFeatureHooksEnabledAtLaunch()) return;
    if (BHRDHookSignatureMatches(@"TFNTwitterStatus",@"isCardHidden",'B',2)) { %init(AdCards); BHRDRecordCapability(@"普通广告卡片",@"已安装",@"匹配 TFNTwitterStatus.isCardHidden"); }
    if (BHRDHookSignatureMatches(@"TPSTwitterFeatureSwitches",@"boolForKey:",'B',3)) { %init(AdFeatures); BHRDRecordCapability(@"广告开关读取",@"已安装",@"匹配 TPSTwitterFeatureSwitches.boolForKey"); }
    if (BHRDHookSignatureMatches(@"TFNTwitterAccount",@"isVideoDynamicAdEnabled",'B',2)) { %init(VideoAds); BHRDRecordCapability(@"旧视频广告开关",@"已安装",@"匹配 isVideoDynamicAdEnabled；不表示 SSP 全覆盖"); }
}
