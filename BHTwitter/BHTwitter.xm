#import <UIKit/UIKit.h>
#import "TWHeaders.h"
#import "BHTdownloadManager.h"
#import "Colours.h"

%config(generator=internal)


%hook T1AppDelegate

- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"FirstRun"]) {
        //sort
        [[NSUserDefaults standardUserDefaults] setValue:@"1strun" forKey:@"FirstRun"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dw_v"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"voice"];
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"like_con"];
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"tweet_con"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return true;
}
%end

%hook T1DirectMessageEntryMediaCell
%new - (void)appendNewButton {
    UIButton *newButton = [UIButton buttonWithType:UIButtonTypeCustom];
    if (@available(iOS 13.0, *)) {
        [newButton setImage:[UIImage systemImageNamed:@"arrow.down"] forState:UIControlStateNormal];
    } else {
        [newButton setImage:[UIImage imageNamed:@"/Library/Application Support/BHT/Ressources.bundle/Regular"] forState:UIControlStateNormal];
    }
    [newButton addTarget:self action:@selector(DownloadHandler) forControlEvents:UIControlEventTouchUpInside];
    [newButton setTranslatesAutoresizingMaskIntoConstraints:false];
    [newButton setTintColor:[UIColor colorFromHexString:@"6D6E70"]];
    
    if ([BHTdownloadManager isDMVideoCell:self.inlineMediaView]) {
        if (self.messageEntryViewModel.isOutgoingMessage) {
            [self addSubview:newButton];
            [NSLayoutConstraint activateConstraints:@[
                [newButton.heightAnchor constraintEqualToConstant:24],
                [newButton.widthAnchor constraintEqualToConstant:30],
                [newButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
                [newButton.leadingAnchor constraintEqualToAnchor:self.inlineMediaView.playerIconView.trailingAnchor]
            ]];
        } else {
            [self addSubview:newButton];
            [NSLayoutConstraint activateConstraints:@[
                [newButton.heightAnchor constraintEqualToConstant:24],
                [newButton.widthAnchor constraintEqualToConstant:30],
                [newButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
                [newButton.leadingAnchor constraintEqualToAnchor:self.inlineMediaView.playerIconView.trailingAnchor]
            ]];
        }
    }
}
%new - (void)DownloadHandler {
    //    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hi" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    //    T1PlayerMediaEntitySessionProducible *session = self.inlineMediaView.viewModel.playerSessionProducer.sessionProducible;
    //    for (TFSTwitterEntityMediaVideoVariant *i in session.mediaEntity.videoInfo.variants) {
    //        if ([i.contentType isEqualToString:@"video/mp4"]) {
    //            UIAlertAction *download = [UIAlertAction actionWithTitle:[self getVideoQ:i.url] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    //                JGProgressHUD *hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
    //                [hud showInView:topMostController().view];
    //                [BHTdownloadManager DownloadVideoWithURL:i.url completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
    //                    if (error) {
    //
    //                        [hud dismiss];
    //                        [FLEXAlert showAlert:@"error :(" message:error.localizedFailureReason from:topMostController()];
    //                    } else {
    //                        [hud dismiss];
    //
    //                        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
    //                            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:filePath];
    //                        } completionHandler:^(BOOL success, NSError *error2) {
    //                            if (error2) {
    //                                [FLEXAlert showAlert:@"error :(" message:error2.localizedFailureReason from:topMostController()];
    //                                [[NSFileManager defaultManager] removeItemAtURL:filePath error:nil];
    //                            } else {
    //                                [FLEXAlert showAlert:@"hi" message:@"Video successfully saved" from:topMostController()];
    //                                [[NSFileManager defaultManager] removeItemAtURL:filePath error:nil];
    //                            }
    //                        }];
    //                    }
    //                }];
    //            }];
    //            [alert addAction:download];
    //        }
    //    }
    //    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    //    [topMostController() presentViewController:alert animated:true completion:nil];
}
%new - (NSString *)getVideoQ:(NSString *)url {
    NSMutableArray *q = [NSMutableArray new];
    NSArray *splits = [url componentsSeparatedByString:@"/"];
    for (int i = 0; i < [splits count]; i++) {
        NSString *item = [splits objectAtIndex:i];
        NSArray *dir = [item componentsSeparatedByString:@"x"];
        for (int k = 0; k < [dir count]; k++) {
            NSString *item2 = [dir objectAtIndex:k];
            if (!(item2.length == 0)) {
                if ([BHTdownloadManager doesContainDigitsOnly:item2]) {
                    if (!(item2.integerValue > 10000)) {
                        if (!(q.count == 2)) {
                            [q addObject:item2];
                        }
                    }
                }
            }
        }
    }
    return [NSString stringWithFormat:@"%@x%@", q.firstObject, q.lastObject];
}
%end


%hook T1StandardStatusView
- (void)setViewModel:(id)arg1 options:(unsigned long long)arg2 account:(id)arg3 {
    %orig;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"dw_v"]) {
        T1StatusInlineActionsView *vis = self.visibleInlineActionsView;
        [vis appendNewButton];
    }
}
%end

