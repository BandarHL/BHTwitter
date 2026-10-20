//
//  BHTdownloadManager.m
//  BHT
//
//  Created by BandarHelal on 24/12/1441 AH.
//

#import "BHTManager.h"
#import "SettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import <stdatomic.h>

static atomic_uint_fast64_t BHTPreferenceCacheGeneration;

static NSCache<NSString *, NSNumber *> *BHTBooleanPreferenceCache(void) {
    static NSCache<NSString *, NSNumber *> *cache;
    static __unused id observer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 64;
        observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                                     object:NSUserDefaults.standardUserDefaults
                                                                      queue:nil
                                                                 usingBlock:^(__unused NSNotification *notification) {
            atomic_fetch_add_explicit(&BHTPreferenceCacheGeneration, 1, memory_order_acq_rel);
        }];
    });
    return cache;
}

static BOOL BHTCachedBoolForKey(NSString *key) {
    NSCache<NSString *, NSNumber *> *cache = BHTBooleanPreferenceCache();

    for (;;) {
        uint_fast64_t generation = atomic_load_explicit(&BHTPreferenceCacheGeneration, memory_order_acquire);
        NSNumber *cachedValue = [cache objectForKey:key];
        uint64_t packedValue = cachedValue.unsignedLongLongValue;
        if (cachedValue != nil &&
            (packedValue >> 1) == generation &&
            generation == atomic_load_explicit(&BHTPreferenceCacheGeneration, memory_order_acquire)) {
            return (packedValue & 1) != 0;
        }

        BOOL value = [[NSUserDefaults standardUserDefaults] boolForKey:key];
        packedValue = ((uint64_t)generation << 1) | (value ? 1 : 0);
        [cache setObject:@(packedValue) forKey:key];

        // 偏好读取期间发生变更时，重新读取以免旧值回填缓存。
        if (generation == atomic_load_explicit(&BHTPreferenceCacheGeneration, memory_order_acquire)) {
            return value;
        }
    }
}

