#import "BHRDPreferences.h"
#import <objc/runtime.h>
#import "BHRDSafety.h"

NSString * const BHRDHideAdsKey = @"bhrd_hide_ads";
NSString * const BHRDHideRepostsKey = @"bhrd_hide_reposts";
NSString * const BHRDDownloadKey = @"bhrd_download";
NSString * const BHRDDirectSaveKey = @"bhrd_direct_save";
NSString * const BHRDDMKey = @"bhrd_dm";
NSString * const BHRDHideReplyKey = @"bhrd_hide_reply_button";
NSString * const BHRDHideRetweetKey = @"bhrd_hide_retweet_button";
NSString * const BHRDHideLikeKey = @"bhrd_hide_like_button";
NSString * const BHRDHideViewsKey = @"bhrd_hide_views_button";
NSString * const BHRDHideBookmarkKey = @"bhrd_hide_bookmark_button";
NSString * const BHRDHideHomeKey = @"bhrd_hide_home_tab";
NSString * const BHRDHideSearchKey = @"bhrd_hide_search_tab";
NSString * const BHRDHideGrokKey = @"bhrd_hide_grok_tab";
NSString * const BHRDHideNotificationsKey = @"bhrd_hide_notifications_tab";
NSString * const BHRDHideMessagesKey = @"bhrd_hide_messages_tab";

NSString * const BHRDHideHomeAddKey = @"bhrd_hide_home_add";
NSString * const BHRDFloatingDownloadKey = @"bhrd_floating_download";

NSString * const BHRDShowShareImageKey = @"bhrd_show_share_image_button";
NSString * const BHRDCopyLocalOnlyKey = @"bhrd_copy_local_only";
NSString * const BHRDCopyExpiresKey = @"bhrd_copy_expires";
NSString * const BHRDDownloadRetentionKey = @"bhrd_download_retention_days";

BOOL BHRDReadPreference(NSUserDefaults *defaults, NSString *key) {
    id value = [defaults objectForKey:key];
    if ([value respondsToSelector:@selector(boolValue)]) return [value boolValue];
    // Preserve 1.0.0 defaults. Every new 1.1.0 hiding option starts disabled.
    return [@[BHRDHideAdsKey, BHRDHideRepostsKey, BHRDDownloadKey, BHRDDMKey, BHRDHideHomeAddKey, BHRDFloatingDownloadKey, BHRDShowShareImageKey, BHRDCopyLocalOnlyKey] containsObject:key];
}
BOOL BHRDPreference(NSString *key) {
    // Copy privacy policy remains readable independently of feature suspension.
    if (![key isEqual:BHRDCopyLocalOnlyKey] && ![key isEqual:BHRDCopyExpiresKey] && !BHRDTweakEnabled()) return NO;
    return BHRDReadPreference(NSUserDefaults.standardUserDefaults, key);
}
NSArray<NSArray<NSString *> *> *BHRDSettingsKeys(void) {
    return @[@[BHRDHideRepostsKey, BHRDHideAdsKey],
             @[BHRDDownloadKey, BHRDDirectSaveKey, BHRDDMKey, BHRDFloatingDownloadKey],
             @[BHRDHideReplyKey, BHRDHideRetweetKey, BHRDHideLikeKey, BHRDHideViewsKey, BHRDHideBookmarkKey, BHRDShowShareImageKey],
             @[BHRDHideHomeKey, BHRDHideSearchKey, BHRDHideGrokKey, BHRDHideNotificationsKey, BHRDHideMessagesKey, BHRDHideHomeAddKey],
             @[BHRDHideTopicsKey, BHRDHideWhoKey, BHRDHideSuggestedTopicsKey, BHRDHidePremiumKey, BHRDHideTrendVideosKey],
             @[BHRDConfirmLikeKey, BHRDConfirmTweetKey, BHRDConfirmFollowKey],
             @[BHRDCopyLocalOnlyKey, BHRDCopyExpiresKey]];
}
NSArray<NSArray<NSString *> *> *BHRDSettingsTitles(void) {
    return @[@[@"隐藏转推", @"屏蔽广告"],
             @[@"启用视频与动图下载", @"直接保存到相册", @"启用私信视频下载", @"全屏右侧独立下载按钮"],
             @[@"隐藏评论按钮", @"隐藏转发按钮", @"隐藏点赞按钮", @"隐藏浏览量", @"隐藏书签按钮", @"显示分享图片按钮"],
             @[@"隐藏主页", @"隐藏搜索", @"隐藏 Grok", @"隐藏通知", @"隐藏私信", @"首页仅保留推荐和关注"],
             @[@"隐藏话题推荐推文", @"隐藏推荐关注", @"隐藏推荐话题", @"隐藏 Premium 推广", @"隐藏趋势视频"],
             @[@"点赞前确认", @"发推前确认", @"关注前确认"],
             @[@"复制内容仅限本机", @"复制内容 10 分钟后过期"]];
}
NSSet<NSString *> *BHRDHiddenInlineActionKeys(void) {
    NSMutableSet *keys = [NSMutableSet set];
    for (NSString *key in @[BHRDHideReplyKey, BHRDHideRetweetKey, BHRDHideLikeKey, BHRDHideViewsKey, BHRDHideBookmarkKey]) if (BHRDPreference(key)) [keys addObject:key];
    return keys;
}
static NSString *BHRDPreferenceKeyForActionClass(Class cls) {
    // Use the original project's class-factory filtering approach, including subclasses.
    // Favorite/Analytics/Bookmark are present in the original; Reply/Retweet extend it.
    NSDictionary *suffixKeys = @{@"ReplyButton": BHRDHideReplyKey,
                                 @"RetweetButton": BHRDHideRetweetKey,
                                 @"RepostButton": BHRDHideRetweetKey,
                                 @"FavoriteButton": BHRDHideLikeKey,
                                 @"LikeButton": BHRDHideLikeKey,
                                 @"AnalyticsButton": BHRDHideViewsKey,
                                 @"ViewCountButton": BHRDHideViewsKey,
                                 @"BookmarkButton": BHRDHideBookmarkKey};
    for (Class current = cls; current != Nil; current = class_getSuperclass(current)) {
        NSString *name = NSStringFromClass(current);
        for (NSString *prefix in @[@"TTAStatusInline", @"T1StatusInline"]) {
            if ([name hasPrefix:prefix]) {
                NSString *key = suffixKeys[[name substringFromIndex:prefix.length]];
                if (key) return key;
            }
        }
    }
    return nil;
}
NSArray *BHRDFilterInlineActionClasses(NSArray *classes, NSSet<NSString *> *hiddenKeys) {
    if (![classes isKindOfClass:NSArray.class] || !hiddenKeys.count) return classes;
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:classes.count];
    for (id value in classes) {
        NSString *key = object_isClass(value) ? BHRDPreferenceKeyForActionClass(value) : nil;
        if (!key || ![hiddenKeys containsObject:key]) [filtered addObject:value];
    }
    return filtered.count == classes.count ? classes : [filtered copy];
}
NSString *BHRDPreferenceKeyForTabPage(NSString *page) {
    if (![page isKindOfClass:NSString.class]) return nil;
    // The primary identifiers are taken directly from CustomTabBar in the original project.
    return @{@"home": BHRDHideHomeKey,
             @"guide": BHRDHideSearchKey, @"search": BHRDHideSearchKey,
             @"grok": BHRDHideGrokKey,
             @"ntab": BHRDHideNotificationsKey, @"notifications": BHRDHideNotificationsKey,
             @"messages": BHRDHideMessagesKey}[page.lowercaseString];
}

