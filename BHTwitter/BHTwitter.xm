#import "SAMKeychain/AuthViewController.h"
#import "Colours.h"
#import "BHTManager.h"
#import "BHTwitter-Swift.h"
#import "BHTBundle.h"

%config(generator=internal)

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
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"TrustedFriends"];
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
    if ([BHTManager FLEX]) {
        [[FLEXManager sharedManager] showExplorer];
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
    if ([BHTManager CopyProfileInfo]) {
        T1ProfileHeaderView *headerView = [self valueForKey:@"_headerView"];
        UIView *innerContentView = [headerView.actionButtonsView valueForKey:@"_innerContentView"];
        UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [copyButton setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
        if (@available(iOS 14.0, *)) {
            [copyButton setShowsMenuAsPrimaryAction:true];
            [copyButton setMenu:[UIMenu menuWithTitle:@"" children:@[
                [UIAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_1"] image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    UIPasteboard.generalPasteboard.string = self.viewModel.bio;
                }],
                [UIAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_2"] image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    UIPasteboard.generalPasteboard.string = self.viewModel.username;
                }],
                [UIAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_3"] image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    UIPasteboard.generalPasteboard.string = self.viewModel.fullName;
                }],
                [UIAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_4"] image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    UIPasteboard.generalPasteboard.string = self.viewModel.url;
                }],
                [UIAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_5"] image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    UIPasteboard.generalPasteboard.string = self.viewModel.location;
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
}
%new - (void)copyButtonHandler:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"hi" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if (is_iPad()) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = sender.frame;
    }
    UIAlertAction *bio = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_1"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = self.viewModel.bio;
    }];
    UIAlertAction *username = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_2"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = self.viewModel.username;
    }];
    UIAlertAction *fullusername = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_3"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = self.viewModel.fullName;
    }];
    UIAlertAction *url = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_4"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = self.viewModel.url;
    }];
    UIAlertAction *location = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_5"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = self.viewModel.location;
    }];
    [alert addAction:bio];
    [alert addAction:username];
    [alert addAction:fullusername];
    [alert addAction:url];
    [alert addAction:location];
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:true completion:nil];
}
%end