@implementation BHTManager
+ (bool)isDMVideoCell:(T1InlineMediaView *)view {
    if (view.playerIconViewType == 4) {
        return true;
    } else {
        return false;
    }
}
+ (void)cleanCache {
    NSArray <NSURL *> *DocumentFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject] includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    for (NSURL *file in DocumentFiles) {
        if ([file.pathExtension.lowercaseString isEqualToString:@"mp4"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
    }
    
    NSArray <NSURL *> *TempFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:NSTemporaryDirectory()] includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    
    for (NSURL *file in TempFiles) {
        if ([file.pathExtension.lowercaseString isEqualToString:@"mp4"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"mov"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file.pathExtension.lowercaseString isEqualToString:@"tmp"]) {
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }
        if ([file hasDirectoryPath]) {
            if ([BHTManager isEmpty:file]) {
                [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
            }
        }
    }
}
+ (BOOL)isEmpty:(NSURL *)url {
    NSArray *FolderFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    if (FolderFiles.count == 0) {
        return true;
    } else {
        return false;
    }
}
+ (NSString *)getDownloadingPersent:(float)per {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:NSNumberFormatterPercentStyle];
    NSNumber *number = [NSNumber numberWithFloat:per];
    return [numberFormatter stringFromNumber:number];
}
+ (NSString *)getVideoQuality:(NSString *)url {
    NSMutableArray *q = [NSMutableArray new];
    NSArray *splits = [url componentsSeparatedByString:@"/"];
    for (int i = 0; i < [splits count]; i++) {
        NSString *item = [splits objectAtIndex:i];
        NSArray *dir = [item componentsSeparatedByString:@"x"];
        for (int k = 0; k < [dir count]; k++) {
            NSString *item2 = [dir objectAtIndex:k];
            if (!(item2.length == 0)) {
                if ([BHTManager doesContainDigitsOnly:item2]) {
                    if (!(item2.integerValue > 10000)) {
                        if (!(q.count == 2)) {
                            [q addObject:item2];
                        }
                    }
                }
            }
        }
    }
    if (q.count == 0) {
        return @"GIF";
    }
    return [NSString stringWithFormat:@"%@x%@", q.firstObject, q.lastObject];
}
+ (BOOL)isVideoCell:(id <T1StatusViewModel>)model {
    return model.isMediaEntityVideo || model.isGIF;
}
+ (void)save:(NSURL *)url {
    [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } error:nil];
}
+ (void)showSaveVC:(NSURL *)url {
    UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (is_iPad()) {
        acVC.popoverPresentationController.sourceView = topMostController().view;
        acVC.popoverPresentationController.sourceRect = CGRectMake(topMostController().view.bounds.size.width / 2.0, topMostController().view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    [topMostController() presentViewController:acVC animated:true completion:nil];
}

+ (MediaInformation *)getM3U8Information:(NSURL *)mediaURL {
    MediaInformationSession *mediaInformationSession = [FFprobeKit getMediaInformation:mediaURL.absoluteString];
    MediaInformation *mediaInformation = [mediaInformationSession getMediaInformation];
    return mediaInformation;
}
+ (UIAlertController *)newFFmpegDownloadSheet:(MediaInformation *)mediaInformation downloadingURL:(NSURL *)downloadingURL progressView:(JGProgressHUD *)hud {
    NSString *menuTitle = [[[BHTBundle sharedBundle] localizedStringForKey:@"DOWNLOAD_MENU_TITLE"]
                           stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:menuTitle
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleActionSheet];

    for (StreamInformation *stream in [mediaInformation getStreams]) {
        NSNumber *width = [stream getWidth];
        NSNumber *height = [stream getHeight];
        if (width != nil && height != nil) {
            NSString *resolution = [NSString stringWithFormat:@"%@x%@", width, height];
            UIAlertAction *downloadOption = [UIAlertAction actionWithTitle:resolution style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *selectedAction) {
                hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"PROGRESS_DOWNLOADING_STATUS_TITLE"];
                [hud showInView:topMostController().view];

                NSURL *newFilePath = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", NSUUID.UUID.UUIDString]];
                [FFmpegKit executeAsync:[NSString stringWithFormat:@"-i %@ -vf scale=%@:flags=lanczos -b:v 2M -c:a copy %@", downloadingURL.absoluteString, resolution, newFilePath.path] withCompleteCallback:^(FFmpegSession *session) {
                    ReturnCode *returnCode = [session getReturnCode];
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        if ([ReturnCode isSuccess:returnCode]) {
                            if (!([BHTManager DirectSave])) {
                                [hud dismiss];
                                [BHTManager showSaveVC:newFilePath];
                            } else {
                                [BHTManager save:newFilePath];
                            }
                        } else {
                            [hud dismiss];
                        }
                    });
                }];
            }];
            [alert addAction:downloadOption];
        }
    }

    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"]
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    return alert;
}
+ (BOOL)DownloadingVideos {
    return BHTCachedBoolForKey(@"dw_v");
}
+ (BOOL)DirectSave {
    return BHTCachedBoolForKey(@"direct_save");
}
+ (BOOL)LikeConfirm {
    return BHTCachedBoolForKey(@"like_con");
}
+ (BOOL)TweetConfirm {
    return BHTCachedBoolForKey(@"tweet_con");
}
+ (BOOL)FollowConfirm {
    return BHTCachedBoolForKey(@"follow_con");
}
+ (BOOL)HidePromoted {
    return BHTCachedBoolForKey(@"hide_promoted");
}
+ (BOOL)HideTopics {
    return BHTCachedBoolForKey(@"hide_topics");
}
+ (BOOL)HideReposts {
    return BHTCachedBoolForKey(@"hide_reposts");
}
+ (BOOL)DisableVODCaptions {
    return BHTCachedBoolForKey(@"dis_VODCaptions");
}
+ (BOOL)UndoTweet {
    return BHTCachedBoolForKey(@"undo_tweet");
}
+ (BOOL)NoHistory {
    return BHTCachedBoolForKey(@"no_his");
}
+ (BOOL)BioTranslate {
    return BHTCachedBoolForKey(@"bio_translate");
}
+ (BOOL)Padlock {
    return BHTCachedBoolForKey(@"padlock");
}
+ (BOOL)changeFont {
    return BHTCachedBoolForKey(@"en_font");
}
+ (BOOL)FLEX {
    return BHTCachedBoolForKey(@"flex_twitter");
}
+ (BOOL)autoHighestLoad {
    return BHTCachedBoolForKey(@"autoHighestLoad");
}
+ (BOOL)disableSensitiveTweetWarnings {
    return BHTCachedBoolForKey(@"disableSensitiveTweetWarnings");
}
+ (BOOL)showScrollIndicator {
    return BHTCachedBoolForKey(@"showScollIndicator");
}
+ (BOOL)CopyProfileInfo {
    return BHTCachedBoolForKey(@"CopyProfileInfo");
}
+ (BOOL)tweetToImage {
    return BHTCachedBoolForKey(@"TweetToImage");
}
+ (BOOL)hideSpacesBar {
    return BHTCachedBoolForKey(@"hide_spaces");
}
+ (BOOL)disableRTL {
    return BHTCachedBoolForKey(@"dis_rtl");
}
+ (BOOL)alwaysOpenSafari {
    return BHTCachedBoolForKey(@"openInBrowser");
}
+ (BOOL)hideWhoToFollow {
    return BHTCachedBoolForKey(@"hide_who_to_follow");
}
+ (BOOL)hideTopicsToFollow {
    return BHTCachedBoolForKey(@"hide_topics_to_follow");
}
+ (BOOL)hideViewCount {
    return BHTCachedBoolForKey(@"hide_view_count");
}
+ (BOOL)hidePremiumOffer {
    return BHTCachedBoolForKey(@"hide_premium_offer");
}
+ (BOOL)hideTrendVideos {
    return BHTCachedBoolForKey(@"hide_trend_videos");
}
+ (BOOL)forceTweetFullFrame {
    return BHTCachedBoolForKey(@"force_tweet_full_frame");
}
+ (BOOL)stripTrackingParams {
    return BHTCachedBoolForKey(@"strip_tracking_params");
}
+ (BOOL)alwaysFollowingPage {
    return BHTCachedBoolForKey(@"always_following_page");
}
+ (BOOL)changeBackground {
    return BHTCachedBoolForKey(@"change_msg_background");
}
+ (bool)backgroundImage {
    return BHTCachedBoolForKey(@"background_image");
}
+ (BOOL)hideBookmarkButton {
    return BHTCachedBoolForKey(@"hide_bookmark_button");
}
+ (BOOL)voiceCreationEnabled {
    return BHTCachedBoolForKey(@"voice_creation_enabled");
}
+ (BOOL)dmReplyLater {
    return BHTCachedBoolForKey(@"dm_reply_later_enabled");
}
+ (BOOL)mediaUpload4k {
    return BHTCachedBoolForKey(@"media_upload_4k_enabled");
}
+ (BOOL)customVoice {
    return BHTCachedBoolForKey(@"custom_voice_upload");
}
+ (UIViewController *)BHTSettingsWithAccount:(TFNTwitterAccount *)twAccount {
    SettingsViewController *pref = [[SettingsViewController alloc] initWithTwitterAccount:twAccount];
    [pref.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"BHTwitter" subtitle:twAccount.displayUsername]];
    return pref;
}

// https://stackoverflow.com/a/45356575/9910699
+ (BOOL)doesContainDigitsOnly:(NSString *)string {
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];

    BOOL containsDigitsOnly = [string rangeOfCharacterFromSet:nonDigits].location == NSNotFound;

    return containsDigitsOnly;
}

+ (BOOL)doesContainNonDigitsOnly:(NSString *)string {
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];

    BOOL containsNonDigitsOnly = [string rangeOfCharacterFromSet:digits].location == NSNotFound;

    return containsNonDigitsOnly;
}

@end