NSString * const BHRDRepostModeKey = @"bhrd_repost_mode";
BHRDRepostMode BHRDReadRepostMode(NSUserDefaults *defaults) {
    id value = [defaults objectForKey:BHRDRepostModeKey];
    if (![value isKindOfClass:NSNumber.class]) return BHRDRepostModeBar;
    NSInteger mode = [value integerValue];
    return mode >= BHRDRepostModeHidden && mode <= BHRDRepostModeBar ? mode : BHRDRepostModeBar;
}
BHRDRepostMode BHRDCurrentRepostMode(void) { return BHRDReadRepostMode(NSUserDefaults.standardUserDefaults); }
NSString *BHRDRepostModeTitle(BHRDRepostMode mode) {
    switch (mode) {
        case BHRDRepostModeHidden: return @"完全隐藏";
        case BHRDRepostModePreview: return @"缩略图";
        default: return @"隐藏条";
    }
}

NSArray *BHRDSetShareImageButtonClass(NSArray *classes, Class buttonClass, BOOL enabled) {
    if (!buttonClass) return classes;
    NSMutableArray *result = [NSMutableArray array];
    BOOL found = NO;
    for (id cls in classes) {
        if (cls == buttonClass) {
            if (enabled && !found) [result addObject:cls];
            found = YES;
        } else [result addObject:cls];
    }
    if (enabled && !found) [result addObject:buttonClass];
    return [result copy];
}

NSString * const BHRDHideTopicsKey = @"bhrd_HideTopics";
NSString * const BHRDHideWhoKey = @"bhrd_HideWho";
NSString * const BHRDHideSuggestedTopicsKey = @"bhrd_HideSuggestedTopics";
NSString * const BHRDHidePremiumKey = @"bhrd_HidePremium";
NSString * const BHRDHideTrendVideosKey = @"bhrd_HideTrendVideos";
NSString * const BHRDConfirmLikeKey = @"bhrd_ConfirmLike";
NSString * const BHRDConfirmTweetKey = @"bhrd_ConfirmTweet";
NSString * const BHRDConfirmFollowKey = @"bhrd_ConfirmFollow";