%hook T1StatusInlineActionsView
%new - (void)appendNewButton {
    if ([BHTdownloadManager isVideoCell:self]) {
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
        if ([BHTdownloadManager isLTR]) {
            [NSLayoutConstraint activateConstraints:@[
                [newButton.heightAnchor constraintEqualToConstant:24],
                [newButton.widthAnchor constraintEqualToConstant:30],
                [newButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
                [newButton.leadingAnchor constraintEqualToAnchor:lastButton.trailingAnchor constant:10]
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [newButton.heightAnchor constraintEqualToConstant:24],
                [newButton.widthAnchor constraintEqualToConstant:30],
                [newButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
                [newButton.leadingAnchor constraintEqualToAnchor:lastButton.trailingAnchor constant:-70]
            ]];
        }

    }
}
%new - (void)DownloadHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hi" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (TFSTwitterEntityMedia *i in self.viewModel.entities.media) {
        for (TFSTwitterEntityMediaVideoVariant *k in i.videoInfo.variants) {
            if ([k.contentType isEqualToString:@"video/mp4"]) {
                UIAlertAction *download = [UIAlertAction actionWithTitle:[self getVideoQ:k.url] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    JGProgressHUD *hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                    [hud showInView:topMostController().view];
                    [NSThread detachNewThreadWithBlock:^{
                        [BHTdownloadManager DownloadVideoWithURL:k.url completionHandler:^(NSURL *filePath, NSError *error) {
                            if (error) {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [hud dismiss];
                                        [FLEXAlert showAlert:@"error :(" message:error.localizedFailureReason from:topMostController()];
                                    });
                                });
                            } else {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [BHTdownloadManager showSaveingViewController:filePath];
                                        [hud dismiss];
                                    });
                                });
                            }
                        }];
                    }];
                }];
                [alert addAction:download];
            }
        }
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [topMostController() presentViewController:alert animated:true completion:nil];
}
%new - (NSString *)getVideoQ:(NSString *)url {
    NSMutableArray *q = [NSMutableArray new];
    NSArray *splits = [url componentsSeparatedByString:@"/"];
    for (int i = 0; i < [splits count]; i++) {
        NSString *item = [splits objectAtIndex:i];
        NSArray *dir = [item componentsSeparatedByString:@"x"];
        for (int k = 0; k < [dir count]; k++) {
            NSString *item2 = [dir objectAtIndex:k];
            if (!(item2.length == 0)) {
                if ([BHTdownloadManager doesContainDigitsOnly:item2]) {
                    if (!(item2.integerValue > 10000)) {
                        if (!(q.count == 2)) {
                            [q addObject:item2];
                        }
                    }
                }
            }
        }
    }
    return [NSString stringWithFormat:@"%@x%@", q.firstObject, q.lastObject];
}
%end

%hook TFNTwitterAccount
- (_Bool)isConversationThreadingVoiceOverSupportEnabled {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"voice"]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)isDMVoiceRenderingEnabled {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"voice"]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)isDMVoiceCreationEnabled {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"voice"]) {
        return true;
    } else {
        return %orig;
    }
}
%end
%hook TFNTwitterComposition
- (BOOL)hasVoiceRecordingAttachment {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"voice"]) {
        return true;
    } else {
        return %orig;
    }
}
%end

%hook T1MediaAutoplaySettings
- (_Bool)voiceOverEnabled {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"voice"]) {
        return true;
    } else {
        return %orig;
    }
}
- (void)setVoiceOverEnabled:(_Bool)arg1 {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"voice"]) {
        arg1 = true;
    }
    return %orig(arg1);
}
%end

%hook T1TweetComposeViewController
- (void)_t1_handleTweet {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"tweet_con"]) {
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
- (void)viewWillAppear:(_Bool)arg1 {
    %orig;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"voice"]) {
        [self _t1_insertVoiceButtonIfNeeded];
    }
}
- (void)_t1_insertVoiceButtonIfNeeded {
    [self.voiceButton setImage:[UIImage imageNamed:@"voice"] forState:UIControlStateNormal];
    [self.voiceButton setHidden:false];
    [self.voiceButton setEnabled:true];
    [self.voiceButton setTranslatesAutoresizingMaskIntoConstraints:false];
    [self.buttonBarView addSubview:self.voiceButton];
    
    TFNButton *lastButton = self.buttonBarView.leadingViews.lastObject;
    if ([BHTdownloadManager isLTR]) {
        [NSLayoutConstraint activateConstraints:@[
            [self.voiceButton.centerYAnchor constraintEqualToAnchor:self.buttonBarView.centerYAnchor],
            [self.voiceButton.leadingAnchor constraintEqualToAnchor:lastButton.trailingAnchor constant:self.buttonBarView.leadingViewsSpacing],
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [self.voiceButton.centerYAnchor constraintEqualToAnchor:self.buttonBarView.centerYAnchor],
            [self.voiceButton.trailingAnchor constraintEqualToAnchor:lastButton.leadingAnchor constant:self.buttonBarView.leadingViewsSpacing-40],
        ]];
    }
}
%end

%hook T1StatusInlineFavoriteButton
- (void)didTap {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"like_con"]) {
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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"like_con"]) {
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
        //Insert section at Top "TFNItemsDataViewSectionController"
        [DataViewControllerBackingStore insertSection:0 atIndex:0];
        //insert Row 0 in section 0 "TFNDataViewItem"
        [DataViewControllerBackingStore insertItem:@"Row 0 " atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        //Insert Row1 in section 0 "TFNDataViewItem"
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
        [BHTdownloadManager showSettings:self];
    } else {
        return %orig;
    }
}
%end




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

