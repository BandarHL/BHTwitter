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

// MARK: Copy user information
%hook T1ProfileHeaderViewController
- (void)viewDidAppear:(_Bool)arg1 {
    %orig(arg1);
    T1ProfileHeaderView *headerView = [self valueForKey:@"_headerView"];
    UIView *innerContentView = [headerView.actionButtonsView valueForKey:@"_innerContentView"];
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [copyButton setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
    if (@available(iOS 14.0, *)) {
        [copyButton setShowsMenuAsPrimaryAction:true];
        [copyButton setMenu:[UIMenu menuWithTitle:@"" children:@[
            [UIAction actionWithTitle:@"Copy bio" image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = self.viewModel.bio;
            }],
            [UIAction actionWithTitle:@"Copy Username" image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = self.viewModel.username;
            }],
            [UIAction actionWithTitle:@"Copy Full Username" image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = self.viewModel.fullName;
            }],
            [UIAction actionWithTitle:@"Copy URL in the bio" image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = self.viewModel.url;
            }],
        ]]];
    } else {
        [copyButton addTarget:self action:@selector(copyButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
    }
    [copyButton setTintColor:UIColor.labelColor];
    [copyButton.layer setCornerRadius:32/2];
    [copyButton.layer setBorderWidth:1];
    [copyButton.layer setBorderColor:[UIColor colorFromHexString:@"2F3336"].CGColor];
    [copyButton setTranslatesAutoresizingMaskIntoConstraints:false];
    [headerView.actionButtonsView addSubview:copyButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [copyButton.centerYAnchor constraintEqualToAnchor:headerView.actionButtonsView.centerYAnchor],
        [copyButton.widthAnchor constraintEqualToConstant:32],
        [copyButton.heightAnchor constraintEqualToConstant:32],
    ]];
    
    
    if (isDeviceLanguageRTL()) {
        [NSLayoutConstraint activateConstraints:@[
            [copyButton.leadingAnchor constraintEqualToAnchor:innerContentView.trailingAnchor constant:7],
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [copyButton.trailingAnchor constraintEqualToAnchor:innerContentView.leadingAnchor constant:-7],
        ]];
    }
}
%new - (void)copyButtonHandler:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hi" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if (is_iPad()) {
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    UIAlertAction *bio = [UIAlertAction actionWithTitle:@"Copy bio" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = self.viewModel.bio;
    }];
    UIAlertAction *username = [UIAlertAction actionWithTitle:@"Copy Username" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = self.viewModel.username;
    }];
    UIAlertAction *fullusername = [UIAlertAction actionWithTitle:@"Copy Full Username" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = self.viewModel.fullName;
    }];
    UIAlertAction *url = [UIAlertAction actionWithTitle:@"Copy URL in the bio" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = self.viewModel.url;
    }];
    [alert addAction:bio];
    [alert addAction:username];
    [alert addAction:fullusername];
    [alert addAction:url];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:true completion:nil];
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
    if (is_iPad()) {
        alert.popoverPresentationController.sourceRect = CGRectMake(topMostController().view.bounds.size.width / 2.0, topMostController().view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    T1PlayerMediaEntitySessionProducible *session = self.inlineMediaView.viewModel.playerSessionProducer.sessionProducible;
    for (TFSTwitterEntityMediaVideoVariant *i in session.mediaEntity.videoInfo.variants) {
        if ([i.contentType isEqualToString:@"video/mp4"]) {
            UIAlertAction *download = [UIAlertAction actionWithTitle:[BHTManager getVideoQuality:i.url] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                BHDownload *DownloadManager = [[BHDownload alloc] init];
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
        if (vis != nil) {
            [vis appendNewButton:true];
        }
    }
}
%end
%hook T1StandardStatusView
- (void)setViewModel:(id)arg1 options:(unsigned long long)arg2 account:(id)arg3 {
    %orig;
    if ([BHTManager DownloadingVideos]) {
        [((T1StatusInlineActionsView *)self.visibleInlineActionsView) appendNewButton:false];
    }
}
%end

%hook T1StatusInlineActionsView
%property (nonatomic, strong) JGProgressHUD *hud;
%new - (void)appendNewButton:(BOOL)isSlideshow {
    if ([BHTManager isVideoCell:self]) {
        if (isSlideshow && [BHTManager TwitterVersion] > 8.61) {
            NSMutableArray *inlineActionButtons = [self valueForKey:@"_inlineActionButtons"];
            TFNAnimatableButton *emptyButton = [%c(TFNAnimatableButton) buttonWithImage:[UIImage systemImageNamed:@"arrow.down"] style:0 sizeClass:0];
            T1StatusInlineActionButton *emptySpace = [[%c(T1StatusInlineActionButton) alloc] initWithOptions:3 overrideSize:0 account:nil];
            [emptySpace setTranslatesAutoresizingMaskIntoConstraints:false];
            [emptyButton setAnimationCoordinator:emptySpace.animator];
            [emptySpace setTouchInsets:UIEdgeInsetsMake(-5, -14, -5, -14)];
            [emptySpace setValue:emptyButton forKey:@"_modernButton"];
            [emptySpace setValue:emptyButton forKey:@"_button"];
            [emptySpace setValue:nil forKey:@"_legacyButton"];
            [inlineActionButtons addObject:emptySpace];
        }
        
        UIButton *newButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [newButton setImage:[UIImage systemImageNamed:@"arrow.down"] forState:UIControlStateNormal];
        [newButton addTarget:self action:@selector(DownloadHandler) forControlEvents:UIControlEventTouchUpInside];
        [newButton setTranslatesAutoresizingMaskIntoConstraints:false];
        [newButton setTintColor:isSlideshow ? UIColor.whiteColor : [UIColor colorFromHexString:@"6D6E70"]];
        [self addSubview:newButton];
        
        [NSLayoutConstraint activateConstraints:@[
            [newButton.heightAnchor constraintEqualToConstant:isSlideshow ? 34 : 24],
            [newButton.widthAnchor constraintEqualToConstant:isSlideshow ? 36 : 30],
            [newButton.topAnchor constraintEqualToAnchor:self.topAnchor constant:isSlideshow ? 5 : -4]
        ]];
        
        if ([BHTManager DwbLayout]) {
            [NSLayoutConstraint activateConstraints:@[
                [newButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
            ]];
        } else {
            if (isDeviceLanguageRTL()) {
                [NSLayoutConstraint activateConstraints:@[
                    [newButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor]
                ]];
            } else {
                [NSLayoutConstraint activateConstraints:@[
                    [newButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
                ]];
            }
        }
    }
}
%new - (void)DownloadHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hi" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if (is_iPad()) {
        alert.popoverPresentationController.sourceRect = CGRectMake(topMostController().view.bounds.size.width / 2.0, topMostController().view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    for (TFSTwitterEntityMedia *i in self.viewModel.entities.media) {
        for (TFSTwitterEntityMediaVideoVariant *k in i.videoInfo.variants) {
            if ([k.contentType isEqualToString:@"video/mp4"]) {
                UIAlertAction *download = [UIAlertAction actionWithTitle:[BHTManager getVideoQuality:k.url] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    BHDownload *DownloadManager = [[BHDownload alloc] init];
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

// MARK: Bio Translate
%hook TFNTwitterCanonicalUser
- (_Bool)isProfileBioTranslatable {
    if ([BHTManager BioTranslate]) {
        return true;
    } else {
        return %orig;
    }
}
%end

// MARK: No search history
%hook T1SearchTypeaheadViewController
- (NSArray *)recentUsers {
    if ([BHTManager NoHistory]) {
        return @[];
    } else {
        return %orig;
    }
}
- (NSArray *)recentUserIDs {
    if ([BHTManager NoHistory]) {
        return @[];
    } else {
        return %orig;
    }
}
- (NSArray *)recentQueries {
    if ([BHTManager NoHistory]) {
        return @[];
    } else {
        return %orig;
    }
}
%end

%hook TFNTwitterMediaUploadConfiguration
- (_Bool)photoUploadHighQualityImagesSettingIsVisible {
    if ([BHTManager autoHighestLoad]) {
        return true;
    } else {
        return %orig;
    }
}
%end

%hook T1SlideshowViewController
- (_Bool)_t1_shouldDisplayLoadHighQualityImageItemForImageDisplayView:(id)arg1 highestQuality:(_Bool)arg2 {
    if ([BHTManager autoHighestLoad]) {
        return true;
    } else {
        return %orig;
    }
}
- (id)_t1_loadHighQualityActionItemWithTitle:(id)arg1 forImageDisplayView:(id)arg2 highestQuality:(_Bool)arg3 {
    if ([BHTManager autoHighestLoad]) {
        return %orig(arg1, arg2, true);
    } else {
        return %orig(arg1, arg2, arg3);
    }
}
%end

%hook T1ImageDisplayView
- (_Bool)_tfn_shouldUseHighestQualityImage {
    if ([BHTManager autoHighestLoad]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)_tfn_shouldUseHighQualityImage {
    if ([BHTManager autoHighestLoad]) {
        return true;
    } else {
        return %orig;
    }
}
%end

%hook T1HighQualityImagesUploadSettings
- (_Bool)shouldUploadHighQualityImages {
    if ([BHTManager autoHighestLoad]) {
        return true;
    } else {
        return %orig;
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
- (_Bool)photoUploadHighQualityImagesSettingIsVisible {
    if ([BHTManager autoHighestLoad]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)loadingHighestQualityImageVariantPermitted {
    if ([BHTManager autoHighestLoad]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)isDoubleMaxZoomFor4KImagesEnabled {
    if ([BHTManager autoHighestLoad]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)isVideoZoomEnabled {
    if ([BHTManager VideoZoom]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)isReplyLaterEnabled {
    if ([BHTManager ReplyLater]) {
        return true;
    } else {
        return %orig;
    }
}
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

// MARK: Reader mode
%hook T1ReaderModeConfig
- (_Bool)isReaderModeEnabled {
    if ([BHTManager ReaderMode]) {
        return true;
    } else {
        return %orig;
    }
}
%end


// MARK: Old tweet style
%hook TTACoreAnatomyFeatures
- (BOOL)isUnifiedCardEnabled {
    if ([BHTManager OldStyle]) {
        return false;
    } else {
        return %orig;
    }
}
- (BOOL)isModernStatusViewsQuoteTweetEnabled {
    if ([BHTManager OldStyle]) {
        return false;
    } else {
        return %orig;
    }
}
- (BOOL)isEdgeToEdgeContentEnabled {
    if ([BHTManager OldStyle]) {
        return false;
    } else {
        return %orig;
    }
}
%end

// MARK: BHTwitter settings
%hook TFNActionItem
%new + (id)actionItemWithTitle:(NSString *)arg1 systemImageName:(NSString *)arg2 action:(void (^)(void))arg3 {
    TFNActionItem *_self = [%c(TFNActionItem) actionItemWithTitle:arg1 imageName:nil action:arg3];
     [_self setValue:[UIImage systemImageNamed:arg2] forKey:@"_image"];
    return _self;
}
%end

%hook TFNSettingsNavigationItem
%new - (id)initWithTitle:(NSString *)arg1 detail:(NSString *)arg2 systemIconName:(NSString *)arg3 controllerFactory:(UIViewController* (^)(void))arg4 {
    TFNSettingsNavigationItem *_self = [[%c(TFNSettingsNavigationItem) alloc] initWithTitle:arg1 detail:arg2 iconName:arg3 controllerFactory:arg4];
    [_self setValue:[UIImage systemImageNamed:arg3] forKey:@"_icon"];
    return _self;
}
%end

%hook T1GenericSettingsViewController
- (void)viewWillAppear:(BOOL)arg1 {
    %orig;
    if ([self.sections count] == 1) {
        TFNItemsDataViewControllerBackingStore *DataViewControllerBackingStore = self.backingStore;
        TFNSettingsNavigationItem *bhtwitter = [[%c(TFNSettingsNavigationItem) alloc] initWithTitle:@"Settings" detail:@"BHTwitter preferences" systemIconName:@"gear" controllerFactory:^UIViewController *{
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
        [self.navigationController pushViewController:[BHTManager BHTSettings] animated:true];
    } else {
        return %orig;
    }
}
%end

// MARK: Change font
%hook UIFontPickerViewController
- (void)viewWillAppear:(BOOL)arg1 {
    %orig(arg1);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Custom fonts" style:UIBarButtonItemStylePlain target:self action:@selector(customFontsHandler)];
}
%new - (void)customFontsHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Hi" message:@"Choose Font" preferredStyle:UIAlertControllerStyleActionSheet];
    if (is_iPad()) {
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    
    NSPropertyListFormat plistFormat;
    NSMutableDictionary *plistDictionary = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:[NSURL fileURLWithPath:@"/var/mobile/Library/Fonts/AddedFontCache.plist"]] options:NSPropertyListImmutable format:&plistFormat error:nil];
    [plistDictionary enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        @try {
            NSString *fontName = ((NSMutableArray *)[[plistDictionary valueForKey:key] valueForKey:@"psNames"]).firstObject;
            UIAlertAction *font = [UIAlertAction actionWithTitle:fontName style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (self.configuration.includeFaces) {
                    [self setSelectedFontDescriptor:[UIFontDescriptor fontDescriptorWithFontAttributes:@{
                        UIFontDescriptorNameAttribute: fontName
                    }]];
                } else {
                    [self setSelectedFontDescriptor:[UIFontDescriptor fontDescriptorWithFontAttributes:@{
                        UIFontDescriptorFamilyAttribute: fontName
                    }]];
                }
                [self.delegate fontPickerViewControllerDidPickFont:self];
            }];
            [alert addAction:font];
        } @catch (NSException *exception) {
            [alert setMessage:[NSString stringWithFormat:@"Unable to find installed fonts /n reason: %@", exception.reason]];
        }
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:true completion:nil];
}
%end

%hook TAEStandardFontGroup
- (UIFont *)profilesFollowingCountFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)profilesFollowingFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)userCellFollowsYouFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)dashFollowingCountFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)dashFollowingFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)carouselUsernameFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)carouselDisplayNameFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)profilesFullNameFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)profilesUsernameFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)readerModeSmallFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)readerModeSmallBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)readerModeMediumFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)readerModeMediumBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)readerModeLargeFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)readerModeLargeBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)treeTopicsDescriptionFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)treeTopicsCategoryNameFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)treeTopicsNameFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)treeTopicsCategoryNameLargeFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)topicsPillNameFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)topicsDescriptionFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)topicsNameFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)composerTextEditorFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)statusCellEdgeToEdgeBodyBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)statusCellEdgeToEdgeBodyFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)statusCellBodyFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)statusCellBodyBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)cardAttributionFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)cardTitleBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)cardTitleFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)tweetDetailBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)tweetDetailFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)directMessageBubbleBodyFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)directMessageComposePersistentBarFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedJumboBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedXLargeBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedLargeBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedNormalBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedSmallBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedJumboFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedXLargeFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedLargeFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedNormalFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)fixedSmallFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)jumboBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)xLargeBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)largeBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)normalBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)smallBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)xSmallBoldFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)jumboFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)xLargeFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)largeFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)normalFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)smallFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)xSmallFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonXLargeFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonLargeFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonMediumFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonMedium_CondensedFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonMedium_CondensedLighterFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonSmallFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonSmallLighterFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonSmall_CondensedFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonSmall_CondensedLighterFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonNavigationBarFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
    } else {
        return %orig;
    }
}
- (UIFont *)buttonHeavyNavigationBarFont {
    if ([BHTManager changeFont]) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"];
            UIFont *ffont = %orig;
            return [UIFont fontWithName:fontName size:ffont.pointSize];
        } else {
            return %orig;
        }
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
