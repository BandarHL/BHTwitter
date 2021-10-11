#import <UIKit/UIKit.h>
#import "BHTManager.h"
#import "SAMKeychain/AuthViewController.h"
#import "Colours.h"

// MARK: Clean cache and Padlock
%hook T1AppDelegate
- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"FirstRun"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"1strun" forKey:@"FirstRun"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dw_v"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"hide_promoted"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"voice"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"undo_tweet"];
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

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;
    if ([BHTManager Padlock]) {
        NSDictionary *keychainData = [[keychain shared] getData];
        if (keychainData != nil) {
            id isAuthenticated = [keychainData valueForKey:@"isAuthenticated"];
            if (isAuthenticated == nil || [isAuthenticated isEqual:@NO]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    AuthViewController *auth = [[AuthViewController alloc] init];
                    [auth setModalPresentationStyle:UIModalPresentationFullScreen];
                    [self.window.rootViewController presentViewController:auth animated:true completion:nil];
                });
            }
        }
        UIImageView *image = [self.window viewWithTag:909];
        if (image != nil) {
            [image removeFromSuperview];
        }
    }
}

- (void)applicationWillTerminate:(id)arg1 {
    %orig;
    if ([BHTManager Padlock]) {
        [[keychain shared] saveDictionary:@{@"isAuthenticated": @NO}];
    }
}

- (void)applicationWillResignActive:(id)arg1 {
    %orig;
    if ([BHTManager Padlock]) {
        UIImageView *image = [[UIImageView alloc] initWithFrame:self.window.bounds];
        [image setTag:909];
        [image setBackgroundColor:UIColor.systemBackgroundColor];
        [image setContentMode:UIViewContentModeCenter];
        [self.window addSubview:image];
    }
}
%end

// MARK: hide ADs
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
        if ([tweet isKindOfClass:NSClassFromString(@"T1URTTimelineStatusItemViewModel")]) {
            T1URTTimelineStatusItemViewModel *fullTweet = tweet;
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
        if ([tweet isKindOfClass:NSClassFromString(@"T1URTTimelineStatusItemViewModel")]) {
            T1URTTimelineStatusItemViewModel *fullTweet = tweet;
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

// MARK: DM download
%hook T1DirectMessageEntryMediaCell
%property (nonatomic, strong) JGProgressHUD *hud;
- (void)setEntryViewModel:(id)arg1 {
    %orig;
    if ([BHTManager DownloadingVideos]) {
        UIContextMenuInteraction *menuInteraction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
        [self setUserInteractionEnabled:true];
        
        if ([BHTManager isDMVideoCell:self.inlineMediaView]) {
            [self addInteraction:menuInteraction];
        }
    }
}
%new - (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        UIAction *saveAction = [UIAction actionWithTitle:@"Download" image:[UIImage systemImageNamed:@"square.and.arrow.down"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self DownloadHandler];
        }];
        return [UIMenu menuWithTitle:@"" children:@[saveAction]];
    }];
}
%new - (void)DownloadHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hi" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    T1PlayerMediaEntitySessionProducible *session = self.inlineMediaView.viewModel.playerSessionProducer.sessionProducible;
    for (TFSTwitterEntityMediaVideoVariant *i in session.mediaEntity.videoInfo.variants) {
        if ([i.contentType isEqualToString:@"video/mp4"]) {
            UIAlertAction *download = [UIAlertAction actionWithTitle:[BHTManager getVideoQuality:i.url] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                BHDownload *DownloadManager = [[BHDownload alloc] initWithBackgroundSessionID:NSUUID.UUID.UUIDString];
                self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                self.hud.textLabel.text = @"Downloading";
                [DownloadManager downloadFileWithURL:[NSURL URLWithString:i.url]];
                [DownloadManager setDelegate:self];
                [self.hud showInView:topMostController().view];
            }];
            [alert addAction:download];
        }
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [topMostController() presentViewController:alert animated:true completion:nil];
}
%new - (void)downloadProgress:(float)progress {
    self.hud.detailTextLabel.text = [BHTManager getDownloadingPersent:progress];
}