// MARK: hide ADs
// credit goes to haoict https://github.com/haoict/twitter-no-ads
%hook TFNItemsDataViewController
- (id)tableViewCellForItem:(id)arg1 atIndexPath:(id)arg2 {
    UITableViewCell *_orig = %orig;
    id tweet = [self itemAtIndexPath:arg2];
    NSString *class_name = NSStringFromClass([tweet classForCoder]);
    
    if ([BHTManager HidePromoted] && [tweet respondsToSelector:@selector(isPromoted)] && [tweet performSelector:@selector(isPromoted)]) {
        [_orig setHidden:YES];
    }
    
    
    if ([self.adDisplayLocation isEqualToString:@"PROFILE_TWEETS"]) {
        if ([BHTManager hideWhoToFollow]) {
            if ([class_name isEqualToString:@"T1URTTimelineUserItemViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"]) {
                [_orig setHidden:true];
            }
        }
        
        if ([BHTManager hideTopicsToFollow]) {
            if ([class_name isEqualToString:@"T1TwitterSwift.URTTimelineTopicCollectionViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"] || [class_name isEqualToString:@"TwitterURT.URTTimelineCarouselViewModel"]) {
                [_orig setHidden:true];
            }
        }
    }
    
    if ([self.adDisplayLocation isEqualToString:@"OTHER"]) {
        if ([BHTManager HidePromoted] && ([class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"] || [class_name isEqualToString:@"T1URTTimelineMessageItemViewModel"])) {
            [_orig setHidden:true];
        }
        
        if ([BHTManager HidePromoted] && [class_name isEqualToString:@"TwitterURT.URTTimelineEventSummaryViewModel"]) {
            _TtC10TwitterURT32URTTimelineEventSummaryViewModel *trendModel = tweet;
            if ([[trendModel.scribeItem allKeys] containsObject:@"promoted_id"]) {
                [_orig setHidden:true];
            }
        }
        if ([BHTManager HidePromoted] && [class_name isEqualToString:@"TwitterURT.URTTimelineTrendViewModel"]) {
            _TtC10TwitterURT25URTTimelineTrendViewModel *trendModel = tweet;
            if ([[trendModel.scribeItem allKeys] containsObject:@"promoted_id"]) {
                [_orig setHidden:true];
            }
        }
    }
    
    if ([self.adDisplayLocation isEqualToString:@"TIMELINE_HOME"]) {
        if ([tweet isKindOfClass:%c(T1URTTimelineStatusItemViewModel)]) {
            T1URTTimelineStatusItemViewModel *fullTweet = tweet;
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
    }
    
    return _orig;
}
- (double)tableView:(id)arg1 heightForRowAtIndexPath:(id)arg2 {
    id tweet = [self itemAtIndexPath:arg2];
    NSString *class_name = NSStringFromClass([tweet classForCoder]);
    
    if ([BHTManager HidePromoted] && [tweet respondsToSelector:@selector(isPromoted)] && [tweet performSelector:@selector(isPromoted)]) {
        return 0;
    }
    
    if ([self.adDisplayLocation isEqualToString:@"PROFILE_TWEETS"]) {
        if ([BHTManager hideWhoToFollow]) {
            if ([class_name isEqualToString:@"T1URTTimelineUserItemViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"]) {
                return 0;
            }
        }
        if ([BHTManager hideTopicsToFollow]) {
            if ([class_name isEqualToString:@"T1TwitterSwift.URTTimelineTopicCollectionViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"] || [class_name isEqualToString:@"TwitterURT.URTTimelineCarouselViewModel"]) {
                return 0;
            }
        }
    }
    
    if ([self.adDisplayLocation isEqualToString:@"OTHER"]) {
        if ([BHTManager HidePromoted] && ([class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"] || [class_name isEqualToString:@"T1URTTimelineMessageItemViewModel"])) {
            return 0;
        }
        
        if ([BHTManager HidePromoted] && [class_name isEqualToString:@"TwitterURT.URTTimelineEventSummaryViewModel"]) {
            _TtC10TwitterURT32URTTimelineEventSummaryViewModel *trendModel = tweet;
            if ([[trendModel.scribeItem allKeys] containsObject:@"promoted_id"]) {
                return 0;
            }
        }
        if ([BHTManager HidePromoted] && [class_name isEqualToString:@"TwitterURT.URTTimelineTrendViewModel"]) {
            _TtC10TwitterURT25URTTimelineTrendViewModel *trendModel = tweet;
            if ([[trendModel.scribeItem allKeys] containsObject:@"promoted_id"]) {
                return 0;
            }
        }
    }
    
    if ([self.adDisplayLocation isEqualToString:@"TIMELINE_HOME"]) {
        if ([tweet isKindOfClass:%c(T1URTTimelineStatusItemViewModel)]) {
            T1URTTimelineStatusItemViewModel *fullTweet = tweet;
            
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
    }
    
    return %orig;
}
- (double)tableView:(id)arg1 heightForHeaderInSection:(long long)arg2 {
    if (self.sections && self.sections[arg2] && ((NSArray* )self.sections[arg2]).count && self.sections[arg2][0]) {
        NSString *sectionClassName = NSStringFromClass([self.sections[arg2][0] classForCoder]);
        if ([sectionClassName isEqualToString:@"TFNTwitterUser"]) {
            return 0;
        }
    }
    return %orig;
}
%end

%hook TFNTwitterStatus
- (_Bool)isCardHidden {
    return ([BHTManager HidePromoted] && [self isPromoted]) ? true : %orig;
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
    NSAttributedString *AttString = [[NSAttributedString alloc] initWithString:[[BHTBundle sharedBundle] localizedStringForKey:@"DOWNLOAD_MENU_TITLE"] attributes:@{
        NSFontAttributeName: [[%c(TAEStandardFontGroup) sharedFontGroup] headline2BoldFont],
        NSForegroundColorAttributeName: UIColor.labelColor
    }];
    TFNActiveTextItem *title = [[%c(TFNActiveTextItem) alloc] initWithTextModel:[[%c(TFNAttributedTextModel) alloc] initWithAttributedString:AttString] activeRanges:nil];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:title];
    
    T1PlayerMediaEntitySessionProducible *session = self.inlineMediaView.viewModel.playerSessionProducer.sessionProducible;
    for (TFSTwitterEntityMediaVideoVariant *i in session.mediaEntity.videoInfo.variants) {
        if ([i.contentType isEqualToString:@"video/mp4"]) {
            TFNActionItem *download = [%c(TFNActionItem) actionItemWithTitle:[BHTManager getVideoQuality:i.url] imageName:@"arrow_down_circle_stroke" action:^{
                BHDownload *DownloadManager = [[BHDownload alloc] init];
                self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                self.hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"PROGRESS_DOWNLOADING_STATUS_TITLE"];
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

// MARK: Color theme
%hook TFNPagingViewController
- (void)viewDidAppear:(_Bool)animated {
    %orig(animated);
    
    static dispatch_once_t once;
    dispatch_once(&once, ^ {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
            BH_changeTwitterColor([[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"]);
        }
    });
}
%end

%hook TFNNavigationController
- (void)viewDidAppear:(_Bool)animated {
    %orig(animated);
    
    static dispatch_once_t once;
    dispatch_once(&once, ^ {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
            BH_changeTwitterColor([[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"]);
        }
    });
}
%end

%hook T1AppSplitViewController
- (void)viewDidAppear:(_Bool)animated {
    %orig(animated);
    
    static dispatch_once_t once;
    dispatch_once(&once, ^ {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
            BH_changeTwitterColor([[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"]);
        }
    });
}
%end

%hook NSUserDefaults
- (void)setObject:(id)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"T1ColorSettingsPrimaryColorOptionKey"]) {
        id selectedColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"];
        if (selectedColor != nil) {
            if ([value isEqual:selectedColor]) {
                return %orig;
            } else {
                return;
            }
        }
        return %orig;
    }
    return %orig;
}
%end

%hook TFNNavigationBar
- (void)setPrefersLargeTitles:(BOOL)largeTitles {
    largeTitles = false;
    return %orig(largeTitles);
}
%end

// MARK: Save tweet as an image
// Twitter 9.31 and higher
%hook TTAStatusInlineShareButton
- (void)didLongPressActionButton:(UILongPressGestureRecognizer *)gestureRecognizer {
    if ([BHTManager tweetToImage]) {
        if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
            T1StatusInlineActionsView *actionsView = self.delegate;
            T1StatusCell *tweetView;
            
            if ([actionsView.superview isKindOfClass:%c(T1StandardStatusView)]) { // normal tweet in the time line
                tweetView = [(T1StandardStatusView *)actionsView.superview eventHandler];
            } else if ([actionsView.superview isKindOfClass:%c(T1TweetDetailsFocalStatusView)]) { // Focus tweet
                tweetView = [(T1TweetDetailsFocalStatusView *)actionsView.superview eventHandler];
            } else {
                return %orig;
            }
            
            UIImage *tweetImage = BH_imageFromView(tweetView);
            UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[tweetImage] applicationActivities:nil];
            if (is_iPad()) {
                acVC.popoverPresentationController.sourceView = self;
                acVC.popoverPresentationController.sourceRect = self.frame;
            }
            [topMostController() presentViewController:acVC animated:true completion:nil];
            return;
        }
    }
    return %orig;
}
%end

// Twitter 9.30 and lower
%hook T1StatusInlineShareButton
- (void)didLongPressActionButton:(UILongPressGestureRecognizer *)gestureRecognizer {
    if ([BHTManager tweetToImage]) {
        if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
            T1StatusInlineActionsView *actionsView = self.delegate;
            T1StatusCell *tweetView;
            
            if ([actionsView.superview isKindOfClass:%c(T1StandardStatusView)]) { // normal tweet in the time line
                tweetView = [(T1StandardStatusView *)actionsView.superview eventHandler];
            } else if ([actionsView.superview isKindOfClass:%c(T1TweetDetailsFocalStatusView)]) { // Focus tweet
                tweetView = [(T1TweetDetailsFocalStatusView *)actionsView.superview eventHandler];
            } else {
                return %orig;
            }
            
            UIImage *tweetImage = BH_imageFromView(tweetView);
            UIActivityViewController *acVC = [[UIActivityViewController alloc] initWithActivityItems:@[tweetImage] applicationActivities:nil];
            if (is_iPad()) {
                acVC.popoverPresentationController.sourceView = self;
                acVC.popoverPresentationController.sourceRect = self.frame;
            }
            [topMostController() presentViewController:acVC animated:true completion:nil];
            return;
        }
    }
    return %orig;
}
%end

// MARK: Timeline download
// THIS SOLUTION WAS TAKEN FROM Translomatic AFTER DISASSEMBLING THE DYLIB
// SO THANKS: @foxfortmobile
// Twitter 9.31 and higher
%hook TTAStatusInlineActionsView
+ (NSArray *)_t1_inlineActionViewClassesForViewModel:(id)arg1 options:(NSUInteger)arg2 displayType:(NSUInteger)arg3 account:(id)arg4 {
    NSArray *_orig = %orig;
    NSMutableArray *newOrig = [_orig mutableCopy];
    
    if ([BHTManager isVideoCell:arg1] && [BHTManager DownloadingVideos]) {
        [newOrig addObject:%c(BHDownloadInlineButton)];
    }
    
    return [newOrig copy];
}
%end

// Twitter 9.30 and lower
%hook T1StatusInlineActionsView
+ (NSArray *)_t1_inlineActionViewClassesForViewModel:(id)arg1 options:(NSUInteger)arg2 displayType:(NSUInteger)arg3 account:(id)arg4 {
    NSArray *_orig = %orig;
    NSMutableArray *newOrig = [_orig mutableCopy];
    
    if ([BHTManager isVideoCell:arg1] && [BHTManager DownloadingVideos]) {
        [newOrig addObject:%c(BHDownloadInlineButton)];
    }
    
    return [newOrig copy];
}
%end

// MARK: Always open in Safrai
// Thanks nyuszika7h https://github.com/nyuszika7h/noinappsafari/
%hook SFSafariViewController
- (void)viewWillAppear:(BOOL)animated {
    if (![BHTManager alwaysOpenSafari]) {
        return %orig;
    }

    NSURL *url = [self initialURL];
    NSString *urlStr = [url absoluteString];

    // In-app browser is used for two-factor authentication with security key,
    // login will not complete successfully if it's redirected to Safari
    if ([urlStr containsString:@"twitter.com/account/"] || [urlStr containsString:@"twitter.com/i/flow/"]) {
        return %orig;
    }

    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

%hook SFInteractiveDismissController
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    if (![BHTManager alwaysOpenSafari]) {
        return %orig;
    }
    [transitionContext completeTransition:NO];
}
%end

%hook TFSTwitterEntityURL
- (NSString *)url {
    // https://github.com/haoict/twitter-no-ads/blob/master/Tweak.xm#L195
    return self.expandedURL;
}
%end

// MARK: Disable RTL
%hook NSParagraphStyle
+ (NSWritingDirection)defaultWritingDirectionForLanguage:(id)lang {
    return [BHTManager disableRTL] ? NSWritingDirectionLeftToRight : %orig;
}
+ (NSWritingDirection)_defaultWritingDirection {
    return [BHTManager disableRTL] ? NSWritingDirectionLeftToRight : %orig;
}
%end

// MARK: Bio Translate
%hook TFNTwitterCanonicalUser
- (_Bool)isProfileBioTranslatable {
    return [BHTManager BioTranslate] ? true : %orig;
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

// MARK: Voice, TwitterCircle, SensitiveTweetWarnings, autoHighestLoad, VideoZoom, VODCaptions, disableSpacesBar feature
%hook TPSTwitterFeatureSwitches
// Twitter save all the features and keys in side JSON file in bundle of application fs_embedded_defaults_production.json, and use it in TFNTwitterAccount class but with DM voice maybe developers forget to add boolean variable in the class, so i had to change it from the file.
// also, you can find every key for every feature i used in this tweak, i can remove all the codes below and find every key for it but I'm lazy to do that, :)
- (BOOL)boolForKey:(NSString *)key {
    if ([BHTManager VoiceFeature] && [key isEqualToString:@"dm_voice_creation_enabled"]) {
        return true;
    }
    
    if ([key isEqualToString:@"edit_tweet_enabled"] || [key isEqualToString:@"edit_tweet_ga_composition_enabled"] || [key isEqualToString:@"edit_tweet_pdp_dialog_enabled"] || [key isEqualToString:@"edit_tweet_upsell_enabled"]) {
        return true;
    }
    
    if ([key isEqualToString:@"conversational_replies_ios_pinned_replies_consumption_enabled"] || [key isEqualToString:@"conversational_replies_ios_pinned_replies_creation_enabled"]) {
        return true;
    }
    return %orig;
}
%end

%hook T1HomeTimelineItemsViewController
- (void)_t1_initializeFleets {
    if ([BHTManager hideSpacesBar]) {
        return;
    }
    return %orig;
}
%end

%hook THFHomeTimelineItemsViewController
- (void)_t1_initializeFleets {
    if ([BHTManager hideSpacesBar]) {
        return;
    }
    return %orig;
}
%end

%hook TFNTwitterMediaUploadConfiguration
- (_Bool)photoUploadHighQualityImagesSettingIsVisible {
    return [BHTManager autoHighestLoad] ? true : %orig;
}
%end

%hook T1SlideshowViewController
- (_Bool)_t1_shouldDisplayLoadHighQualityImageItemForImageDisplayView:(id)arg1 highestQuality:(_Bool)arg2 {
    return [BHTManager autoHighestLoad] ? true : %orig;
}
- (id)_t1_loadHighQualityActionItemWithTitle:(id)arg1 forImageDisplayView:(id)arg2 highestQuality:(_Bool)arg3 {
    if ([BHTManager autoHighestLoad]) {
        arg3 = true;
    }
    return %orig(arg1, arg2, arg3);
}
%end

%hook T1ImageDisplayView
- (_Bool)_tfn_shouldUseHighestQualityImage {
    return [BHTManager autoHighestLoad] ? true : %orig;
}
- (_Bool)_tfn_shouldUseHighQualityImage {
    return [BHTManager autoHighestLoad] ? true : %orig;
}
%end

%hook T1HighQualityImagesUploadSettings
- (_Bool)shouldUploadHighQualityImages {
    return [BHTManager autoHighestLoad] ? true : %orig;
}
%end

%hook TFSTwitterAPICommandAccountStateProvider
- (_Bool)allowPromotedContent {
    return [BHTManager HidePromoted] ? true : %orig;
}
%end

%hook T1TrustedFriendsFeatureSwitches
+ (_Bool)isTrustedFriendsTweetCreationEnabled:(id)arg1 {
    return [BHTManager TwitterCircle] ? true : %orig;
}
%end

%hook TFNTwitterAccount
- (_Bool)isEditProfileUsernameEnabled {
    return true;
}
- (_Bool)isEditTweetConsumptionEnabled {
    return true;
}
- (_Bool)isTrustedFriendsAPIEnabled {
    return [BHTManager TwitterCircle] ? true : %orig;
}
- (_Bool)isSensitiveTweetWarningsComposeEnabled {
    return [BHTManager disableSensitiveTweetWarnings] ? false : %orig;
}
- (_Bool)isSensitiveTweetWarningsConsumeEnabled {
    return [BHTManager disableSensitiveTweetWarnings] ? false : %orig;
}
- (_Bool)isDmModularSearchEnabled {
    return [BHTManager DmModularSearch] ? true : %orig;
}
- (_Bool)isVideoDynamicAdEnabled {
    return [BHTManager HidePromoted] ? false : %orig;
}

- (_Bool)isVODCaptionsEnabled {
    return [BHTManager DisableVODCaptions] ? false : %orig;
}
- (_Bool)photoUploadHighQualityImagesSettingIsVisible {
    return [BHTManager autoHighestLoad] ? true : %orig;
}
- (_Bool)loadingHighestQualityImageVariantPermitted {
    return [BHTManager autoHighestLoad] ? true : %orig;
}
- (_Bool)isDoubleMaxZoomFor4KImagesEnabled {
    return [BHTManager autoHighestLoad] ? true : %orig;
}
- (_Bool)isVideoZoomEnabled {
    return [BHTManager VideoZoom] ? true : %orig;
}
- (_Bool)isDMVoiceRenderingEnabled {
    return [BHTManager VoiceFeature] ? true : %orig;
}
- (_Bool)isDMVoiceCreationEnabled {
    return [BHTManager VoiceFeature] ? true : %orig;
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
    return [BHTManager VoiceFeature] ? false : %orig;
}
%end

// MARK: Tweet confirm
%hook T1TweetComposeViewController
- (void)_t1_didTapSendButton:(UIButton *)tweetButton {
    if ([BHTManager TweetConfirm]) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.message([[BHTBundle sharedBundle] localizedStringForKey:@"CONFIRM_ALERT_MESSAGE"]);
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"YES_BUTTON_TITLE"]).handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"NO_BUTTON_TITLE"]).cancelStyle();
        } showFrom:topMostController()];
    } else {
        return %orig;
    }
}
- (void)_t1_handleTweet {
    if ([BHTManager TweetConfirm]) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.message([[BHTBundle sharedBundle] localizedStringForKey:@"CONFIRM_ALERT_MESSAGE"]);
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"YES_BUTTON_TITLE"]).handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"NO_BUTTON_TITLE"]).cancelStyle();
        } showFrom:topMostController()];
    } else {
        return %orig;
    }
}

