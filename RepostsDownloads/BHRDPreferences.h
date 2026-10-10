#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const BHRDHideRepostsKey;
FOUNDATION_EXPORT NSString * const BHRDDownloadKey;
FOUNDATION_EXPORT NSString * const BHRDDirectSaveKey;
FOUNDATION_EXPORT NSString * const BHRDDMKey;
FOUNDATION_EXPORT NSString * const BHRDHideReplyKey;
FOUNDATION_EXPORT NSString * const BHRDHideRetweetKey;
FOUNDATION_EXPORT NSString * const BHRDHideLikeKey;
FOUNDATION_EXPORT NSString * const BHRDHideViewsKey;
FOUNDATION_EXPORT NSString * const BHRDHideBookmarkKey;
FOUNDATION_EXPORT NSString * const BHRDHideHomeKey;
FOUNDATION_EXPORT NSString * const BHRDHideSearchKey;
FOUNDATION_EXPORT NSString * const BHRDHideGrokKey;
FOUNDATION_EXPORT NSString * const BHRDHideNotificationsKey;
FOUNDATION_EXPORT NSString * const BHRDHideMessagesKey;

BOOL BHRDReadPreference(NSUserDefaults *defaults, NSString *key);
BOOL BHRDPreference(NSString *key);
NSArray<NSArray<NSString *> *> *BHRDSettingsKeys(void);
NSArray<NSArray<NSString *> *> *BHRDSettingsTitles(void);
NSSet<NSString *> *BHRDHiddenInlineActionKeys(void);
NSArray *BHRDFilterInlineActionClasses(NSArray *classes, NSSet<NSString *> *hiddenKeys);
NSString *BHRDPreferenceKeyForTabPage(NSString *page);

typedef NS_ENUM(NSInteger, BHRDRepostMode) {
    BHRDRepostModeHidden = 0,
    BHRDRepostModePreview = 1,
    BHRDRepostModeBar = 2
};
FOUNDATION_EXPORT NSString * const BHRDRepostModeKey;
BHRDRepostMode BHRDReadRepostMode(NSUserDefaults *defaults);
BHRDRepostMode BHRDCurrentRepostMode(void);
NSString *BHRDRepostModeTitle(BHRDRepostMode mode);

FOUNDATION_EXPORT NSString * const BHRDHideHomeAddKey;
FOUNDATION_EXPORT NSString * const BHRDFloatingDownloadKey;

FOUNDATION_EXPORT NSString * const BHRDShowShareImageKey;
NSArray *BHRDSetShareImageButtonClass(NSArray *classes, Class buttonClass, BOOL enabled);

FOUNDATION_EXPORT NSString * const BHRDHideAdsKey;

FOUNDATION_EXPORT NSString * const BHRDHideTopicsKey;
FOUNDATION_EXPORT NSString * const BHRDHideWhoKey;
FOUNDATION_EXPORT NSString * const BHRDHideSuggestedTopicsKey;
FOUNDATION_EXPORT NSString * const BHRDHidePremiumKey;
FOUNDATION_EXPORT NSString * const BHRDHideTrendVideosKey;
FOUNDATION_EXPORT NSString * const BHRDConfirmLikeKey;
FOUNDATION_EXPORT NSString * const BHRDConfirmTweetKey;
FOUNDATION_EXPORT NSString * const BHRDConfirmFollowKey;
FOUNDATION_EXPORT NSString * const BHRDCopyLocalOnlyKey;
FOUNDATION_EXPORT NSString * const BHRDCopyExpiresKey;
FOUNDATION_EXPORT NSString * const BHRDDownloadRetentionKey;
