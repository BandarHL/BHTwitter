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
+ (float)TwitterVersion;

+ (BOOL)DownloadingVideos;
+ (BOOL)DirectSave;
+ (BOOL)VoiceFeature;
+ (BOOL)voice_in_replay;
+ (BOOL)UndoTweet;
+ (BOOL)ReaderMode;
+ (BOOL)ReplyLater;
+ (BOOL)VideoZoom;
+ (BOOL)NoHistory;
+ (BOOL)BioTranslate;
+ (BOOL)LikeConfirm;
+ (BOOL)TweetConfirm;
+ (BOOL)FollowConfirm;
+ (BOOL)HidePromoted;
+ (BOOL)HideTopics;
+ (BOOL)DisableVODCaptions;
+ (BOOL)Padlock;
+ (BOOL)OldStyle;
+ (BOOL)DwbLayout;
+ (BOOL)changeFont;
+ (BOOL)FLEX;
+ (BOOL)autoHighestLoad;
+ (BOOL)DmModularSearch;
+ (BOOL)disableSensitiveTweetWarnings;
+ (BOOL)TwitterCircle;
+ (BOOL)CopyProfileInfo;
+ (BOOL)tweetToImage;
+ (BOOL)hideSpacesBar;
+ (BOOL)disableRTL;
@end