// MARK: Status tweet
- (BOOL)_t1_isVibeCompositionEnabled {
    return true;
}
// MARK: CoTweet
- (BOOL)isTweetCollaborationEnabled {
    return true;
}
- (BOOL)_t1_canEnableCollaboration {
    return true;
}
%end

// MARK: Follow confirm
%hook TUIFollowControl
- (void)_followUser:(id)arg1 event:(id)arg2 {
    if ([BHTManager FollowConfirm]) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.message([[BHTBundle sharedBundle] localizedStringForKey:@"CONFIRM_ALERT_MESSAGE"]);
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"YES_BUTTON_TITLE"]).handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"NO_BUTTON_TITLE"]).cancelStyle();
        } showFrom:topMostController()];
    } else {
        return %orig;
    }
}
%end

// MARK: Like confirm
%hook TTAStatusInlineFavoriteButton
- (void)didTap {
    if ([BHTManager LikeConfirm]) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.message([[BHTBundle sharedBundle] localizedStringForKey:@"CONFIRM_ALERT_MESSAGE"]);
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"YES_BUTTON_TITLE"]).handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"NO_BUTTON_TITLE"]).cancelStyle();
        } showFrom:topMostController()];
    } else {
        return %orig;
    }
}
%end

%hook T1StatusInlineFavoriteButton
- (void)didTap {
    if ([BHTManager LikeConfirm]) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.message([[BHTBundle sharedBundle] localizedStringForKey:@"CONFIRM_ALERT_MESSAGE"]);
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"YES_BUTTON_TITLE"]).handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"NO_BUTTON_TITLE"]).cancelStyle();
        } showFrom:topMostController()];
    } else {
        return %orig;
    }
}
%end

