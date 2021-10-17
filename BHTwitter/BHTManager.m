//
//  BHTdownloadManager.m
//  BHT
//
//  Created by BandarHelal on 24/12/1441 AH.
//

#import "BHTManager.h"


@implementation BHTManager
+ (BOOL)isDeviceLanguageRTL {
  return ([NSLocale characterDirectionForLanguage:[[NSLocale preferredLanguages] objectAtIndex:0]] == NSLocaleLanguageDirectionRightToLeft);
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
+ (BOOL)isVideoCell:(T1StatusInlineActionsView *)cell {
    TFSTwitterEntityMedia *i = cell.viewModel.entities.media.firstObject;
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
+ (BOOL)tipjar {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"Tipjar"];
}

+ (BOOL)LikeConfirm {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"like_con"];
}
+ (BOOL)TweetConfirm {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"tweet_con"];
}
+ (BOOL)HidePromoted {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"hide_promoted"];
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
+ (BOOL)Padlock {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"padlock"];
}
+ (BOOL)OldStyle {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"old_style"];
}
+ (BOOL)DwbLayout {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"dwb_layout"];
}
+ (BOOL)FLEX {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"flex_twitter"];
}
+ (UIViewController *)BHTSettings {
    HBSection *main_section = [HBSection sectionWithTitle:@"BHTwitter Preferences" footer:nil];
    HBSection *layout_section = [HBSection sectionWithTitle:@"Layout customization" footer:nil];
    HBSection *debug = [HBSection sectionWithTitle:@"Debugging" footer:nil];
    HBSection *developer = [HBSection sectionWithTitle:@"Developer" footer:nil];
    
    HBSwitchCell *download = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Downloading videos" DetailTitle:@"This option will enable downloading videos" switchKey:@"dw_v" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dw_v"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"dw_v"];
        }
    }];
    
    HBSwitchCell *direct_save = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Direct save" DetailTitle:@"Save video directly after downloading" switchKey:@"direct_save" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"direct_save"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"direct_save"];
        }
    }];
    
    HBSwitchCell *hide_ads = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Hide ads" DetailTitle:@"This option will remove all promoted tweet" switchKey:@"hide_promoted" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"hide_promoted"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"hide_promoted"];
        }
    }];
    
    HBSwitchCell *voice = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Voice feature" DetailTitle:@"This option will enable voice in tweet and DM" switchKey:@"voice" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"voice"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"voice"];
        }
    }];
    HBSwitchCell *voice_in_replay = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Voice feature in replay" DetailTitle:@"This option will enable voice in tweet replay" switchKey:@"voice_in_replay" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"voice_in_replay"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"voice_in_replay"];
        }
    }];
    HBSwitchCell *Tipjar = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Tip Jar feature" DetailTitle:@"This option will enable Tip Jar feature" switchKey:@"Tipjar" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"Tipjar"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"Tipjar"];
        }
    }];
    HBSwitchCell *UndoTweet = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Undo tweets feature" DetailTitle:@"Undo tweets after tweeting" switchKey:@"undo_tweet" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"undo_tweet"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"undo_tweet"];
        }
    }];
    HBSwitchCell *ReaderMode = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Reader mode feature" DetailTitle:@"This option will enable reader mode in threads" switchKey:@"reader_mode" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"reader_mode"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"reader_mode"];
        }
    }];
    HBSwitchCell *ReplyLater = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Reply later feature" DetailTitle:@"This option will enable you to mark DM conversations as replay later" switchKey:@"reply_layer" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"reply_layer"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"reply_layer"];
        }
    }];
    HBSwitchCell *VideoZoom = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Video zoom feature" DetailTitle:@"You can zoom the video by dobule clicking in the center of the video" switchKey:@"video_zoom" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"video_zoom"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"video_zoom"];
        }
    }];
    HBSwitchCell *like_confirm = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Like confirm" DetailTitle:@"Show a confirm alert when you press like button" switchKey:@"like_con" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"like_con"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"like_con"];
        }
    }];
    HBSwitchCell *tweet_confirm = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Tweet confirm" DetailTitle:@"Show a confirm alert when you press tweet button" switchKey:@"tweet_con" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"tweet_con"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"tweet_con"];
        }
    }];
    HBSwitchCell *padlock = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Padlock" DetailTitle:@"Lock Twitter with passcode" switchKey:@"padlock" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[keychain shared] saveDictionary:@{@"isAuthenticated": @YES}];
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"padlock"];
        } else {
            //            [[keychain shared] deleteService];
            [[keychain shared] saveDictionary:@{@"isAuthenticated": @NO}];
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"padlock"];
        }
    }];
    
    HBSwitchCell *oldTweetStyle = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Disable edge to edge tweet style" DetailTitle:@"Force Twitter to use the old tweet style" switchKey:@"old_style" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"old_style"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"old_style"];
        }
    }];
    
//    HBViewControllerCell *icons = [[HBViewControllerCell alloc] initCellWithTitle:@"Change Twitter icon" detail:@"Use Twitter alertnative icons" action:^UIViewController *{
//        UIViewController *v = UIViewController.new;
//        [v.view setBackgroundColor:UIColor.redColor];
//        return v;
//    }];
    
    HBSwitchCell *dwbLayout = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Download button always on the trailing side" DetailTitle:@"Force the download button to be always in the trailing side" switchKey:@"dwb_layout" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dwb_layout"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"dwb_layout"];
        }
    }];
    
    HBSwitchCell *flex = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Enable FLEX" DetailTitle:@"Show FLEX on twitter app" switchKey:@"flex_twitter" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[FLEXManager sharedManager] showExplorer];
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"flex_twitter"];
        } else {
            [[FLEXManager sharedManager] hideExplorer];
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"flex_twitter"];
        }
    }];
    
    HBTwitterCell *bandarhl = [[HBTwitterCell alloc] initTwitterCellWithTitle:@"BandarHelal" detail:@"@BandarHL" AccountLink:@"https://twitter.com/BandarHL"];
    HBGithubCell *sourceCode = [[HBGithubCell alloc] initGithubCellWithTitle:@"BHTwitter" detailTitle:@"Code source of BHTwitter" GithubURL:@"https://github.com/BandarHL/BHTwitter/"];
    
    
    [main_section addCells:@[download, hide_ads, direct_save, voice, voice_in_replay, Tipjar, UndoTweet, ReaderMode, ReplyLater, VideoZoom, like_confirm, tweet_confirm, padlock]];
    
    [layout_section addCells:@[oldTweetStyle, dwbLayout]];
//    [layout_section addCell:icons];
    [debug addCell:flex];
    [developer addCells:@[bandarhl, sourceCode]];
    
    HBPreferences *pref = [HBPreferences tableWithSections:@[main_section, layout_section, debug, developer] title:@"BHTwitter" TableStyle:UITableViewStyleInsetGrouped SeparatorStyle:UITableViewCellSeparatorStyleNone];
    return pref;
}
+ (void)showSettings:(UIViewController *)_self {
    [_self.navigationController pushViewController:[BHTManager BHTSettings] animated:true];
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

