//
//  BHTdownloadManager.m
//  BHT
//
//  Created by BandarHelal on 24/12/1441 AH.
//

#import "BHTdownloadManager.h"

@implementation BHTdownloadManager
+ (void)DownloadVideoWithURL:(NSString *)url completionHandler:(void (^)(NSURL *filePath, NSError *error))completionHandler {
    NSError *err;
    NSString *documentsDirectoryURL = [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), @"Documents"];
    NSURL *fileURL = [NSURL URLWithString:url];
    NSString *fileName = fileURL.lastPathComponent;
    NSString *downloadPath = [documentsDirectoryURL stringByAppendingPathComponent:fileName];
    NSURL *downloadPathURL = [NSURL fileURLWithPath:downloadPath];
    
    NSData *dataFile = [NSData dataWithContentsOfURL:fileURL];
    if (dataFile) {
        [dataFile writeToFile:downloadPath options:nil error:&err];
    }
    
    completionHandler(downloadPathURL, err);
}
+ (BOOL)isVideoCell:(T1StatusInlineActionsView *)cell {
    TFSTwitterEntityMedia *i = cell.viewModel.entities.media.firstObject;
    if (i.videoInfo == nil) {
        return false;
    } else {
        return true;
    }
}
+ (BOOL)isDMVideoCell:(T1InlineMediaView *)cell {
    if (cell.playerIconView == nil) {
        return false;
    } else {
        return true;
    }
}

+ (BOOL)isLTR {
    if ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) {
        return false;
    } else {
        return true;
    }
}

+ (void)showSaveingViewController:(NSURL *)url {
    UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    [topMostController() presentViewController:acVC animated:true completion:nil];
}

+ (void)showSettings:(UIViewController *)_self {
    HBSection *main_section = [HBSection sectionWithTitle:@"BHTwitter Preferences" footer:nil];
    HBSection *developer = [HBSection sectionWithTitle:@"Developer" footer:nil];
    
    HBSwitchCell *download = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Downloading videos" DetailTitle:@"this option will enabel downloading videos" switchKey:@"dw_v" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dw_v"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"dw_v"];
        }
    }];
    
    HBSwitchCell *voice = [[HBSwitchCell alloc] initSwitchCellWithImage:nil Title:@"Voice Feature" DetailTitle:@"this option will enabel voice in tweet and DM" switchKey:@"voice" withBlock:^(UISwitch *weakSender) {
        if (weakSender.isOn) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"voice"];
        } else {
            [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"voice"];
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
    HBTwitterCell *bandarhl = [[HBTwitterCell alloc] initTwitterCellWithTitle:@"BandarHelal" detail:@"@BandarHL" AccountLink:@"https://twitter.com/BandarHL"];
//    HBTwitterCell *c = [[HBTwitterCell alloc] initTwitterCellWithTitle:@"CrazyMind" detail:@"@CrazyMind90" AccountLink:@"https://twitter.com/CrazyMind90"];
    
    [main_section addCell:download];
    [main_section addCell:voice];
    [main_section addCell:like_confirm];
    [main_section addCell:tweet_confirm];
    [developer addCell:bandarhl];
//    [developer addCell:c];
    HBPreferences *hollow_pref = [HBPreferences tableWithSections:@[main_section, developer] title:@"BHTwitter" TableStyle:UITableViewStyleGrouped SeparatorStyle:UITableViewCellSeparatorStyleNone];
    [_self.navigationController pushViewController:hollow_pref animated:true];
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