%hook T1ImmersiveExploreCardView
- (void)handleDoubleTap:(id)arg1 {
    if ([BHTManager LikeConfirm]) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.message([[BHTBundle sharedBundle] localizedStringForKey:@"CONFIRM_ALERT_MESSAGE"]);
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"YES_BUTTON_TITLE"]).handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"NO_BUTTON_TITLE"]).cancelStyle();
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
            make.message([[BHTBundle sharedBundle] localizedStringForKey:@"CONFIRM_ALERT_MESSAGE"]);
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"YES_BUTTON_TITLE"]).handler(^(NSArray<NSString *> *strings) {
                %orig;
            });
            make.button([[BHTBundle sharedBundle] localizedStringForKey:@"NO_BUTTON_TITLE"]).cancelStyle();
        } showFrom:topMostController()];
    } else {
        return %orig;
    }
}
%end

// MARK: Undo tweet
%hook TFNTwitterToastNudgeExperimentModel
- (BOOL)shouldShowShowUndoTweetSentToast {
    return [BHTManager UndoTweet] ? true : %orig;
}
%end

// MARK: Reader mode
%hook T1ReaderModeConfig
- (_Bool)isReaderModeEnabled {
    return [BHTManager ReaderMode] ? true : %orig;
}
%end

// MARK: Old tweet style
%hook TTACoreAnatomyFeatures
- (BOOL)isUnifiedCardEnabled {
    return [BHTManager OldStyle] ? false : %orig;
}
- (BOOL)isModernStatusViewsQuoteTweetEnabled {
    return [BHTManager OldStyle] ? false : %orig;
}
- (BOOL)isEdgeToEdgeContentEnabled {
    return [BHTManager OldStyle] ? false : %orig;
}
%end

