//
//  BHTdownloadManager.m
//  BHT
//
//  Created by BandarHelal on 24/12/1441 AH.
//

#import "BHTManager.h"
#import "BHTwitter-Swift.h"
#import "BHTwitter+NSURL.h"

@implementation BHTManager
+ (float)TwitterVersion {
    NSString *ver = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    return [ver floatValue];
}
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
    TFSTwitterEntityMedia *i = model.entities.media.firstObject;
    if (i.videoInfo == nil) {
        return false;
    } else {
        return true;
    }
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
+ (BOOL)VoiceFeature {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"voice"];
}
+ (BOOL)voice_in_replay {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"voice_in_replay"];
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
+ (BOOL)ReaderMode {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"reader_mode"];
}
+ (BOOL)ReplyLater {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"reply_layer"];
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
+ (BOOL)DwbLayout {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"dwb_layout"];
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
+ (BOOL)DmModularSearch {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DmModularSearch"];
}
+ (BOOL)TwitterCircle {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"TrustedFriends"];
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
+ (UIViewController *)BHTSettingsWithAccount:(TFNTwitterAccount *)twAccount {
    HBPreferences *pref = [[HBPreferences alloc] initTableWithTableStyle:UITableViewStyleInsetGrouped title:@"BHTwitter" SeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    [pref.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"BHTwitter" subtitle:twAccount.displayUsername]];
    
    HBSection *mainSection = [HBSection sectionWithTitle:@"BHTwitter Preferences" footer:nil];
    HBSection *twitterBlueSection = [HBSection sectionWithTitle:@"Twitter blue features" footer:@"You may need to restart Twitter app to apply changes"];
    HBSection *layoutSection = [HBSection sectionWithTitle:@"Layout customization" footer:@"Restart Twitter app to apply changes"];
    HBSection *debug = [HBSection sectionWithTitle:@"Debugging" footer:nil];
    HBSection *legalSection = [HBSection sectionWithTitle:@"Legal notices" footer:nil];
    HBSection *developer = [HBSection sectionWithTitle:@"Developer" footer:@"BHTwitter v2.9.7"];
    
    HBSwitchCell *download = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Downloading videos" DetailTitle:@"Downloading videos. By adding button in tweet and inside video tab bar." switchKey:@"dw_v" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dw_v"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"dw_v"];
        }
    }];
    
    HBSwitchCell *direct_save = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Direct save" DetailTitle:@"Save video directly after downloading." switchKey:@"direct_save" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"direct_save"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"direct_save"];
        }
    }];
    
    HBSwitchCell *hide_ads = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Hide ads" DetailTitle:@"Remove all promoted tweet." switchKey:@"hide_promoted" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"hide_promoted"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"hide_promoted"];
        }
    }];
    
    HBSwitchCell *hide_topics = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Hide topics tweets" DetailTitle:@"Remove all topics tweets from the timeline." switchKey:@"hide_topics" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"hide_topics"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"hide_topics"];
        }
    }];
    
    HBSwitchCell *disable_VODCaptions = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Disable video layer captions" DetailTitle:nil switchKey:@"dis_VODCaptions" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dis_VODCaptions"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"dis_VODCaptions"];
        }
    }];
    
    HBSwitchCell *voice = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Voice feature" DetailTitle:@"Enable voice in tweet and DM." switchKey:@"voice" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"voice"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"voice"];
        }
    }];
    
    HBSwitchCell *voice_in_replay = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Voice feature in replay" DetailTitle:@"Enable voice in tweet replay." switchKey:@"voice_in_replay" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"voice_in_replay"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"voice_in_replay"];
        }
    }];
    
    HBSwitchCell *UndoTweet = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Undo tweets feature" DetailTitle:@"Undo tweets after tweeting." switchKey:@"undo_tweet" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"undo_tweet"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"undo_tweet"];
        }
    }];
    
    HBSwitchCell *ReaderMode = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Reader mode feature" DetailTitle:@"Enable reader mode in threads." switchKey:@"reader_mode" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"reader_mode"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"reader_mode"];
        }
    }];
    
    HBSwitchCell *ReplyLater = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Reply later feature" DetailTitle:@"Enable you to mark DM conversations as replay later." switchKey:@"reply_layer" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"reply_layer"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"reply_layer"];
        }
    }];
    
    HBSwitchCell *VideoZoom = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Video zoom feature" DetailTitle:@"You can zoom the video by double clicking in the center of the video." switchKey:@"video_zoom" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"video_zoom"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"video_zoom"];
        }
    }];
    
    HBSwitchCell *NoHistory = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"No search history" DetailTitle:@"Force Twitter to stop recording search history." switchKey:@"no_his" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"no_his"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"no_his"];
        }
    }];
    
    HBSwitchCell *BioTranslate = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Translate bio" DetailTitle:@"Show you a button in user bio to translate it." switchKey:@"bio_translate" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"bio_translate"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"bio_translate"];
        }
    }];
    
    HBSwitchCell *like_confirm = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Like confirm" DetailTitle:@"Show a confirm alert when you press like button." switchKey:@"like_con" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"like_con"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"like_con"];
        }
    }];
    
    HBSwitchCell *tweet_confirm = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Tweet confirm" DetailTitle:@"Show a confirm alert when you press tweet button." switchKey:@"tweet_con" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"tweet_con"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"tweet_con"];
        }
    }];
    
    HBSwitchCell *follow_confirm = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"User follow confirm" DetailTitle:@"Show a confirm alert when you press follow button." switchKey:@"follow_con" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"follow_con"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"follow_con"];
        }
    }];
    
    HBSwitchCell *padlock = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Padlock" DetailTitle:@"Lock Twitter with passcode." switchKey:@"padlock" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[keychain shared] saveDictionary:@{@"isAuthenticated": @YES}];
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"padlock"];
        } else {
            [[keychain shared] saveDictionary:@{@"isAuthenticated": @NO}];
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"padlock"];
        }
    }];
    
    HBSwitchCell *DmModularSearch = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Enable DM Modular Search" DetailTitle:@"Enable the new UI of DM search" switchKey:@"DmModularSearch" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"DmModularSearch"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"DmModularSearch"];
        }
    }];
    HBSwitchCell *autoHighestLoad = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Auto load photos in highest quality" DetailTitle:@"This option let you upload photos and load it in highest quality possible." switchKey:@"autoHighestLoad" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"autoHighestLoad"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"autoHighestLoad"];
        }
    }];
    
    HBSwitchCell *disableSensitiveTweetWarnings = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Disable sensitive tweet warning view" DetailTitle:nil switchKey:@"disableSensitiveTweetWarnings" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"disableSensitiveTweetWarnings"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"disableSensitiveTweetWarnings"];
        }
    }];
    
    HBSwitchCell *oldTweetStyle = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Disable edge to edge tweet style" DetailTitle:@"Force Twitter to use the old tweet style." switchKey:@"old_style" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"old_style"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"old_style"];
        }
    }];
    
    HBSwitchCell *trustedFriends = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Enable Twitter Circle feature" DetailTitle:nil switchKey:@"TrustedFriends" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"TrustedFriends"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"TrustedFriends"];
        }
    }];
    
    HBSwitchCell *copyProfileInfo = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Enable Copying profile information feature" DetailTitle:@"Add new button in Twitter profile that let you copy whatever info you want" switchKey:@"CopyProfileInfo" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"CopyProfileInfo"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"CopyProfileInfo"];
        }
    }];
    
    HBSwitchCell *tweetToImage = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Save tweet as an image" DetailTitle:@"You can export tweets as image, by long pressing on the Tweet Share button" switchKey:@"TweetToImage" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"TweetToImage"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"TweetToImage"];
        }
    }];
    
    HBSwitchCell *hideSpace = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Hide spaces bar" DetailTitle:nil switchKey:@"hide_spaces" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"hide_spaces"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"hide_spaces"];
        }
    }];
    
    HBSwitchCell *disableRTL = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Disable RTL" DetailTitle:@"Force Twitter use LTL with RTL language.\nRestart Twitter app to apply changes" switchKey:@"dis_rtl" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dis_rtl"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"dis_rtl"];
        }
    }];
    
    HBViewControllerCell *fontsPicker = [[HBViewControllerCell alloc] initCellWithTitle:@"Font" detail:[[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"] action:^UIViewController *{
        UIFontPickerViewControllerConfiguration *configuration = [[UIFontPickerViewControllerConfiguration alloc] init];
        [configuration setFilteredTraits:UIFontDescriptorClassMask];
        [configuration setIncludeFaces:false];
        UIFontPickerViewController *fontPicker = [[UIFontPickerViewController alloc] initWithConfiguration:configuration];
        [fontPicker setTitle:@"Choose Font"];
        fontPicker.delegate = pref;
        return fontPicker;
    }];
    HBViewControllerCell *BoldfontsPicker = [[HBViewControllerCell alloc] initCellWithTitle:@"Bold Font" detail:[[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"] action:^UIViewController *{
        UIFontPickerViewControllerConfiguration *configuration = [[UIFontPickerViewControllerConfiguration alloc] init];
        [configuration setIncludeFaces:true];
        [configuration setFilteredTraits:UIFontDescriptorClassModernSerifs];
        [configuration setFilteredTraits:UIFontDescriptorClassMask];
        UIFontPickerViewController *fontPicker = [[UIFontPickerViewController alloc] initWithConfiguration:configuration];
        [fontPicker setTitle:@"Choose Font"];
        fontPicker.delegate = pref;
        return fontPicker;
    }];
    
    HBViewControllerCell *CustomTabBarVC = [[HBViewControllerCell alloc] initCellWithTitle:@"Custom Tab Bar" detail:nil action:^UIViewController *{
        CustomTabBarViewController *customTabBArVC = [[CustomTabBarViewController alloc] init];
        [customTabBArVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"Custom Tab Bar" subtitle:twAccount.displayUsername]];
        return customTabBArVC;
    }];
    
    HBViewControllerCell *appTheme = [[HBViewControllerCell alloc] initCellWithTitle:@"Theme" detail:@"Choose a theme color for you Twitter experience that can only be seen by you." action:^UIViewController *{
//        I create my own Color Theme ViewController for two main reasons:
//        1- Twitter use swift to build their view controller, so I can't hook anything on it.
//        2- Twitter knows you do not actually subscribe with Twitter Blue, so it keeps resting the changes and resting 'T1ColorSettingsPrimaryColorOptionKey' key, so I had to create another key to track the original one and keep sure no changes, but it still not enough to keep the new theme after relaunching app, so i had to force the changes again with new lunch.
        BHColorThemeViewController *themeVC = [[BHColorThemeViewController alloc] init];
        [themeVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"Theme" subtitle:twAccount.displayUsername]];
        return themeVC;
    }];
    
    HBSwitchCell *font = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Enable changing font" DetailTitle:@"Option to allow changing Twitter font and show font picker." switchKey:@"en_font" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"en_font"];
            [layoutSection addCells:@[fontsPicker, BoldfontsPicker]];
            [pref.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:3 inSection:2], [NSIndexPath indexPathForRow:4 inSection:2]] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"en_font"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"bhtwitter_font_1"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"bhtwitter_font_2"];
            [layoutSection removeCells:@[fontsPicker, BoldfontsPicker]];
            [pref.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:3 inSection:2], [NSIndexPath indexPathForRow:4 inSection:2]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }];
    
    HBSwitchCell *dwbLayout = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Download button always on the trailing side" DetailTitle:@"Force the download button to be always in the trailing side." switchKey:@"dwb_layout" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dwb_layout"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"dwb_layout"];
        }
    }];
    
    HBSwitchCell *flex = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Enable FLEX" DetailTitle:@"Show FLEX on twitter app." switchKey:@"flex_twitter" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[FLEXManager sharedManager] showExplorer];
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"flex_twitter"];
        } else {
            [[FLEXManager sharedManager] hideExplorer];
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"flex_twitter"];
        }
    }];
    
    HBViewControllerCell *acknowledgements = [[HBViewControllerCell alloc] initCellWithTitle:@"Acknowledgements" detail:nil action:^UIViewController *{
        T1RichTextFormatViewController *acknowledgementsVC = [[objc_getClass("T1RichTextFormatViewController") alloc] initWithRichTextFormatDocumentPath:[NSURL bhtwitter_fileURLWithPath:@"Acknowledgements.rtf"].path];
        [acknowledgementsVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"Acknowledgements" subtitle:twAccount.displayUsername]];
        return acknowledgementsVC;
    }];
    
    HBTwitterCell *bandarhl = [[HBTwitterCell alloc] initTwitterCellWithTitle:@"BandarHelal" detail:@"@BandarHL" AccountLink:@"https://twitter.com/BandarHL"];
    HBlinkCell *tipJar = [[HBlinkCell alloc] initLinkCellWithTitle:@"Tip Jar" detailTitle:@"Donate" link:@"https://www.paypal.me/BandarHL"];
    HBGithubCell *sourceCode = [[HBGithubCell alloc] initGithubCellWithTitle:@"BHTwitter" detailTitle:@"Code source of BHTwitter" GithubURL:@"https://github.com/BandarHL/BHTwitter/"];
    
    
    [mainSection addCells:@[download, hide_ads, hide_topics, disable_VODCaptions, direct_save, voice, voice_in_replay, ReplyLater, VideoZoom, NoHistory, BioTranslate, like_confirm, tweet_confirm, follow_confirm, padlock, DmModularSearch, autoHighestLoad, disableSensitiveTweetWarnings, copyProfileInfo, tweetToImage, hideSpace, disableRTL]];
    
    [twitterBlueSection addCells:@[UndoTweet, ReaderMode, trustedFriends, appTheme, CustomTabBarVC]];
    [layoutSection addCells:@[oldTweetStyle, dwbLayout, font]];
    if ([BHTManager changeFont]) {
        [layoutSection addCells:@[fontsPicker, BoldfontsPicker]];
    }
    
    [debug addCell:flex];
    [legalSection addCell:acknowledgements];
    [developer addCells:@[bandarhl, sourceCode, tipJar]];

    [pref addSections:@[mainSection, twitterBlueSection, layoutSection, debug, legalSection, developer]];
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