%new - (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)fileName {
    NSString *DocPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *newFilePath = [[NSURL fileURLWithPath:DocPath] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", NSUUID.UUID.UUIDString]];
    [manager moveItemAtURL:filePath toURL:newFilePath error:nil];
    [self.hud dismiss];
    [BHTManager showSaveVC:newFilePath];
}
%new - (void)downloadDidFailureWithError:(NSError *)error {
    if (error) {
        [self.hud dismiss];
    }
}
%end


// MARK: Timeline download
%hook T1SlideshowStatusView
- (void)setViewModel:(id)arg1 media:(id)arg2 animated:(BOOL)arg3 {
    %orig;
    if ([BHTManager DownloadingVideos]) {
        T1StatusInlineActionsView *vis = [self valueForKey:@"_actionsView"];
        [vis appendNewButton:true];
    }
}
%end
%hook T1StandardStatusView
- (void)setViewModel:(id)arg1 options:(unsigned long long)arg2 account:(id)arg3 {
    %orig;
    if ([BHTManager DownloadingVideos]) {
        T1StatusInlineActionsView *vis = self.visibleInlineActionsView;
        [vis appendNewButton:false];
    }
}
%end

%hook T1StatusInlineActionsView
%property (nonatomic, strong) JGProgressHUD *hud;
%new - (void)appendNewButton:(BOOL)isSlideshow {
    if ([BHTManager isVideoCell:self]) {
        UIButton *newButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [newButton setImage:[UIImage systemImageNamed:@"arrow.down"] forState:UIControlStateNormal];
        [newButton addTarget:self action:@selector(DownloadHandler) forControlEvents:UIControlEventTouchUpInside];
        [newButton setTranslatesAutoresizingMaskIntoConstraints:false];
        [newButton setTintColor:isSlideshow ? UIColor.whiteColor : [UIColor colorFromHexString:@"6D6E70"]];
        [self addSubview:newButton];
        
        if ([BHTManager isDeviceLanguageRTL]) {
            [NSLayoutConstraint activateConstraints:@[
                [newButton.heightAnchor constraintEqualToConstant:isSlideshow ? 34 : 24],
                [newButton.widthAnchor constraintEqualToConstant:isSlideshow ? 36 : 30],
                [newButton.topAnchor constraintEqualToAnchor:self.topAnchor constant:-4],
                [newButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor]
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [newButton.heightAnchor constraintEqualToConstant:isSlideshow ? 34 : 24],
                [newButton.widthAnchor constraintEqualToConstant:isSlideshow ? 36 : 30],
                [newButton.topAnchor constraintEqualToAnchor:self.topAnchor constant:-4],
                [newButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
            ]];
        }
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
                        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                        self.hud.textLabel.text = @"Downloading";
                        [self.hud showInView:topMostController().view];
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
    self.hud.detailTextLabel.text = [BHTManager getDownloadingPersent:progress];
}

%new - (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)fileName {
    NSString *DocPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *newFilePath = [[NSURL fileURLWithPath:DocPath] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", NSUUID.UUID.UUIDString]];
    [manager moveItemAtURL:filePath toURL:newFilePath error:nil];
    if (!([BHTManager DirectSave])) {
        [self.hud dismiss];
        [BHTManager showSaveVC:newFilePath];
    } else {
        [BHTManager save:newFilePath];
    }
}
%new - (void)downloadDidFailureWithError:(NSError *)error {
    if (error) {
        [self.hud dismiss];
    }
}
%end

// MARK: Voice feature and Tipjar
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

// MARK: Tweet confirm
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

// MARK: Like confirm
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

// MARK: Undo tweet
%hook TFNTwitterToastNudgeExperimentModel
- (BOOL)shouldShowShowUndoTweetSentToast {
    if ([BHTManager UndoTweet]) {
        return true;
    } else {
        return %orig;
    }
}
%end


// MARK: BHTwitter settings
%hook TFNSettingsNavigationItem
- (id)initWithTitle:(id)arg1 detail:(id)arg2 iconName:(id)arg3 controllerFactory:(id)arg4 {
    if ([arg3 isKindOfClass:NSClassFromString(@"NSString")] && [arg3 isEqual:@"gear"]) {
        TFNSettingsNavigationItem *_orig = %orig;
        [_orig setValue:[UIImage systemImageNamed:@"gear"] forKey:@"_icon"];
        return _orig;
    }
    return %orig(arg1, arg2, arg3, arg4);
}
%end

%hook T1GenericSettingsViewController
- (void)viewWillAppear:(BOOL)arg1 {
    %orig;
    if ([self.sections count] == 1) {
        TFNItemsDataViewControllerBackingStore *DataViewControllerBackingStore = self.backingStore;
        TFNSettingsNavigationItem *bhtwitter = [[%c(TFNSettingsNavigationItem) alloc] initWithTitle:@"Settings" detail:@"BHTwitter preferences" iconName:@"gear" controllerFactory:^UIViewController *{
            return [BHTManager BHTSettings];
        }];
        [DataViewControllerBackingStore insertSection:0 atIndex:0];
        [DataViewControllerBackingStore insertItem:bhtwitter atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
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
//
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
