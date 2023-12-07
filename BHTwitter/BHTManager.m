//
//  BHTdownloadManager.m
//  BHT
//
//  Created by BandarHelal on 24/12/1441 AH.
//

#import "BHTManager.h"
#import "SettingsViewController.h"

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

+ (BOOL)DownloadingVideos {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"dw_v"];
}
+ (BOOL)DirectSave {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"direct_save"];
}
+ (BOOL)LikeConfirm {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"like_con"];
}
+ (BOOL)TweetConfirm {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"tweet_con"];
}
+ (BOOL)FollowConfirm {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"follow_con"];
}
+ (BOOL)HidePromoted {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_promoted"];
}
+ (BOOL)HideTopics {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_topics"];
}
+ (BOOL)DisableVODCaptions {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"dis_VODCaptions"];
}
+ (BOOL)UndoTweet {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"undo_tweet"];
}
+ (BOOL)VideoZoom {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"video_zoom"];
}
+ (BOOL)NoHistory {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"no_his"];
}
+ (BOOL)BioTranslate {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"bio_translate"];
}
+ (BOOL)Padlock {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"padlock"];
}
+ (BOOL)OldStyle {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"old_style"];
}
+ (BOOL)changeFont {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"en_font"];
}
+ (BOOL)FLEX {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"flex_twitter"];
}
+ (BOOL)autoHighestLoad {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"autoHighestLoad"];
}
+ (BOOL)disableSensitiveTweetWarnings {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"disableSensitiveTweetWarnings"];
}
+ (BOOL)TwitterCircle {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"TrustedFriends"];
}
+ (BOOL)showScrollIndicator {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"showScollIndicator"];
}
+ (BOOL)CopyProfileInfo {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"CopyProfileInfo"];
}
+ (BOOL)tweetToImage {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"TweetToImage"];
}
+ (BOOL)hideSpacesBar {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_spaces"];
}
+ (BOOL)disableRTL {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"dis_rtl"];
}
+ (BOOL)alwaysOpenSafari {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"openInBrowser"];
}
+ (BOOL)hideWhoToFollow {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_who_to_follow"];
}
+ (BOOL)hideTopicsToFollow {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_topics_to_follow"];
}
+ (BOOL)hideViewCount {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_view_count"];
}
+ (BOOL)forceTweetFullFrame {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"force_tweet_full_frame"];
}
+ (BOOL)stripTrackingParams {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"strip_tracking_params"];
}
+ (BOOL)copyAsVxTwitter {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"copy_as_vxtwitter"];
}
+ (BOOL)disableImmersive {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"disable_immersive_player"];
}
+ (BOOL)alwaysFollowingPage {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"always_following_page"];
}
+ (BOOL)stopHidingTabBar {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"no_tab_bar_hiding"];
}
+ (BOOL)advancedSearch {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"advanced_search"];
}
+ (BOOL)changeBackground {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"change_msg_background"];
}
+ (bool)backgroundImage {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"background_image"];
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

