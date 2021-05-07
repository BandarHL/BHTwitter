#import <UIKit/UIKit.h>
#import "TWHeaders.h"
#import "BHTManager.h"
#import "Colours.h"

%config(generator=internal)
JGProgressHUD *hud;

%hook T1AppDelegate

- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"FirstRun"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"1strun" forKey:@"FirstRun"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dw_v"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"hide_promoted"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"voice"];
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"like_con"];
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"tweet_con"];
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"direct_save"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [BHTManager cleanCache];
    if ([BHTManager FLEX]) {
        [[FLEXManager sharedManager] showExplorer];
    }
    return true;
}
%end

// credit goes to haoict https://github.com/haoict/twitter-no-ads
%hook TFNItemsDataViewController
- (id)tableViewCellForItem:(id)arg1 atIndexPath:(id)arg2 {
    UITableViewCell *_orig = %orig;
    if ([BHTManager HidePromoted]) {
        id tweet = [self itemAtIndexPath:arg2];
        if ([tweet isKindOfClass:NSClassFromString(@"TFNTwitterStatus")]) {
            TFNTwitterStatus *fullTweet = tweet;
            if (fullTweet.isPromoted) {
                [_orig setHidden:true];
                return _orig;
            }
        }
    }
    return _orig;
}
- (double)tableView:(id)arg1 heightForRowAtIndexPath:(id)arg2 {
    if ([BHTManager HidePromoted]) {
        id tweet = [self itemAtIndexPath:arg2];
        if ([tweet isKindOfClass:NSClassFromString(@"TFNTwitterStatus")]) {
            TFNTwitterStatus *fullTweet = tweet;
            if (fullTweet.isPromoted) {
                return 0;
            } else {
                return %orig;
            }
        }
    }
    return %orig;
}
%end

%hook T1DirectMessageEntryMediaCell
- (id)initWithFrame:(struct CGRect)arg1 {
    if ([BHTManager DownloadingVideos]) {
        UILongPressGestureRecognizer *longGes = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(DownloadHandler)];
        [self addGestureRecognizer:longGes];
    }
    return %orig(arg1);
}
%new - (void)DownloadHandler {
    if ([BHTManager isDMVideoCell:self.inlineMediaView]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hi" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        T1PlayerMediaEntitySessionProducible *session = self.inlineMediaView.viewModel.playerSessionProducer.sessionProducible;
        for (TFSTwitterEntityMediaVideoVariant *i in session.mediaEntity.videoInfo.variants) {
            if ([i.contentType isEqualToString:@"video/mp4"]) {
                UIAlertAction *download = [UIAlertAction actionWithTitle:[BHTManager getVideoQuality:i.url] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    BHDownload *DownloadManager = [[BHDownload alloc] initWithBackgroundSessionID:NSUUID.UUID.UUIDString];
                    hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                    hud.textLabel.text = @"Downloading";
                    [DownloadManager downloadFileWithURL:[NSURL URLWithString:i.url]];
                    [DownloadManager setDelegate:self];
                    [hud showInView:topMostController().view];
                }];
                [alert addAction:download];
            }
        }
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [topMostController() presentViewController:alert animated:true completion:nil];
    }
}
%new - (void)downloadProgress:(float)progress {
    hud.detailTextLabel.text = [BHTManager getDownloadingPersent:progress];
}

%new - (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)fileName {
    NSString *DocPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *newFilePath = [[NSURL fileURLWithPath:DocPath] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", NSUUID.UUID.UUIDString]];
    [manager moveItemAtURL:filePath toURL:newFilePath error:nil];
    [hud dismiss];
    [BHTManager showSaveVC:newFilePath];
}
%new - (void)downloadDidFailureWithError:(NSError *)error {
    if (error) {
        [hud dismiss];
    }
}
%end

%hook T1AppEventHandler
- (void)_t1_configureRightToLeftSupport {
    return;
}
%end

%hook T1StatusBodyTextView
- (_Bool)openURL {
    if ([self.viewModel isKindOfClass:NSClassFromString(@"TFNTwitterStatus")]) {
        TFNTwitterStatus *tweet = self.viewModel;
        if ([tweet.mediaScribeContentID containsString:@"youtube"]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:tweet.mediaScribeContentID] options:@{} completionHandler:nil];
            return true;
        } else {
            return %orig;
        }
    }
    return %orig;
}
%end

%hook T1StandardStatusView
- (void)setViewModel:(id)arg1 options:(unsigned long long)arg2 account:(id)arg3 {
    %orig;
    if ([BHTManager DownloadingVideos]) {
        T1StatusInlineActionsView *vis = self.visibleInlineActionsView;
        [vis appendNewButton];
    }
}
%end

