//
//  BHTdownloadManager.h
//  BHT
//
//  Created by BandarHelal on 24/12/1441 AH.
//

#import "TWHeaders.h"


@interface BHTManager : NSObject
+ (NSString *)getDownloadingPersent:(float)per;
+ (void)cleanCache;
+ (NSString *)getVideoQuality:(NSString *)url;
+ (BOOL)isVideoCell:(id <T1StatusViewModel>)model;
+ (bool)isDMVideoCell:(T1InlineMediaView *)view;
+ (BOOL)doesContainDigitsOnly:(NSString *)string;
+ (UIViewController *)BHTSettingsWithAccount:(TFNTwitterAccount *)twAccount;
+ (void)showSaveVC:(NSURL *)url;
+ (void)save:(NSURL *)url;
+ (MediaInformation *)getM3U8Information:(NSURL *)mediaURL;
+ (TFNMenuSheetViewController *)newFFmpegDownloadSheet:(MediaInformation *)mediaInformation downloadingURL:(NSURL *)downloadingURL progressView:(JGProgressHUD *)hud;

+ (BOOL)DownloadingVideos;
+ (BOOL)DirectSave;
+ (BOOL)UndoTweet;
+ (BOOL)NoHistory;
+ (BOOL)BioTranslate;
+ (BOOL)LikeConfirm;
+ (BOOL)TweetConfirm;
+ (BOOL)FollowConfirm;
+ (BOOL)HidePromoted;
+ (BOOL)HideTopics;
+ (BOOL)DisableVODCaptions;
+ (BOOL)Padlock;
+ (BOOL)changeFont;
+ (BOOL)autoHighestLoad;
+ (BOOL)disableSensitiveTweetWarnings;
+ (BOOL)showScrollIndicator;
+ (BOOL)CopyProfileInfo;
+ (BOOL)tweetToImage;
+ (BOOL)hideSpacesBar;
+ (BOOL)disableRTL;
+ (BOOL)alwaysOpenSafari;
+ (BOOL)hideWhoToFollow;
+ (BOOL)hideTopicsToFollow;
+ (BOOL)hideViewCount;
+ (BOOL)hidePremiumOffer;
+ (BOOL)hideTrendVideos;
+ (BOOL)forceTweetFullFrame;
+ (BOOL)stripTrackingParams;
+ (BOOL)alwaysFollowingPage;
+ (BOOL)changeBackground;
+ (bool)backgroundImage;
+ (BOOL)hideBookmarkButton;
+ (BOOL)voiceCreationEnabled;
+ (BOOL)dmReplyLater;
+ (BOOL)mediaUpload4k;
+ (BOOL)customVoice;
@end