// MARK: BHTwitter settings
%hook TFNActionItem
%new + (instancetype)actionItemWithTitle:(NSString *)arg1 systemImageName:(NSString *)arg2 action:(void (^)(void))arg3 {
    TFNActionItem *_self = [%c(TFNActionItem) actionItemWithTitle:arg1 imageName:nil action:arg3];
     [_self setValue:[UIImage systemImageNamed:arg2] forKey:@"_image"];
    return _self;
}
%end

%hook TFNSettingsNavigationItem
%new - (instancetype)initWithTitle:(NSString *)arg1 detail:(NSString *)arg2 systemIconName:(NSString *)arg3 controllerFactory:(UIViewController* (^)(void))arg4 {
    TFNSettingsNavigationItem *_self = [[%c(TFNSettingsNavigationItem) alloc] initWithTitle:arg1 detail:arg2 iconName:arg3 controllerFactory:arg4];
    [_self setValue:[UIImage systemImageNamed:arg3] forKey:@"_icon"];
    return _self;
}
%end

%hook T1GenericSettingsViewController
- (void)viewWillAppear:(BOOL)arg1 {
    %orig;
    if ([self.sections count] == 1) {
        TFNItemsDataViewControllerBackingStore *backingStore = self.backingStore;
        TFNSettingsNavigationItem *bhtwitter = [[%c(TFNSettingsNavigationItem) alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_TITLE"] detail:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_DETAIL"] systemIconName:@"gear" controllerFactory:^UIViewController *{
            return [BHTManager BHTSettingsWithAccount:self.account];
        }];
        
        if ([backingStore respondsToSelector:@selector(insertSection:atIndex:)]) {
            [backingStore insertSection:0 atIndex:0];
        } else {
            [backingStore _tfn_insertSection:0 atIndex:0];
        }
        if ([backingStore respondsToSelector:@selector(insertItem:atIndexPath:)]) {
            [backingStore insertItem:bhtwitter atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        } else {
            [backingStore _tfn_insertItem:bhtwitter atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        }
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
        [Tweakcell.textLabel setText:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_DETAIL"]];
        return Tweakcell;
    } else if (indexPath.section == 0 && indexPath.row ==0 ) {
        
        TFNTextCell *Settingscell = [[%c(TFNTextCell) alloc] init];
        [Settingscell setBackgroundColor:[UIColor clearColor]];
        Settingscell.textLabel.textColor = [UIColor colorWithRed:0.40 green:0.47 blue:0.53 alpha:1.0];
        [Settingscell.textLabel setText:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_TITLE"]];
        return Settingscell;
    }
    
    
    return %orig;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath section]== 0 && [indexPath row]== 1) {
        [self.navigationController pushViewController:[BHTManager BHTSettingsWithAccount:self.account] animated:true];
    } else {
        return %orig;
    }
}
%end

// MARK: Change font
%hook UIFontPickerViewController
- (void)viewWillAppear:(BOOL)arg1 {
    %orig(arg1);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_FONTS_NAVIGATION_BUTTON_TITLE"] style:UIBarButtonItemStylePlain target:self action:@selector(customFontsHandler)];
}
%new - (void)customFontsHandler {
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Library/Fonts/AddedFontCache.plist"]) {
        NSAttributedString *AttString = [[NSAttributedString alloc] initWithString:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_FONTS_MENU_TITLE"] attributes:@{
            NSFontAttributeName: [[%c(TAEStandardFontGroup) sharedFontGroup] headline2BoldFont],
            NSForegroundColorAttributeName: UIColor.labelColor
        }];
        TFNActiveTextItem *title = [[%c(TFNActiveTextItem) alloc] initWithTextModel:[[%c(TFNAttributedTextModel) alloc] initWithAttributedString:AttString] activeRanges:nil];
        
        NSMutableArray *actions = [[NSMutableArray alloc] init];
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
    } else {
        UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"BHTwitter" message:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_FONTS_TUT_ALERT_MESSAGE"] preferredStyle:UIAlertControllerStyleAlert];
        
        [errAlert addAction:[UIAlertAction actionWithTitle:@"iFont application" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://apps.apple.com/sa/app/ifont-find-install-any-font/id1173222289"] options:@{} completionHandler:nil];
        }]];
        [errAlert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"OK_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:errAlert animated:true completion:nil];
    }
}
%end