%hook T1StatusInlineActionsView
%new - (void)appendNewButton {
    if ([BHTManager isVideoCell:self]) {
        UIButton *newButton = [UIButton buttonWithType:UIButtonTypeCustom];
        if (@available(iOS 13.0, *)) {
            [newButton setImage:[UIImage systemImageNamed:@"arrow.down"] forState:UIControlStateNormal];
        } else {
            [newButton setImage:[UIImage imageNamed:@"/Library/Application Support/BHT/Ressources.bundle/Regular"] forState:UIControlStateNormal];
        }
        [newButton addTarget:self action:@selector(DownloadHandler) forControlEvents:UIControlEventTouchUpInside];
        [newButton setTranslatesAutoresizingMaskIntoConstraints:false];
        [newButton setTintColor:[UIColor colorFromHexString:@"6D6E70"]];
        [self addSubview:newButton];
        
        TFNButton *lastButton = self.inlineActionButtons.lastObject;
        [NSLayoutConstraint activateConstraints:@[
            [newButton.heightAnchor constraintEqualToConstant:24],
            [newButton.widthAnchor constraintEqualToConstant:30],
            [newButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [newButton.leadingAnchor constraintEqualToAnchor:lastButton.trailingAnchor constant:13]
        ]];

    }
}
%new - (void)DownloadHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hi" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (TFSTwitterEntityMedia *i in self.viewModel.entities.media) {
        for (TFSTwitterEntityMediaVideoVariant *k in i.videoInfo.variants) {
            if ([k.contentType isEqualToString:@"video/mp4"]) {
                UIAlertAction *download = [UIAlertAction actionWithTitle:[BHTManager getVideoQuality:k.url] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    BHDownload *DownloadManager = [[BHDownload alloc] initWithBackgroundSessionID:NSUUID.UUID.UUIDString];
                    [DownloadManager downloadFileWithURL:[NSURL URLWithString:k.url]];
                    [DownloadManager setDelegate:self];
                    if (!([BHTManager DirectSave])) {
                        hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                        hud.textLabel.text = @"Downloading";
                        [hud showInView:topMostController().view];
                    }
                }];
                [alert addAction:download];
            }
        }
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [topMostController() presentViewController:alert animated:true completion:nil];
}
%new - (void)downloadProgress:(float)progress {
    hud.detailTextLabel.text = [BHTManager getDownloadingPersent:progress];
}

%new - (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)fileName {
    NSString *DocPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *newFilePath = [[NSURL fileURLWithPath:DocPath] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", NSUUID.UUID.UUIDString]];
    [manager moveItemAtURL:filePath toURL:newFilePath error:nil];
    if (!([BHTManager DirectSave])) {
        [hud dismiss];
        [BHTManager showSaveVC:newFilePath];
    } else {
        [BHTManager save:newFilePath];
    }
}
%new - (void)downloadDidFailureWithError:(NSError *)error {
    if (error) {
        [hud dismiss];
    }
}
%end

%hook TFNTwitterComposition
- (BOOL)isReply {
    if ([BHTManager voice_in_replay]) {
        return false;
    } else {
        return %orig;
    }
}
%end

%hook TFNTwitterAccount
- (BOOL)isProfileTipJarSettingsEnabled {
    if ([BHTManager tipjar]) {
        return true;
    } else {
        return %orig;
    }
}
- (bool)isVODInlineAudioToggleEnabled {
    return true;
}
- (_Bool)isConversationThreadingVoiceOverSupportEnabled {
    if ([BHTManager VoiceFeature]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)isDMVoiceRenderingEnabled {
    if ([BHTManager VoiceFeature]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)isDMVoiceCreationEnabled {
    if ([BHTManager VoiceFeature]) {
        return true;
    } else {
        return %orig;
    }
}
%end
%hook TFNTwitterComposition
- (BOOL)hasVoiceRecordingAttachment {
    if ([BHTManager VoiceFeature]) {
        return true;
    } else {
        return %orig;
    }
}
%end

%hook T1MediaAutoplaySettings
- (_Bool)voiceOverEnabled {
    if ([BHTManager VoiceFeature]) {
        return true;
    } else {
        return %orig;
    }
}
- (void)setVoiceOverEnabled:(_Bool)arg1 {
    if ([BHTManager VoiceFeature]) {
        arg1 = true;
    }
    return %orig(arg1);
}
%end

%hook T1PhotoMediaRailViewController
- (void)setVoiceButtonHidden:(BOOL)arg1 {
    if ([BHTManager VoiceFeature]) {
        arg1 = false;
    }
    return %orig(arg1);
}
- (BOOL)isVoiceButtonHidden {
    if ([BHTManager VoiceFeature]) {
        return false;
    }
    return %orig;
}
%end

%hook T1TweetComposeViewController
- (void)_t1_handleTweet {
    if ([BHTManager TweetConfirm]) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.message(@"Are you sure?");
            make.button(@"Yes").handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button(@"No").cancelStyle();
        } showFrom:self];
    } else {
        return %orig;
    }
}
%end

