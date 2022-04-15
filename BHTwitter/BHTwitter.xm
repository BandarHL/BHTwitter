#import "BHDownloadInlineButton.h"
#import "SAMKeychain/AuthViewController.h"
#import "Colours.h"
#import "BHTManager.h"

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

// MARK: Custom Tab bar
%hook T1TabBarViewController
- (void)loadView {
    %orig;
    NSArray <NSString *> *hiddenBars = [CustomTabBarUtility getHiddenTabBars];
    for (T1TabView *tabView in self.tabViews) {
        if ([hiddenBars containsObject:tabView.scribePage]) {
            [tabView setHidden:true];
        }
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
    
    if ([BHTManager DwbLayout]) {
        [NSLayoutConstraint activateConstraints:@[
            [copyButton.trailingAnchor constraintEqualToAnchor:innerContentView.leadingAnchor constant:-7],
        ]];
    } else {
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
    id tweet = [self itemAtIndexPath:arg2];
    
    if ([tweet isKindOfClass:%c(TFNTwitterStatus)]) {
        TFNTwitterStatus *fullTweet = tweet;
        if ([BHTManager HidePromoted]) {
            if (fullTweet.isPromoted) {
                [_orig setHidden:true];
            }
        }
    }
    
    if ([tweet isKindOfClass:%c(T1URTTimelineStatusItemViewModel)]) {
        T1URTTimelineStatusItemViewModel *fullTweet = tweet;
        if ([BHTManager HidePromoted]) {
            if (fullTweet.isPromoted) {
                [_orig setHidden:true];
            }
        }
        
        if ([BHTManager HideTopics]) {
            if ((fullTweet.banner != nil) && [fullTweet.banner isKindOfClass:%c(TFNTwitterURTTimelineStatusTopicBanner)]) {
                [_orig setHidden:true];
            }
        }
    }
    
    if ([BHTManager HideTopics]) {
        if ([tweet isKindOfClass:%c(_TtC10TwitterURT26URTTimelinePromptViewModel)]) {
            [_orig setHidden:true];
        }
    }
    
    return _orig;
}
- (double)tableView:(id)arg1 heightForRowAtIndexPath:(id)arg2 {
    id tweet = [self itemAtIndexPath:arg2];
    
    if ([tweet isKindOfClass:%c(TFNTwitterStatus)]) {
        TFNTwitterStatus *fullTweet = tweet;
        if ([BHTManager HidePromoted]) {
            if (fullTweet.isPromoted) {
                return 0;
            }
        }
    }
    
    if ([tweet isKindOfClass:%c(T1URTTimelineStatusItemViewModel)]) {
        T1URTTimelineStatusItemViewModel *fullTweet = tweet;
        if ([BHTManager HidePromoted]) {
            if (fullTweet.isPromoted) {
                return 0;
            }
        }
        
        if ([BHTManager HideTopics]) {
            if ((fullTweet.banner != nil) && [fullTweet.banner isKindOfClass:%c(TFNTwitterURTTimelineStatusTopicBanner)]) {
                return 0;
            }
        }
    }
    
    if ([BHTManager HideTopics]) {
        if ([tweet isKindOfClass:%c(_TtC10TwitterURT26URTTimelinePromptViewModel)]) {
            return 0;
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
    NSAttributedString *AttString = [[NSAttributedString alloc] initWithString:@"\nSelect video quality you want to download" attributes:@{
        NSFontAttributeName: [[%c(TAEStandardFontGroup) sharedFontGroup] fixedLargeBoldFont],
        NSForegroundColorAttributeName: UIColor.labelColor
    }];
    TFNActiveTextItem *title = [[%c(TFNActiveTextItem) alloc] initWithTextModel:[[%c(TFNAttributedTextModel) alloc] initWithAttributedString:AttString] activeRanges:nil];
    TFNMenuSheetCenteredIconItem *icon = [[%c(TFNMenuSheetCenteredIconItem) alloc] initWithIconImageName:@"2728" height:55 fillColor:UIColor.clearColor];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:icon];
    [actions addObject:title];
    
    T1PlayerMediaEntitySessionProducible *session = self.inlineMediaView.viewModel.playerSessionProducer.sessionProducible;
    for (TFSTwitterEntityMediaVideoVariant *i in session.mediaEntity.videoInfo.variants) {
        if ([i.contentType isEqualToString:@"video/mp4"]) {
            TFNActionItem *download = [%c(TFNActionItem) actionItemWithTitle:[BHTManager getVideoQuality:i.url] imageName:@"arrow_down_circle_stroke" action:^{
                BHDownload *DownloadManager = [[BHDownload alloc] init];
                self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                self.hud.textLabel.text = @"Downloading";
                [DownloadManager downloadFileWithURL:[NSURL URLWithString:i.url]];
                [DownloadManager setDelegate:self];
                [self.hud showInView:topMostController().view];
            }];
            [actions addObject:download];
        }
    }
    
    TFNMenuSheetViewController *alert = [[%c(TFNMenuSheetViewController) alloc] initWithActionItems:[NSArray arrayWithArray:actions]];
    [alert tfnPresentedCustomPresentFromViewController:topMostController() animated:YES completion:nil];
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
// THIS SOLUTION WAS TAKEN FROM Translomatic AFTER DISASSEMBLING THE DYLIB
// SO THANKS: @foxfortmobile
%hook T1StatusInlineActionsView
+ (NSArray *)_t1_inlineActionViewClassesForViewModel:(id)arg1 options:(unsigned long long)arg2 displayType:(unsigned long long)arg3 account:(id)arg4 {
    NSArray *_orig = %orig;
    NSMutableArray *newOrig = [_orig mutableCopy];
    
    if ([BHTManager isVideoCell:arg1]) {
        [newOrig addObject:%c(BHDownloadInlineButton)];
    }
    
    return [newOrig copy];
}
%end

// MARK: always Open Safari
// thanks: @CrazyMind90
%hook TFSTwitterEntityURL
- (NSString *)url {
    // https://github.com/haoict/twitter-no-ads/blob/master/Tweak.xm#L195
    return self.expandedURL;
}
%end

%hook UIViewController
- (id)t1_openURLParserResult:(NSURL *)arg1 account:(id)arg2 scribeContext:(id)arg3 {
    if (BH_canOpenURL(arg1)) { return nil;}
    return %orig(arg1, arg2, arg3);
}
- (id)t1_openURL:(NSURL *)arg1 account:(id)arg2 scribeContext:(id)arg3 fromCardDataSource:(id)arg4 {
    if (BH_canOpenURL(arg1)) { return nil;}
    return %orig(arg1, arg2, arg3, arg4);
}
- (id)t1_openURL:(NSURL *)arg1 account:(id)arg2 scribeContext:(id)arg3 fromSourceDirectMessageEntry:(id)arg4 {
    if (BH_canOpenURL(arg1)) { return nil;}
    return %orig(arg1, arg2, arg3, arg4);
}
- (id)t1_openURL:(NSURL *)arg1 account:(id)arg2 scribeContext:(id)arg3 fromSourceUser:(id)arg4 {
    if (BH_canOpenURL(arg1)) { return nil;}
    return %orig(arg1, arg2, arg3, arg4);
}
- (id)t1_openURL:(NSURL *)arg1 account:(id)arg2 scribeContext:(id)arg3 fromSourceStatus:(id)arg4 applyAdURLTransforms:(_Bool)arg5 forceAuthenticateWebViewController:(_Bool)arg6 {
    if (BH_canOpenURL(arg1)) { return nil;}
    return %orig(arg1, arg2, arg3, arg4, arg5, arg6);
}
- (id)t1_openURL:(NSURL *)arg1 account:(id)arg2 scribeContext:(id)arg3 forceAuthenticateWebViewController:(_Bool)arg4 {
    if (BH_canOpenURL(arg1)) { return nil;}
    return %orig(arg1, arg2, arg3, arg4);
}
- (id)t1_openURL:(NSURL *)arg1 account:(id)arg2 scribeContext:(id)arg3 expandedURL:(id)arg4 {
    if (BH_canOpenURL(arg1)) { return nil;}
    return %orig(arg1, arg2, arg3, arg4);
}
- (id)t1_openURL:(NSURL *)arg1 account:(id)arg2 scribeContext:(id)arg3 {
    if (BH_canOpenURL(arg1)) { return nil;}
    return %orig(arg1, arg2, arg3);
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
%hook T1SearchTypeaheadViewController // for old Twitter versions
- (void)viewDidLoad {
    if ([BHTManager NoHistory]) { // thanks @CrazyMind90
        if ([self respondsToSelector:@selector(clearActionControlWantsClear:)]) {
            [self performSelector:@selector(clearActionControlWantsClear:)];
        }
    }
    %orig;
}
%end

%hook TTSSearchTypeaheadViewController
- (void)viewDidLoad {
    if ([BHTManager NoHistory]) { // thanks @CrazyMind90
        if ([self respondsToSelector:@selector(clearActionControlWantsClear:)]) {
            [self performSelector:@selector(clearActionControlWantsClear:)];
        }
    }
    %orig;
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

// MARK: Voice feature
%hook TFNTwitterComposition
- (BOOL)isReply {
    if ([BHTManager voice_in_replay]) {
        return false;
    } else {
        return %orig;
    }
}
%end

%hook TFSTwitterAPICommandAccountStateProvider
- (_Bool)allowPromotedContent {
    if ([BHTManager HidePromoted]) {
        return false;
    } else {
        return %orig;
    }
}
%end

%hook TFNTwitterAccount
- (_Bool)isSensitiveTweetWarningsComposeEnabled {
    if ([BHTManager disableSensitiveTweetWarnings]) {
        return false;
    } else {
        return %orig;
    }
}
- (_Bool)isSensitiveTweetWarningsConsumeEnabled {
    if ([BHTManager disableSensitiveTweetWarnings]) {
        return false;
    } else {
        return %orig;
    }
}
- (_Bool)isDmModularSearchEnabled {
    if ([BHTManager DmModularSearch]) {
        return true;
    } else {
        return %orig;
    }
}
- (_Bool)isVideoDynamicAdEnabled {
    if ([BHTManager HidePromoted]) {
        return false;
    }
}

- (_Bool)isVODCaptionsEnabled {
    if ([BHTManager DisableVODCaptions]) {
        return false;
    } else {
        return %orig;
    }
}
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

// MARK: Follow confirm
%hook TUIFollowControl
- (void)_followUser:(id)arg1 event:(id)arg2 {
    if ([BHTManager FollowConfirm]) {
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
    NSAttributedString *AttString = [[NSAttributedString alloc] initWithString:@"\nSelect your custom font" attributes:@{
        NSFontAttributeName: [[%c(TAEStandardFontGroup) sharedFontGroup] fixedLargeBoldFont],
        NSForegroundColorAttributeName: UIColor.labelColor
    }];
    TFNActiveTextItem *title = [[%c(TFNActiveTextItem) alloc] initWithTextModel:[[%c(TFNAttributedTextModel) alloc] initWithAttributedString:AttString] activeRanges:nil];
    TFNMenuSheetCenteredIconItem *icon = [[%c(TFNMenuSheetCenteredIconItem) alloc] initWithIconImageName:@"2728" height:55 fillColor:UIColor.clearColor];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:icon];
    [actions addObject:title];
    
    NSPropertyListFormat plistFormat;
    NSMutableDictionary *plistDictionary = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:[NSURL fileURLWithPath:@"/var/mobile/Library/Fonts/AddedFontCache.plist"]] options:NSPropertyListImmutable format:&plistFormat error:nil];
    [plistDictionary enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        @try {
            NSString *fontName = ((NSMutableArray *)[[plistDictionary valueForKey:key] valueForKey:@"psNames"]).firstObject;
            TFNActionItem *fontAction = [%c(TFNActionItem) actionItemWithTitle:fontName action:^{
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
            [actions addObject:fontAction];
        } @catch (NSException *exception) {
            NSLog(@"Unable to find installed fonts /n reason: %@", exception.reason);
        }
    }];
    
    TFNMenuSheetViewController *alert = [[%c(TFNMenuSheetViewController) alloc] initWithActionItems:[NSArray arrayWithArray:actions]];
    [alert tfnPresentedCustomPresentFromViewController:self animated:YES completion:nil];
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
//    return accessGroupID();
//}
//- (NSString *)providerSharedAccessGroup {
//    return accessGroupID();
//}
//%end
//
//%hook TFSKeychainDefaultTwitterConfiguration
//- (NSString *)defaultAccessGroup {
//    return accessGroupID();
//}
//- (NSString *)sharedAccessGroup {
//    return accessGroupID();
//}
//%end
