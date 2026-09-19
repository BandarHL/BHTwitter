// Related NeoFreeBird feature-switch paths, adapted to X Suixin preferences.
#import "BHRDPreferences.h"
#import <objc/runtime.h>
static NSNumber *RecommendationOverride(NSString *key) {
    if (![key isKindOfClass:NSString.class]) return nil;
    if ([key isEqual:@"wtf_device_follow_nudge_turn_off_reactive_blending_enabled"]) return BHRDPreference(BHRDHideWhoKey) ? @YES : nil;
    if ([key isEqualToString:@"ios_profile_analytics_upsell_enabled"] ||
        [key isEqualToString:@"ios_profile_analytics_upsell_possible_enabled"] ||
        [key isEqualToString:@"ios_profile_upgrade_upsell_enabled"] ||
        [key isEqualToString:@"ios_profile_upgrade_upsell_swapper_enabled"] ||
        [key isEqualToString:@"ios_profile_visitor_upsell_enabled"] ||
        [key isEqualToString:@"subscriptions_upsells_get_verified_profile"] ||
        [key isEqualToString:@"subscriptions_upsells_reply_boost_enabled"] ||
        [key
            isEqualToString:@"subscriptions_upsells_reply_boost_popup_enabled"] ||
        [key isEqualToString:@"subscriptions_upsells_post_analytics_enabled"] ||
        [key isEqualToString:@"subscriptions_upsells_creator_support_post_"
                             @"conversation_enabled"] ||
        [key isEqualToString:@"longform_notetweets_composer_upsell_enabled"] ||
        [key isEqualToString:
                 @"longform_notetweets_composer_auto_upsell_enabled"] ||
        [key isEqualToString:@"subscriptions_cta_on_replies_enabled"] ||
        [key isEqualToString:@"super_follow_upsell_sticky_button_enabled"] ||
        [key isEqualToString:@"subscriptions_new_paywall_enabled"] ||
        [key isEqualToString:@"subscriptions_offers_promotional_enabled"] ||
        [key isEqualToString:@"subscriptions_gifting_premium_enabled"] ||
        [key isEqualToString:
                 @"subscriptions_gifting_premium_intro_copy_enabled"] ||
        [key isEqualToString:
                 @"subscriptions_ios_download_to_offline_upsell_enabled"] ||
        [key isEqualToString:
                 @"ios_notifications_blue_verified_introductory_offer_visible"] ||
        [key isEqualToString:@"ios_notifications_blue_verified_introductory_"
                             @"offer_prefix_visible"] ||
        [key isEqualToString:@"dash_items_download_grok_enabled"]) {
        return BHRDPreference(BHRDHidePremiumKey) ? @NO : nil;
    }

    return nil;
}
%group RecommendationGate0_0
%hook TPSTwitterFeatureSwitches
- (BOOL)boolForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.boolValue : %orig; }
%end
%end
%group RecommendationGate0_1
%hook TPSTwitterFeatureSwitches
- (NSInteger)integerForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.integerValue : %orig; }
%end
%end
%group RecommendationGate0_2
%hook TPSTwitterFeatureSwitches
- (NSNumber *)numberForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value : %orig; }
%end
%end
%group RecommendationGate0_3
%hook TPSTwitterFeatureSwitches
- (id)rawValueForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value : %orig; }
%end
%end
%group RecommendationGate0_4
%hook TPSTwitterFeatureSwitches
- (BOOL)unsafePeekBoolForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.boolValue : %orig; }
%end
%end
%group RecommendationGate0_5
%hook TPSTwitterFeatureSwitches
- (NSInteger)unsafePeekIntegerForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.integerValue : %orig; }
%end
%end
%group RecommendationGate0_6
%hook TPSTwitterFeatureSwitches
- (BOOL)hasNonDefaultValueForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? YES : %orig; }
%end
%end
%group RecommendationGate1_0
%hook TFSFeatureSwitches
- (BOOL)boolForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.boolValue : %orig; }
%end
%end
%group RecommendationGate1_1
%hook TFSFeatureSwitches
- (NSInteger)integerForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.integerValue : %orig; }
%end
%end
%group RecommendationGate1_2
%hook TFSFeatureSwitches
- (NSNumber *)numberForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value : %orig; }
%end
%end
%group RecommendationGate1_3
%hook TFSFeatureSwitches
- (id)rawValueForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value : %orig; }
%end
%end
%group RecommendationGate1_4
%hook TFSFeatureSwitches
- (BOOL)unsafePeekBoolForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.boolValue : %orig; }
%end
%end
%group RecommendationGate1_5
%hook TFSFeatureSwitches
- (NSInteger)unsafePeekIntegerForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.integerValue : %orig; }
%end
%end
%group RecommendationGate1_6
%hook TFSFeatureSwitches
- (BOOL)hasNonDefaultValueForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? YES : %orig; }
%end
%end
%group RecommendationGate2_0
%hook TFSInstrumentedFeatureSwitches
- (BOOL)boolForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.boolValue : %orig; }
%end
%end
%group RecommendationGate2_1
%hook TFSInstrumentedFeatureSwitches
- (NSInteger)integerForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.integerValue : %orig; }
%end
%end
%group RecommendationGate2_2
%hook TFSInstrumentedFeatureSwitches
- (NSNumber *)numberForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value : %orig; }
%end
%end
%group RecommendationGate2_3
%hook TFSInstrumentedFeatureSwitches
- (id)rawValueForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value : %orig; }
%end
%end
%group RecommendationGate2_4
%hook TFSInstrumentedFeatureSwitches
- (BOOL)unsafePeekBoolForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.boolValue : %orig; }
%end
%end
%group RecommendationGate2_5
%hook TFSInstrumentedFeatureSwitches
- (NSInteger)unsafePeekIntegerForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? value.integerValue : %orig; }
%end
%end
%group RecommendationGate2_6
%hook TFSInstrumentedFeatureSwitches
- (BOOL)hasNonDefaultValueForKey:(NSString *)key { NSNumber *value = RecommendationOverride(key); return value ? YES : %orig; }
%end
%end
%ctor {
    if (class_getInstanceMethod(objc_getClass("TPSTwitterFeatureSwitches"), @selector(boolForKey:))) { %init(RecommendationGate0_0); }
    if (class_getInstanceMethod(objc_getClass("TPSTwitterFeatureSwitches"), @selector(integerForKey:))) { %init(RecommendationGate0_1); }
    if (class_getInstanceMethod(objc_getClass("TPSTwitterFeatureSwitches"), @selector(numberForKey:))) { %init(RecommendationGate0_2); }
    if (class_getInstanceMethod(objc_getClass("TPSTwitterFeatureSwitches"), @selector(rawValueForKey:))) { %init(RecommendationGate0_3); }
    if (class_getInstanceMethod(objc_getClass("TPSTwitterFeatureSwitches"), @selector(unsafePeekBoolForKey:))) { %init(RecommendationGate0_4); }
    if (class_getInstanceMethod(objc_getClass("TPSTwitterFeatureSwitches"), @selector(unsafePeekIntegerForKey:))) { %init(RecommendationGate0_5); }
    if (class_getInstanceMethod(objc_getClass("TPSTwitterFeatureSwitches"), @selector(hasNonDefaultValueForKey:))) { %init(RecommendationGate0_6); }
    if (class_getInstanceMethod(objc_getClass("TFSFeatureSwitches"), @selector(boolForKey:))) { %init(RecommendationGate1_0); }
    if (class_getInstanceMethod(objc_getClass("TFSFeatureSwitches"), @selector(integerForKey:))) { %init(RecommendationGate1_1); }
    if (class_getInstanceMethod(objc_getClass("TFSFeatureSwitches"), @selector(numberForKey:))) { %init(RecommendationGate1_2); }
    if (class_getInstanceMethod(objc_getClass("TFSFeatureSwitches"), @selector(rawValueForKey:))) { %init(RecommendationGate1_3); }
    if (class_getInstanceMethod(objc_getClass("TFSFeatureSwitches"), @selector(unsafePeekBoolForKey:))) { %init(RecommendationGate1_4); }
    if (class_getInstanceMethod(objc_getClass("TFSFeatureSwitches"), @selector(unsafePeekIntegerForKey:))) { %init(RecommendationGate1_5); }
    if (class_getInstanceMethod(objc_getClass("TFSFeatureSwitches"), @selector(hasNonDefaultValueForKey:))) { %init(RecommendationGate1_6); }
    if (class_getInstanceMethod(objc_getClass("TFSInstrumentedFeatureSwitches"), @selector(boolForKey:))) { %init(RecommendationGate2_0); }
    if (class_getInstanceMethod(objc_getClass("TFSInstrumentedFeatureSwitches"), @selector(integerForKey:))) { %init(RecommendationGate2_1); }
    if (class_getInstanceMethod(objc_getClass("TFSInstrumentedFeatureSwitches"), @selector(numberForKey:))) { %init(RecommendationGate2_2); }
    if (class_getInstanceMethod(objc_getClass("TFSInstrumentedFeatureSwitches"), @selector(rawValueForKey:))) { %init(RecommendationGate2_3); }
    if (class_getInstanceMethod(objc_getClass("TFSInstrumentedFeatureSwitches"), @selector(unsafePeekBoolForKey:))) { %init(RecommendationGate2_4); }
    if (class_getInstanceMethod(objc_getClass("TFSInstrumentedFeatureSwitches"), @selector(unsafePeekIntegerForKey:))) { %init(RecommendationGate2_5); }
    if (class_getInstanceMethod(objc_getClass("TFSInstrumentedFeatureSwitches"), @selector(hasNonDefaultValueForKey:))) { %init(RecommendationGate2_6); }
}