%hook TAEStandardFontGroup
- (UIFont *)profilesFollowingCountFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)profilesFollowingFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)userCellFollowsYouFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)dashFollowingCountFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)dashFollowingFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)carouselUsernameFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)carouselDisplayNameFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)profilesFullNameFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)profilesUsernameFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)readerModeSmallFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)readerModeSmallBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)readerModeMediumFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)readerModeMediumBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)readerModeLargeFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)readerModeLargeBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)treeTopicsDescriptionFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)treeTopicsCategoryNameFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)treeTopicsNameFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)treeTopicsCategoryNameLargeFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)topicsPillNameFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)topicsDescriptionFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)topicsNameFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)composerTextEditorFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)statusCellEdgeToEdgeBodyBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)statusCellEdgeToEdgeBodyFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)statusCellBodyFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)statusCellBodyBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)cardAttributionFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)cardTitleBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)cardTitleFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)tweetDetailBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)tweetDetailFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)directMessageBubbleBodyFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)directMessageComposePersistentBarFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedJumboBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedXLargeBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedLargeBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedNormalBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedSmallBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedJumboFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedXLargeFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedLargeFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedNormalFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)fixedSmallFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)jumboBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)xLargeBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)largeBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)normalBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)smallBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)xSmallBoldFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(true, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)jumboFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)xLargeFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)largeFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)normalFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)smallFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)xSmallFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonXLargeFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonLargeFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonMediumFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonMedium_CondensedFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonMedium_CondensedLighterFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonSmallFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonSmallLighterFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonSmall_CondensedFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonSmall_CondensedLighterFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonNavigationBarFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
- (UIFont *)buttonHeavyNavigationBarFont {
    UIFont *origFont = %orig;
    UIFont *newFont = BH_getDefaultFont(false, origFont.pointSize);
    return newFont != nil ? newFont : origFont;
}
%end

%hook HBForceCepheiPrefs
+ (BOOL)forceCepheiPrefsWhichIReallyNeedToAccessAndIKnowWhatImDoingISwear {
    return YES;
}
%end

// MARK: Fix login keychain in non-JB (IPA).
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