%hook T1StatusInlineFavoriteButton
- (void)didTap {
    if ([BHTManager LikeConfirm]) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.message(@"Are you sure?");
            make.button(@"Yes").handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button(@"No").cancelStyle();
        } showFrom:topMostController()];
    } else {
        return %orig;
    }
}
%end


%hook T1TweetDetailsViewController
- (void)_t1_toggleFavoriteOnCurrentStatus {
    if ([BHTManager LikeConfirm]) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.message(@"Are you sure?");
            make.button(@"Yes").handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button(@"No").cancelStyle();
        } showFrom:topMostController()];
    } else {
        return %orig;
    }
}
%end


%hook T1SettingsViewController
- (void)viewWillAppear:(BOOL)arg1 {
    %orig;
    if ([self.sections count] == 2) {
        TFNItemsDataViewControllerBackingStore *DataViewControllerBackingStore = self.backingStore;
        [DataViewControllerBackingStore insertSection:0 atIndex:0];
        [DataViewControllerBackingStore insertItem:@"Row 0 " atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        [DataViewControllerBackingStore insertItem:@"Row1" atIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row ==1 ) {
        
        TFNTextCell *Tweakcell = [[%c(TFNTextCell) alloc] init];
        [Tweakcell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [Tweakcell.textLabel setText:@"BHTwitter"];
        return Tweakcell;
    } else if (indexPath.section == 0 && indexPath.row ==0 ) {
        
        TFNTextCell *Settingscell = [[%c(TFNTextCell) alloc] init];
        [Settingscell setBackgroundColor:[UIColor clearColor]];
        Settingscell.textLabel.textColor = [UIColor colorWithRed:0.40 green:0.47 blue:0.53 alpha:1.0];
        [Settingscell.textLabel setText:@"Settings"];
        return Settingscell;
    }
    
    
    return %orig;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath section]== 0 && [indexPath row]== 1) {
        [BHTManager showSettings:self];
    } else {
        return %orig;
    }
}
%end



// Fix login keychain in non-JB (IPA).
//%hook TFSKeychain
//- (NSString *)providerDefaultAccessGroup {
//    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
//                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
//                           @"bundleSeedID", kSecAttrAccount,
//                           @"", kSecAttrService,
//                           (id)kCFBooleanTrue, kSecReturnAttributes,
//                           nil];
//    CFDictionaryRef result = nil;
//    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
//    if (status == errSecItemNotFound)
//        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
//        if (status != errSecSuccess)
//            return nil;
//    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
//    
//    return accessGroup;
//}
//- (NSString *)providerSharedAccessGroup {
//    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
//                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
//                           @"bundleSeedID", kSecAttrAccount,
//                           @"", kSecAttrService,
//                           (id)kCFBooleanTrue, kSecReturnAttributes,
//                           nil];
//    CFDictionaryRef result = nil;
//    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
//    if (status == errSecItemNotFound)
//        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
//        if (status != errSecSuccess)
//            return nil;
//    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
//    
//    return accessGroup;
//}
//%end

//%hook TFSKeychainDefaultTwitterConfiguration
//- (NSString *)defaultAccessGroup {
//    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
//                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
//                           @"bundleSeedID", kSecAttrAccount,
//                           @"", kSecAttrService,
//                           (id)kCFBooleanTrue, kSecReturnAttributes,
//                           nil];
//    CFDictionaryRef result = nil;
//    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
//    if (status == errSecItemNotFound)
//        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
//        if (status != errSecSuccess)
//            return nil;
//    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
//    
//    return accessGroup;
//}
//- (NSString *)sharedAccessGroup {
//    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
//                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
//                           @"bundleSeedID", kSecAttrAccount,
//                           @"", kSecAttrService,
//                           (id)kCFBooleanTrue, kSecReturnAttributes,
//                           nil];
//    CFDictionaryRef result = nil;
//    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
//    if (status == errSecItemNotFound)
//        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
//        if (status != errSecSuccess)
//            return nil;
//    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
//    
//    return accessGroup;
//}
//%end
