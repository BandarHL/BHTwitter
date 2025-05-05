#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SAMKeychain/AuthViewController.h"
#import "Colours/Colours.h"
#import "BHTManager.h"
#import <math.h>
#import "BHTBundle/BHTBundle.h"

// Add this before the hooks, after the imports

UIColor *BHTCurrentAccentColor(void) {
    Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
    if (!TAEColorSettingsCls) {
        return [UIColor systemBlueColor];
    }

    id settings = [TAEColorSettingsCls sharedSettings];
    id current = [settings currentColorPalette];
    id palette = [current colorPalette];
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

    if ([defs objectForKey:@"bh_color_theme_selectedColor"]) {
        NSInteger opt = [defs integerForKey:@"bh_color_theme_selectedColor"];
        return [palette primaryColorForOption:opt] ?: [UIColor systemBlueColor];
    }

    if ([defs objectForKey:@"T1ColorSettingsPrimaryColorOptionKey"]) {
        NSInteger opt = [defs integerForKey:@"T1ColorSettingsPrimaryColorOptionKey"];
        return [palette primaryColorForOption:opt] ?: [UIColor systemBlueColor];
    }

    return [UIColor systemBlueColor];
}

static UIFont * _Nullable TAEStandardFontGroupReplacement(UIFont *self, SEL _cmd, CGFloat arg1, CGFloat arg2) {
    BH_BaseImp orig  = originalFontsIMP[NSStringFromSelector(_cmd)].pointerValue;
    NSUInteger nArgs = [[self class] instanceMethodSignatureForSelector:_cmd].numberOfArguments;
    UIFont *origFont;
    switch (nArgs) {
        case 2:
            origFont = orig(self, _cmd);
            break;
        case 3:
            origFont = orig(self, _cmd, arg1);
            break;
        case 4:
            origFont = orig(self, _cmd, arg1, arg2);
            break;
        default:
            // Should not be reachable, as it was verified before swizzling
            origFont = orig(self, _cmd);
            break;
    };
    
    UIFont *newFont  = BH_getDefaultFont(origFont);
    return newFont != nil ? newFont : origFont;
}
static void batchSwizzlingOnClass(Class cls, NSArray<NSString*>*origSelectors, IMP newIMP){
    for (NSString *sel in origSelectors) {
        SEL origSel = NSSelectorFromString(sel);
        Method origMethod = class_getInstanceMethod(cls, origSel);
        if (origMethod != NULL) {
            IMP oldImp = class_replaceMethod(cls, origSel, newIMP, method_getTypeEncoding(origMethod));
            [originalFontsIMP setObject:[NSValue valueWithPointer:oldImp] forKey:sel];
        } else {
            NSLog(@"[BHTwitter] Can't find method (%@) in Class (%@)", sel, NSStringFromClass(cls));
        }
    }
}

// MARK: Clean cache and Padlock
%hook T1AppDelegate
- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"FirstRun_4.3"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"1strun" forKey:@"FirstRun_4.3"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dw_v"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"hide_promoted"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"voice"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"undo_tweet"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"TrustedFriends"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"disableSensitiveTweetWarnings"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"disable_immersive_player"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"custom_voice_upload"];
    }
    [BHTManager cleanCache];
    if ([BHTManager FLEX]) {
        [[%c(FLEXManager) sharedManager] showExplorer];
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
        [[%c(FLEXManager) sharedManager] showExplorer];
    }
}
%end

// MARK: Custom Tab bar
%hook T1TabBarViewController
- (void)loadView {
    %orig;
    NSArray <NSString *> *hiddenBars = [BHCustomTabBarUtility getHiddenTabBars];
    for (T1TabView *tabView in self.tabViews) {
        if ([hiddenBars containsObject:tabView.scribePage]) {
            [tabView setHidden:true];
        }
    }
}

- (void)setTabBarHidden:(BOOL)arg1 withDuration:(CGFloat)arg2 {
    if ([BHTManager stopHidingTabBar]) {
        return;
    }
    
    return %orig;
}
- (void)setTabBarHidden:(BOOL)arg1 {
    if ([BHTManager stopHidingTabBar]) {
        return;
    }
    
    return %orig;
}
%end


%hook T1DirectMessageConversationEntriesViewController
- (void)viewDidLoad {
    %orig;
    if ([BHTManager changeBackground]) {
        if ([BHTManager backgroundImage]) { // set the backgeound as image
            NSFileManager *manager = [NSFileManager defaultManager];
            NSString *DocPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
            NSURL *imagePath = [[NSURL fileURLWithPath:DocPath] URLByAppendingPathComponent:@"msg_background.png"];
            
            if ([manager fileExistsAtPath:imagePath.path]) {
                UIImageView *backgroundImage = [[UIImageView alloc] initWithFrame:UIScreen.mainScreen.bounds];
                backgroundImage.image = [UIImage imageNamed:imagePath.path];
                [backgroundImage setContentMode:UIViewContentModeScaleAspectFill];
                [self.view insertSubview:backgroundImage atIndex:0];
            }
        }
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"background_color"]) { // set the backgeound as color
            NSString *hexCode = [[NSUserDefaults standardUserDefaults] objectForKey:@"background_color"];
            UIColor *selectedColor = [UIColor colorFromHexString:hexCode];
            self.view.backgroundColor = selectedColor;
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
                if (self.viewModel.bio != nil)
                    UIPasteboard.generalPasteboard.string = self.viewModel.bio;
            }],
                [UIAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_2"] image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                if (self.viewModel.username != nil)
                    UIPasteboard.generalPasteboard.string = self.viewModel.username;
            }],
                [UIAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_3"] image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                if (self.viewModel.fullName != nil)
                    UIPasteboard.generalPasteboard.string = self.viewModel.fullName;
            }],
                [UIAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_4"] image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                if (self.viewModel.url != nil)
                    UIPasteboard.generalPasteboard.string = self.viewModel.url;
            }],
                [UIAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_5"] image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                if (self.viewModel.location != nil)
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
        if (self.viewModel.bio != nil)
            UIPasteboard.generalPasteboard.string = self.viewModel.bio;
    }];
    UIAlertAction *username = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_2"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (self.viewModel.username != nil)
            UIPasteboard.generalPasteboard.string = self.viewModel.username;
    }];
    UIAlertAction *fullusername = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_3"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (self.viewModel.fullName != nil)
            UIPasteboard.generalPasteboard.string = self.viewModel.fullName;
    }];
    UIAlertAction *url = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_4"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (self.viewModel.url != nil)
            UIPasteboard.generalPasteboard.string = self.viewModel.url;
    }];
    UIAlertAction *location = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_5"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (self.viewModel.location != nil)
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

%hook T1ProfileSummaryView
- (BOOL)shouldShowGetVerifiedButton {
    return [BHTManager hidePremiumOffer] ? false : %orig;
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
            if ([class_name isEqualToString:@"T1URTTimelineUserItemViewModel"] || [class_name isEqualToString:@"T1TwitterSwift.URTTimelineCarouselViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"]) {
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
        if ([BHTManager hideTrendVideos] && ([class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"] || [class_name isEqualToString:@"T1TwitterSwift.URTTimelineCarouselViewModel"])) {
            [_orig setHidden:true];
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

        if ([BHTManager hidePremiumOffer]) {
            if ([class_name isEqualToString:@"T1URTTimelineMessageItemViewModel"]) {
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
            if ([class_name isEqualToString:@"T1URTTimelineUserItemViewModel"] || [class_name isEqualToString:@"T1TwitterSwift.URTTimelineCarouselViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"]) {
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

        if ([BHTManager hideTrendVideos] && ([class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"] || [class_name isEqualToString:@"T1TwitterSwift.URTTimelineCarouselViewModel"])) {
            return 0;
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

        if ([BHTManager hidePremiumOffer]) {
            if ([class_name isEqualToString:@"T1URTTimelineMessageItemViewModel"]) {
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
        
        if ([i.contentType isEqualToString:@"application/x-mpegURL"]) {
            TFNActionItem *option = [objc_getClass("TFNActionItem") actionItemWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FFMPEG_DOWNLOAD_OPTION_TITLE"] imageName:@"arrow_down_circle_stroke" action:^{
                
                self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                self.hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"FETCHING_PROGRESS_TITLE"];
                [self.hud showInView:topMostController().view];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    MediaInformation *mediaInfo = [BHTManager getM3U8Information:[NSURL URLWithString:i.url]];
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [self.hud dismiss];

                        TFNMenuSheetViewController *alert2 = [BHTManager newFFmpegDownloadSheet:mediaInfo downloadingURL:[NSURL URLWithString:i.url] progressView:self.hud];
                        [alert2 tfnPresentedCustomPresentFromViewController:topMostController() animated:YES completion:nil];
                    });
                });
                
            }];
            
            [actions addObject:option];
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

// upload custom voice
%hook T1MediaAttachmentsViewCell
%property (nonatomic, strong) UIButton *uploadButton;
- (void)updateCellElements {
    %orig;

    if ([BHTManager customVoice]) {
        TFNButton *removeButton = [self valueForKey:@"_removeButton"];

        if ([self.attachment isKindOfClass:%c(TTMAssetVoiceRecording)]) {
            if (self.uploadButton == nil) {
                self.uploadButton = [UIButton buttonWithType:UIButtonTypeCustom];
                UIImageSymbolConfiguration *smallConfig = [UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleSmall];
                UIImage *arrowUpImage = [UIImage systemImageNamed:@"arrow.up" withConfiguration:smallConfig];
                [self.uploadButton setImage:arrowUpImage forState:UIControlStateNormal];
                [self.uploadButton addTarget:self action:@selector(handleUploadButton:) forControlEvents:UIControlEventTouchUpInside];
                [self.uploadButton setTintColor:UIColor.labelColor];
                [self.uploadButton setBackgroundColor:[UIColor blackColor]];
                [self.uploadButton.layer setCornerRadius:29/2];
                [self.uploadButton setTranslatesAutoresizingMaskIntoConstraints:false];

                if (self.uploadButton.superview == nil) {
                    [self addSubview:self.uploadButton];
                    [NSLayoutConstraint activateConstraints:@[
                        [self.uploadButton.trailingAnchor constraintEqualToAnchor:removeButton.leadingAnchor constant:-10],
                        [self.uploadButton.topAnchor constraintEqualToAnchor:removeButton.topAnchor],
                        [self.uploadButton.widthAnchor constraintEqualToConstant:29],
                        [self.uploadButton.heightAnchor constraintEqualToConstant:29],
                    ]];
                }
            }
        }
    }
}
%new - (void)handleUploadButton:(UIButton *)sender {
    UIImagePickerController *videoPicker = [[UIImagePickerController alloc] init];
    videoPicker.mediaTypes = @[(NSString*)kUTTypeMovie];
    videoPicker.delegate = self;
    
    [topMostController() presentViewController:videoPicker animated:YES completion:nil];
}
%new - (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    NSURL *videoURL = info[UIImagePickerControllerMediaURL];
    TTMAssetVoiceRecording *attachment = self.attachment;
    NSURL *recorder_url = [NSURL fileURLWithPath:attachment.filePath];
    
    if (recorder_url != nil) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSError *error = nil;
        if ([fileManager fileExistsAtPath:[recorder_url path]]) {
            [fileManager removeItemAtURL:recorder_url error:&error];
            if (error) {
                NSLog(@"[BHTwitter] Error removing existing file: %@", error);
            }
        }
        
        [fileManager copyItemAtURL:videoURL toURL:recorder_url error:&error];
        if (error) {
            NSLog(@"[BHTwitter] Error copying file: %@", error);
        }
    }
    
    [picker dismissViewControllerAnimated:true completion:nil];
}
%new - (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:true completion:nil];
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

%new
- (BOOL)shouldThemeIcon {
    UIViewController *ancestor = [self _viewControllerForAncestor];
    if (!ancestor) {
        return NO;
    }
    
    // Always allow onboarding
    if ([ancestor isKindOfClass:NSClassFromString(@"ONBSignedOutViewController")]) {
        return YES;
    }
    
    // Get navigation controller
    UINavigationController *navController = nil;
    if ([ancestor isKindOfClass:[UINavigationController class]]) {
        navController = (UINavigationController *)ancestor;
    } else {
        navController = ancestor.navigationController;
    }
    
    // Check if we're on a detail view
    if (navController && navController.viewControllers.count > 1) {
        return NO;
    }
    
    // Show on timeline navigation controller with single view
    if ([NSStringFromClass([ancestor class]) containsString:@"TimelineNavigationController"]) {
        return YES;
    }
    
    // Show on home timeline views
    if ([NSStringFromClass([ancestor class]) containsString:@"HomeTimelineViewController"] || 
        [NSStringFromClass([ancestor class]) containsString:@"FeedTimelineViewController"]) {
        return YES;
    }
    
    return NO;
}

- (void)didMoveToWindow {
    %orig;
    [self updateLogoTheme];
}

- (void)didMoveToSuperview {
    %orig;
    [self updateLogoTheme];
}

%new
- (void)updateLogoTheme {
    BOOL shouldTheme = [self shouldThemeIcon];
    
    // ONLY look at DIRECT subviews of the navigation bar
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imageView = (UIImageView *)subview;
            
            // VERY specific size check to only match Twitter logo
            CGFloat width = imageView.frame.size.width;
            CGFloat height = imageView.frame.size.height;
            
            // Twitter logo is EXACTLY 29x29 with minimal tolerance
            BOOL isTwitterLogo = fabs(width - 29.0) < 0.1 && fabs(height - 29.0) < 0.1;
            
            if (isTwitterLogo) {
                if (shouldTheme) {
                    // Get the original image
                    UIImage *originalImage = imageView.image;
                    if (originalImage && originalImage.renderingMode != UIImageRenderingModeAlwaysTemplate) {
                        // Create template image from original
                        UIImage *templateImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                        imageView.image = templateImage;
                        imageView.tintColor = BHTCurrentAccentColor();
                    }
                }
            }
        }
    }
}

%end

// MARK: Save tweet as an image
// Twitter 9.31 and higher
%hook TTAStatusInlineShareButton
- (void)didLongPressActionButton:(UILongPressGestureRecognizer *)gestureRecognizer {
    if ([BHTManager tweetToImage]) {
        if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
            T1StatusInlineActionsView *actionsView = (T1StatusInlineActionsView *)self.delegate;
            T1StatusCell *tweetView;
            
            if ([actionsView.superview isKindOfClass:%c(T1StandardStatusView)]) { // normal tweet in the time line
                tweetView = [(T1StandardStatusView *)actionsView.superview eventHandler];
            } else if ([actionsView.superview isKindOfClass:%c(T1TweetDetailsFocalStatusView)]) { // Focus tweet
                tweetView = [(T1TweetDetailsFocalStatusView *)actionsView.superview eventHandler];
            } else if ([actionsView.superview isKindOfClass:%c(T1ConversationFocalStatusView)]) { // Focus tweet
                tweetView = [(T1ConversationFocalStatusView *)actionsView.superview eventHandler];
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
            } else if ([actionsView.superview isKindOfClass:%c(T1ConversationFocalStatusView)]) { // Focus tweet
                tweetView = [(T1ConversationFocalStatusView *)actionsView.superview eventHandler];
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
    
    if ([newOrig containsObject:%c(TTAStatusInlineAnalyticsButton)] && [BHTManager hideViewCount]) {
        [newOrig removeObject:%c(TTAStatusInlineAnalyticsButton)];
    }

    if ([newOrig containsObject:%c(TTAStatusInlineBookmarkButton)] && [BHTManager hideBookmarkButton]) {
        [newOrig removeObject:%c(TTAStatusInlineBookmarkButton)];
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

// MARK: Voice, SensitiveTweetWarnings, autoHighestLoad, VideoZoom, VODCaptions, disableSpacesBar feature
%hook TPSTwitterFeatureSwitches
// Twitter save all the features and keys in side JSON file in bundle of application fs_embedded_defaults_production.json, and use it in TFNTwitterAccount class but with DM voice maybe developers forget to add boolean variable in the class, so i had to change it from the file.
// also, you can find every key for every feature i used in this tweak, i can remove all the codes below and find every key for it but I'm lazy to do that, :)
- (BOOL)boolForKey:(NSString *)key {
    if ([key isEqualToString:@"edit_tweet_enabled"] || [key isEqualToString:@"edit_tweet_ga_composition_enabled"] || [key isEqualToString:@"edit_tweet_pdp_dialog_enabled"] || [key isEqualToString:@"edit_tweet_upsell_enabled"]) {
        return true;
    }
    
    if ([key isEqualToString:@"articles_timeline_profile_tab_enabled"]) {
        return ![BHTManager disableArticles];
    }

    if ([key isEqualToString:@"highlights_tweets_tab_ui_enabled"]) {
        return ![BHTManager disableHighlights];
    }

    if ([key isEqualToString:@"media_tab_profile_videos_tab_enabled"] || [key isEqualToString:@"media_tab_profile_photos_tab_enabled"]) {
        return ![BHTManager disableMediaTab];
    }

    if ([key isEqualToString:@"dash_items_download_grok_enabled"]) {
        return false;
    }
    
    if ([key isEqualToString:@"conversational_replies_ios_minimal_detail_enabled"]) {
        return ![BHTManager OldStyle];
    }
    
    return %orig;
}
%end

// MARK: Force Tweets to show images as Full frame: https://github.com/BandarHL/BHTwitter/issues/101
%hook T1StandardStatusAttachmentViewAdapter
- (NSUInteger)displayType {
    if (self.attachmentType == 2) {
        return [BHTManager forceTweetFullFrame] ? 1 : %orig;
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

%hook THFHomeTimelineContainerViewController
- (void)_t1_showPremiumUpsellIfNeeded {
    if ([BHTManager hidePremiumOffer]) {
        return;
    }
    return %orig;
}
- (void)_t1_showPremiumUpsellIfNeededWithScribing:(BOOL)arg1 {
    if ([BHTManager hidePremiumOffer]) {
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

%hook TFNTwitterAccount
- (_Bool)isEditProfileUsernameEnabled {
    return true;
}
- (_Bool)isEditTweetConsumptionEnabled {
    return true;
}
- (_Bool)isSensitiveTweetWarningsComposeEnabled {
    return [BHTManager disableSensitiveTweetWarnings] ? false : %orig;
}
- (_Bool)isSensitiveTweetWarningsConsumeEnabled {
    return [BHTManager disableSensitiveTweetWarnings] ? false : %orig;
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
%end

// MARK: Tweet confirm
%hook T1TweetComposeViewController
- (void)_t1_didTapSendButton:(UIButton *)tweetButton {
    if ([BHTManager TweetConfirm]) {
        [%c(FLEXAlert) makeAlert:^(FLEXAlert *make) {
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
        [%c(FLEXAlert) makeAlert:^(FLEXAlert *make) {
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
        [%c(FLEXAlert) makeAlert:^(FLEXAlert *make) {
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
        [%c(FLEXAlert) makeAlert:^(FLEXAlert *make) {
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
        [%c(FLEXAlert) makeAlert:^(FLEXAlert *make) {
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
        [%c(FLEXAlert) makeAlert:^(FLEXAlert *make) {
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
        [%c(FLEXAlert) makeAlert:^(FLEXAlert *make) {
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
        TFNSettingsNavigationItem *bhtwitter = [[%c(TFNSettingsNavigationItem) alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_TITLE"] detail:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_DETAIL"] systemIconName:@"gearshape.circle" controllerFactory:^UIViewController *{
            return [BHTManager BHTSettingsWithAccount:self.account];
        }];
        
        if ([backingStore respondsToSelector:@selector(insertSection:atIndex:)]) {
            [backingStore insertSection:0 atIndex:1];
        } else {
            [backingStore _tfn_insertSection:0 atIndex:1];
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
        [DataViewControllerBackingStore insertSection:0 atIndex:1];
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
+ (TAEStandardFontGroup *)sharedFontGroup {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *fontsMethods = [NSMutableArray arrayWithArray:@[]];
        
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList([self class], &methodCount);
        for (unsigned int i = 0; i < methodCount; ++i) {
            Method method = methods[i];
            SEL sel = method_getName(method);
            NSString *selStr = NSStringFromSelector(sel);
            
            NSMethodSignature *methodSig = [self instanceMethodSignatureForSelector:sel];
            if (strcmp(methodSig.methodReturnType, @encode(void)) == 0) {
                // Only add methods that return an object
                continue;
            } else if (methodSig.numberOfArguments == 2) {
                // - (id)bodyFont; ...
                [fontsMethods addObject:selStr];
            } else if (methodSig.numberOfArguments == 3
                       && strcmp([methodSig getArgumentTypeAtIndex:2], @encode(CGFloat)) == 0) {
                // - (id)fontOfSize:(CGFloat); ...
                [fontsMethods addObject:selStr];
            } else if (methodSig.numberOfArguments == 4
                       && strcmp([methodSig getArgumentTypeAtIndex:2], @encode(CGFloat)) == 0
                       && strcmp([methodSig getArgumentTypeAtIndex:3], @encode(CGFloat)) == 0) {
                // - (id)monospacedDigitalFontOfSize:(CGFloat) weight:(CGFloat); ...
                [fontsMethods addObject:selStr];
            } else {
                NSLog(@"[BHTwitter] Method (%@) with unknown signiture (%@) in TAEStandardFontGroup", selStr, methodSig);
            }
        }
        free(methods);
        
        originalFontsIMP = [NSMutableDictionary new];
        batchSwizzlingOnClass([self class], [fontsMethods copy], (IMP)TAEStandardFontGroupReplacement);
    });
    return %orig;
}
%end

%hook HBForceCepheiPrefs
+ (BOOL)forceCepheiPrefsWhichIReallyNeedToAccessAndIKnowWhatImDoingISwear {
    return YES;
}
%end

// MARK: Show Scroll Bar
%hook TFNTableView
- (void)setShowsVerticalScrollIndicator:(BOOL)arg1 {
    %orig([BHTManager showScrollIndicator]);
}
%end

// MARK: Clean tracking from copied links: https://github.com/BandarHL/BHTwitter/issues/75
%ctor {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    // Someone needs to hold reference the to Notification
    _PasteboardChangeObserver = [center addObserverForName:UIPasteboardChangedNotification object:nil queue:mainQueue usingBlock:^(NSNotification * _Nonnull note){
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            trackingParams = @{
                @"twitter.com" : @[@"s", @"t"],
                @"x.com" : @[@"s", @"t"],
            };
        });
        
        if ([BHTManager stripTrackingParams]) {
            if (UIPasteboard.generalPasteboard.hasURLs) {
                NSURL *pasteboardURL = UIPasteboard.generalPasteboard.URL;
                NSArray<NSString*>* params = trackingParams[pasteboardURL.host];
                
                if ([pasteboardURL.absoluteString isEqualToString:_lastCopiedURL] == NO && params != nil && pasteboardURL.query != nil) {
                    // to prevent endless copy loop
                    _lastCopiedURL = pasteboardURL.absoluteString;
                    NSURLComponents *cleanedURL = [NSURLComponents componentsWithURL:pasteboardURL resolvingAgainstBaseURL:NO];
                    NSMutableArray<NSURLQueryItem*> *safeParams = [NSMutableArray arrayWithCapacity:0];
                    
                    for (NSURLQueryItem *item in cleanedURL.queryItems) {
                        if ([params containsObject:item.name] == NO) {
                            [safeParams addObject:item];
                        }
                    }
                    cleanedURL.queryItems = safeParams.count > 0 ? safeParams : nil;

                    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"tweet_url_host"]) {
                        NSString *selectedHost = [[NSUserDefaults standardUserDefaults] objectForKey:@"tweet_url_host"];
                        cleanedURL.host = selectedHost;
                    }
                    UIPasteboard.generalPasteboard.URL = cleanedURL.URL;
                }
            }
        }
    }];
    %init;
}

// MARK: Restore Source Labels - This is still pretty experimental and may break. This restores Tweet Source Labels by using an Legacy API. by: @nyaathea

static NSMutableDictionary *tweetSources      = nil;
static NSMutableDictionary *viewToTweetID     = nil;
static NSMutableDictionary *fetchTimeouts     = nil;
static NSMutableDictionary *viewInstances     = nil;
static NSMutableDictionary *fetchRetries      = nil;
static NSMutableDictionary *updateRetries     = nil;
static NSMutableDictionary *updateCompleted   = nil;
static NSMutableDictionary *fetchPending      = nil;
static NSMutableDictionary *cookieCache       = nil;
static NSDate *lastCookieRefresh              = nil;

// Constants for cookie refresh interval (7 days in seconds)
#define COOKIE_REFRESH_INTERVAL (7 * 24 * 60 * 60)

// --- Networking & Helper Implementation ---
@interface TweetSourceHelper : NSObject
+ (void)fetchSourceForTweetID:(NSString *)tweetID;
+ (void)timeoutFetchForTweetID:(NSTimer *)timer;
+ (void)retryUpdateForTweetID:(NSString *)tweetID;
+ (void)pollForPendingUpdates;
+ (void)handleAppForeground:(NSNotification *)notification;
+ (NSDictionary *)fetchCookies;
+ (void)cacheCookies:(NSDictionary *)cookies;
+ (NSDictionary *)loadCachedCookies;
+ (BOOL)shouldRefreshCookies;
@end

@implementation TweetSourceHelper

+ (NSDictionary *)fetchCookies {
    NSMutableDictionary *cookiesDict = [NSMutableDictionary dictionary];
    NSArray *domains = @[@"api.twitter.com", @".twitter.com"];
    NSArray *requiredCookies = @[@"ct0", @"auth_token", @"twid", @"guest_id", @"guest_id_ads", @"guest_id_marketing", @"personalization_id"];
    
    for (NSString *domain in domains) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", domain]];
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url];
        for (NSHTTPCookie *cookie in cookies) {
            if ([requiredCookies containsObject:cookie.name]) {
                cookiesDict[cookie.name] = cookie.value;
            }
        }
    }
    
    NSLog(@"TweetSourceTweak: Fetched cookies: %@", cookiesDict);
    return cookiesDict;
}

+ (void)cacheCookies:(NSDictionary *)cookies {
    if (!cookies || cookies.count == 0) {
        NSLog(@"TweetSourceTweak: No cookies to cache");
        return;
    }
    
    cookieCache = [cookies mutableCopy];
    lastCookieRefresh = [NSDate date];
    
    // Persist to NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:cookies forKey:@"TweetSourceTweak_CookieCache"];
    [defaults setObject:lastCookieRefresh forKey:@"TweetSourceTweak_LastCookieRefresh"];
    [defaults synchronize];
    
    NSLog(@"TweetSourceTweak: Cached cookies: %@", cookies);
}

+ (NSDictionary *)loadCachedCookies {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *cachedCookies = [defaults dictionaryForKey:@"TweetSourceTweak_CookieCache"];
    lastCookieRefresh = [defaults objectForKey:@"TweetSourceTweak_LastCookieRefresh"];
    
    if (cachedCookies) {
        cookieCache = [cachedCookies mutableCopy];
        NSLog(@"TweetSourceTweak: Loaded cached cookies: %@", cachedCookies);
    } else {
        NSLog(@"TweetSourceTweak: No cached cookies found");
    }
    
    return cachedCookies;
}

+ (BOOL)shouldRefreshCookies {
    if (!lastCookieRefresh) {
        return YES;
    }
    NSTimeInterval timeSinceLastRefresh = [[NSDate date] timeIntervalSinceDate:lastCookieRefresh];
    return timeSinceLastRefresh >= COOKIE_REFRESH_INTERVAL;
}

+ (void)fetchSourceForTweetID:(NSString *)tweetID {
    if (!tweetID) return;
    @try {
        if (!tweetSources)   tweetSources   = [NSMutableDictionary dictionary];
        if (!fetchTimeouts)  fetchTimeouts  = [NSMutableDictionary dictionary];
        if (!fetchRetries)   fetchRetries   = [NSMutableDictionary dictionary];
        if (!fetchPending)   fetchPending   = [NSMutableDictionary dictionary];

        if (fetchPending[tweetID] || (tweetSources[tweetID] &&
            ![tweetSources[tweetID] isEqualToString:@""] &&
            ![tweetSources[tweetID] isEqualToString:@"Source Unavailable"])) {
            return; // Skip if fetch is pending or already has a valid source
        }

        fetchPending[tweetID] = @(YES);

        if (!fetchRetries[tweetID]) fetchRetries[tweetID] = @(0);
        NSNumber *retryCount = fetchRetries[tweetID];
        if (retryCount.integerValue >= 2) {
            tweetSources[tweetID] = @"Source Unavailable";
            fetchPending[tweetID] = @(NO);
            return;
        }

        NSTimer *timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:6.0
                                                                 target:self
                                                               selector:@selector(timeoutFetchForTweetID:)
                                                               userInfo:@{@"tweetID": tweetID}
                                                                repeats:NO];
        fetchTimeouts[tweetID] = timeoutTimer;

        NSString *urlString = [NSString stringWithFormat:@"https://api.twitter.com/2/timeline/conversation/%@.json?include_ext_alt_text=true&include_reply_count=true&tweet_mode=extended", tweetID];
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            tweetSources[tweetID] = @"Source Unavailable";
            fetchPending[tweetID] = @(NO);
            [fetchTimeouts removeObjectForKey:tweetID];
            [timeoutTimer invalidate];
            return;
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"GET";
        request.timeoutInterval = 5.0;

        // Load cached cookies if not already loaded
        if (!cookieCache) {
            [self loadCachedCookies];
        }

        NSDictionary *cookiesToUse = cookieCache;
        if ([self shouldRefreshCookies] || !cookiesToUse) {
            NSDictionary *freshCookies = [self fetchCookies];
            if (freshCookies.count > 0) {
                [self cacheCookies:freshCookies];
                cookiesToUse = freshCookies;
            } else if (cookiesToUse.count == 0) {
                NSLog(@"TweetSourceTweak: No cookies available for tweet %@", tweetID);
                tweetSources[tweetID] = @"Source Unavailable";
                fetchPending[tweetID] = @(NO);
                [fetchTimeouts removeObjectForKey:tweetID];
                [timeoutTimer invalidate];
                return;
            }
        }

        NSMutableArray *cookieStrings = [NSMutableArray array];
        NSString *ct0Value = cookiesToUse[@"ct0"];
        for (NSString *cookieName in cookiesToUse) {
            NSString *cookieValue = cookiesToUse[cookieName];
            [cookieStrings addObject:[NSString stringWithFormat:@"%@=%@", cookieName, cookieValue]];
        }

        [request setValue:@"Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA" forHTTPHeaderField:@"Authorization"];
        [request setValue:@"OAuth2Session" forHTTPHeaderField:@"x-twitter-auth-type"];
        [request setValue:@"CFNetwork/1331.0.7 Darwin/16.9.0" forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];

        if (ct0Value) {
            [request setValue:ct0Value forHTTPHeaderField:@"x-csrf-token"];
        } else {
            NSLog(@"TweetSourceTweak: No ct0 cookie available for tweet %@", tweetID);
            tweetSources[tweetID] = @"Source Unavailable";
            fetchPending[tweetID] = @(NO);
            [fetchTimeouts removeObjectForKey:tweetID];
            [timeoutTimer invalidate];
            return;
        }

        if (cookieStrings.count > 0) {
            NSString *cookieHeader = [cookieStrings componentsJoinedByString:@"; "];
            [request setValue:cookieHeader forHTTPHeaderField:@"Cookie"];
        } else {
            NSLog(@"TweetSourceTweak: No cookies to set for tweet %@", tweetID);
            tweetSources[tweetID] = @"Source Unavailable";
            fetchPending[tweetID] = @(NO);
            [fetchTimeouts removeObjectForKey:tweetID];
            [timeoutTimer invalidate];
            return;
        }

        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            @try {
                NSTimer *timer = fetchTimeouts[tweetID];
                if (timer) {
                    [timer invalidate];
                    [fetchTimeouts removeObjectForKey:tweetID];
                }

                fetchPending[tweetID] = @(NO);

                if (error) {
                    NSLog(@"TweetSourceTweak: Fetch error for tweet %@: %@", tweetID, error);
                    fetchRetries[tweetID] = @(retryCount.integerValue + 1);
                    if (retryCount.integerValue < 2) {
                        [self fetchSourceForTweetID:tweetID];
                    } else {
                        tweetSources[tweetID] = @"Source Unavailable";
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    }
                    return;
                }

                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode != 200) {
                    NSLog(@"TweetSourceTweak: Fetch failed for tweet %@ with status code %ld", tweetID, (long)httpResponse.statusCode);
                    fetchRetries[tweetID] = @(retryCount.integerValue + 1);
                    if (retryCount.integerValue < 2) {
                        if (httpResponse.statusCode == 401 || httpResponse.statusCode == 403) {
                            NSDictionary *freshCookies = [self fetchCookies];
                            if (freshCookies.count > 0) {
                                [self cacheCookies:freshCookies];
                                [self fetchSourceForTweetID:tweetID];
                                return;
                            }
                        }
                        [self fetchSourceForTweetID:tweetID];
                    } else {
                        tweetSources[tweetID] = @"Source Unavailable";
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    }
                    return;
                }

                NSError *jsonError;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (jsonError) {
                    NSLog(@"TweetSourceTweak: JSON parse error for tweet %@: %@", tweetID, jsonError);
                    fetchRetries[tweetID] = @(retryCount.integerValue + 1);
                    if (retryCount.integerValue < 2) {
                        [self fetchSourceForTweetID:tweetID];
                    } else {
                        tweetSources[tweetID] = @"Source Unavailable";
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    }
                    return;
                }

                NSDictionary *tweets    = json[@"globalObjects"][@"tweets"];
                NSDictionary *tweetData = tweets[tweetID];
                NSString *sourceHTML    = tweetData[@"source"];

                if (sourceHTML) {
                    NSString *sourceText = sourceHTML;
                    NSRange startRange = [sourceHTML rangeOfString:@">"];
                    NSRange endRange   = [sourceHTML rangeOfString:@"</a>"];
                    if (startRange.location != NSNotFound && endRange.location != NSNotFound && startRange.location + 1 < endRange.location) {
                        sourceText = [sourceHTML substringWithRange:NSMakeRange(startRange.location + 1, endRange.location - startRange.location - 1)];
                        // Clean up sourceText by removing leading numeric string (e.g., "1694706607912062977NinEverythi" -> "NinEverythi")
                        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\d+" options:0 error:nil];
                        sourceText = [regex stringByReplacingMatchesInString:sourceText options:0 range:NSMakeRange(0, sourceText.length) withTemplate:@""];
                    }
                    tweetSources[tweetID] = sourceText;
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:0.3];
                } else {
                    tweetSources[tweetID] = @"Unknown Source";
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:0.3];
                }
            } @catch (NSException *e) {
                NSLog(@"TweetSourceTweak: Exception in fetch completion for tweet %@: %@", tweetID, e);
                tweetSources[tweetID] = @"Source Unavailable";
                fetchPending[tweetID] = @(NO);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
            }
        }];
        [task resume];
    } @catch (NSException *e) {
        NSLog(@"TweetSourceTweak: Exception in fetch setup for tweet %@: %@", tweetID, e);
        tweetSources[tweetID] = @"Source Unavailable";
        fetchPending[tweetID] = @(NO);
        NSTimer *timer = fetchTimeouts[tweetID];
        if (timer) {
            [timer invalidate];
            [fetchTimeouts removeObjectForKey:tweetID];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
    }
}

+ (void)timeoutFetchForTweetID:(NSTimer *)timer {
    NSString *tweetID = timer.userInfo[@"tweetID"];
    if (tweetID && fetchPending[tweetID]) {
        NSNumber *retryCount = fetchRetries[tweetID];
        fetchRetries[tweetID] = @(retryCount.integerValue + 1);
        fetchPending[tweetID] = @(NO);
        [fetchTimeouts removeObjectForKey:tweetID];
        if (retryCount.integerValue < 2) {
            [self fetchSourceForTweetID:tweetID];
        } else {
            tweetSources[tweetID] = @"Source Unavailable";
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
            [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:0.3];
        }
    }
}

+ (void)retryUpdateForTweetID:(NSString *)tweetID {
    @try {
        if (!updateRetries)   updateRetries   = [NSMutableDictionary dictionary];
        if (!updateCompleted) updateCompleted = [NSMutableDictionary dictionary];

        if (updateCompleted[tweetID] && [updateCompleted[tweetID] boolValue]) return;
        if (!updateRetries[tweetID]) updateRetries[tweetID] = @(0);

        NSNumber *retryCount = updateRetries[tweetID];
        updateRetries[tweetID] = @(retryCount.integerValue + 1);

        if (tweetSources[tweetID] && ![tweetSources[tweetID] isEqualToString:@""]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
            NSTimeInterval delay = (retryCount.integerValue < 10) ? 0.5 : (retryCount.integerValue < 20) ? 1.0 : 3.0;
            [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:delay];
        }
    } @catch (__unused NSException *e) {}
}

+ (void)pollForPendingUpdates {
    @try {
        if (!tweetSources || !updateCompleted) return;
        NSArray *allTweetIDs = [tweetSources allKeys];
        for (NSString *tweetID in allTweetIDs) {
            if (tweetSources[tweetID] && ![tweetSources[tweetID] isEqualToString:@""] &&
                ![tweetSources[tweetID] isEqualToString:@"Source Unavailable"]) {
                if (!updateCompleted[tweetID] || ![updateCompleted[tweetID] boolValue]) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    if (!updateRetries[tweetID] || [updateRetries[tweetID] integerValue] < 5) {
                        [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:1.0];
                    }
                }
            }
        }
        [self performSelector:@selector(pollForPendingUpdates) withObject:nil afterDelay:5.0];
    } @catch (__unused NSException *e) {}
}

+ (void)handleAppForeground:(NSNotification *)notification {
    @try {
        [self performSelector:@selector(pollForPendingUpdates) withObject:nil afterDelay:1.0];
    } @catch (__unused NSException *e) {}
}

@end
// --- End Helper Implementation ---

%hook TFNTwitterStatus

- (id)init {
    id originalSelf = %orig;
    @try {
        NSInteger statusID = self.statusID;
        if (statusID > 0) {
            if (!tweetSources) tweetSources = [NSMutableDictionary dictionary];
            if (!tweetSources[@(statusID).stringValue]) {
                tweetSources[@(statusID).stringValue] = @"";
                [TweetSourceHelper fetchSourceForTweetID:@(statusID).stringValue];
            }
        }
    } @catch (__unused NSException *e) {}
    return originalSelf;
}

%end

%hook T1ConversationFocalStatusView

- (void)setViewModel:(id)viewModel {
    %orig;
    @try {
        if (viewModel) {
            id status = nil;
            @try { status = [viewModel valueForKey:@"tweet"]; } @catch (__unused NSException *e) {}
            if (status) {
                NSInteger statusID = 0;
                @try {
                    statusID = [[status valueForKey:@"statusID"] integerValue];
                    if (statusID > 0) {
                        if (!tweetSources)   tweetSources   = [NSMutableDictionary dictionary];
                        if (!viewToTweetID)  viewToTweetID  = [NSMutableDictionary dictionary];
                        if (!viewInstances)  viewInstances  = [NSMutableDictionary dictionary];

                        NSString *tweetIDStr = @(statusID).stringValue;
                        viewToTweetID[@((uintptr_t)self)] = tweetIDStr;
                        viewInstances[tweetIDStr] = [NSValue valueWithNonretainedObject:self];

                        if (!tweetSources[tweetIDStr]) {
                            tweetSources[tweetIDStr] = @"";
                            [TweetSourceHelper fetchSourceForTweetID:tweetIDStr];
                        } else if (tweetSources[tweetIDStr] && ![tweetSources[tweetIDStr] isEqualToString:@""] &&
                                   (!updateCompleted[tweetIDStr] || ![updateCompleted[tweetIDStr] boolValue])) {
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetIDStr}];
                        }
                    }
                } @catch (__unused NSException *e) {}

                if (statusID <= 0) {
                    @try {
                        NSString *altID = [status valueForKey:@"rest_id"] ?: [status valueForKey:@"id_str"] ?: [status valueForKey:@"id"];
                        if (altID) {
                            if (!tweetSources)   tweetSources   = [NSMutableDictionary dictionary];
                            if (!viewToTweetID)  viewToTweetID  = [NSMutableDictionary dictionary];
                            if (!viewInstances)  viewInstances  = [NSMutableDictionary dictionary];

                            viewToTweetID[@((uintptr_t)self)] = altID;
                            viewInstances[altID]              = [NSValue valueWithNonretainedObject:self];

                            if (!tweetSources[altID]) {
                                tweetSources[altID] = @"";
                                [TweetSourceHelper fetchSourceForTweetID:altID];
                            } else if (tweetSources[altID] && ![tweetSources[altID] isEqualToString:@""] &&
                                       (!updateCompleted[altID] || ![updateCompleted[altID] boolValue])) {
                                [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": altID}];
                            }
                        }
                    } @catch (__unused NSException *e) {}
                }
            }
        }
    } @catch (__unused NSException *e) {}
}

- (void)dealloc {
    @try {
        NSString *tweetID = viewToTweetID[@((uintptr_t)self)];
        if (tweetID) {
            [viewToTweetID removeObjectForKey:@((uintptr_t)self)];
            if (viewInstances[tweetID]) {
                NSValue *viewValue = viewInstances[tweetID];
                UIView *storedView = [viewValue nonretainedObjectValue];
                if (storedView == self) {
                    [viewInstances removeObjectForKey:tweetID];
                }
            }
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)handleTweetSourceUpdated:(NSNotification *)notification {
    @try {
        NSDictionary *userInfo = notification.userInfo;
        NSString *tweetID      = userInfo[@"tweetID"];
        if (tweetID && tweetSources[tweetID] && ![tweetSources[tweetID] isEqualToString:@""]) {
            NSValue *viewValue = viewInstances[tweetID];
            UIView  *target    = viewValue ? [viewValue nonretainedObjectValue] : nil;
            if (target) {
                NSString *currentTweetID = viewToTweetID[@((uintptr_t)target)];
                if (currentTweetID && [currentTweetID isEqualToString:tweetID]) {
                    [self enumerateSubviewsRecursively:^(UIView *subview) {
                        if ([subview isKindOfClass:%c(TFNAttributedTextView)]) {
                            TFNAttributedTextView *textView = (TFNAttributedTextView *)subview;
                            TFNAttributedTextModel *model = [textView valueForKey:@"_textModel"];
                            if (model && model.attributedString.string) {
                                NSString *text = model.attributedString.string;
                                if ([text containsString:@"PM"] || [text containsString:@"AM"] ||
                                    [text rangeOfString:@"\\d{1,2}[:.]\\d{1,2}" options:NSRegularExpressionSearch].location != NSNotFound) {
                                    // Force a refresh of the text model
                                    [textView setTextModel:nil];
                                    [textView setTextModel:model];
                                }
                            }
                        }
                    }];
                }
            }
        }
    } @catch (__unused NSException *e) {}
}

%new
- (void)enumerateSubviewsRecursively:(void (^)(UIView *))block {
    block(self);
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(UIView)]) {
            [self enumerateSubviewsRecursively:block];
        }
    }
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleTweetSourceUpdated:)
                                                     name:@"TweetSourceUpdated"
                                                   object:nil];
        [TweetSourceHelper performSelector:@selector(pollForPendingUpdates) withObject:nil afterDelay:3.0];
        [[NSNotificationCenter defaultCenter] addObserver:[TweetSourceHelper class]
                                                 selector:@selector(handleAppForeground:)
                                                     name:@"UIApplicationDidBecomeActiveNotification"
                                                   object:nil];
    });
}

%end

%hook TFNAttributedTextView

- (void)setTextModel:(TFNAttributedTextModel *)model {
    // --- BHTwitter style: Only run if toggle is ON ---
    if (![BHTManager RestoreTweetLabels]) {
        %orig;
        return;
    }
    if (!model || !model.attributedString) {
        %orig;
        return;
    }

    NSString *currentText = model.attributedString.string;
    BOOL isTimestamp = NO;
    
    // Check if this is a timestamp format
    if ([currentText containsString:@"PM"] || [currentText containsString:@"AM"]) {
        isTimestamp = YES;
    } else {
        NSRegularExpression *timeRegex = [NSRegularExpression regularExpressionWithPattern:@"\\d{1,2}[:.]\\d{1,2}"
                                                                                   options:0
                                                                                     error:nil];
        NSRange range = [timeRegex rangeOfFirstMatchInString:currentText options:0 range:NSMakeRange(0, currentText.length)];
        if (range.location != NSNotFound) isTimestamp = YES;
    }

    if (isTimestamp) {
        @try {
            UIView *view = self;
            id tweetViewModel = nil;
            BOOL isDetailView = NO;
            
            // Walk up the view hierarchy to find the tweet view model and check if we're in a detail view
            while (view && (!tweetViewModel || !isDetailView)) {
                if ([NSStringFromClass([view class]) containsString:@"TweetDetails"] ||
                    [NSStringFromClass([view class]) containsString:@"ConversationFocal"]) {
                    isDetailView = YES;
                }
                
                if ([view respondsToSelector:@selector(viewModel)]) {
                    tweetViewModel = [view performSelector:@selector(viewModel)];
                }
                view = view.superview;
            }
            
            // Only proceed if we're in a detail view
            if (!isDetailView) {
                %orig;
                return;
            }

            if ([tweetViewModel respondsToSelector:@selector(tweet)]) {
                id tweet = [tweetViewModel performSelector:@selector(tweet)];
                if (tweet) {
                    NSInteger statusID = 0;
                    @try {
                        statusID = [[tweet valueForKey:@"statusID"] integerValue];
                    } @catch (__unused NSException *e) {
                        // Try alternative IDs if statusID fails
                        NSString *altID = [tweet valueForKey:@"rest_id"] ?: [tweet valueForKey:@"id_str"] ?: [tweet valueForKey:@"id"];
                        if (altID) {
                            if (!tweetSources) tweetSources = [NSMutableDictionary dictionary];
                            if (!tweetSources[altID]) {
                                tweetSources[altID] = @"";
                                [TweetSourceHelper fetchSourceForTweetID:altID];
                            }
                            
                            if (tweetSources[altID] && ![tweetSources[altID] isEqualToString:@""]) {
                                NSString *sourceText = tweetSources[altID];
                                NSMutableAttributedString *newString = [[NSMutableAttributedString alloc] initWithAttributedString:model.attributedString];
                                
                                // Get existing attributes from the timestamp
                                NSDictionary *existingAttributes = nil;
                                if (newString.length > 0) {
                                    existingAttributes = [newString attributesAtIndex:0 effectiveRange:NULL];
                                }
                                
                                // Add separator and source text
                                NSMutableAttributedString *appended = [[NSMutableAttributedString alloc] init];
                                [appended appendAttributedString:[[NSAttributedString alloc] initWithString:@" · " attributes:existingAttributes]];
                                
                                // Use current accent color for source text
                                NSMutableDictionary *sourceAttributes = [existingAttributes mutableCopy];
                                [sourceAttributes setObject:BHTCurrentAccentColor() forKey:NSForegroundColorAttributeName];
                                [appended appendAttributedString:[[NSAttributedString alloc] initWithString:sourceText attributes:sourceAttributes]];
                                
                                [newString appendAttributedString:appended];
                                [model setValue:newString forKey:@"attributedString"];
                            }
                        }
                    }
                    
                    if (statusID > 0) {
                        NSString *tweetIDStr = @(statusID).stringValue;
                        if (!tweetSources) tweetSources = [NSMutableDictionary dictionary];
                        if (!tweetSources[tweetIDStr]) {
                            tweetSources[tweetIDStr] = @"";
                            [TweetSourceHelper fetchSourceForTweetID:tweetIDStr];
                        }
                        
                        if (tweetSources[tweetIDStr] && ![tweetSources[tweetIDStr] isEqualToString:@""]) {
                            NSString *sourceText = tweetSources[tweetIDStr];
                            NSMutableAttributedString *newString = [[NSMutableAttributedString alloc] initWithAttributedString:model.attributedString];
                            
                            // Get existing attributes from the timestamp
                            NSDictionary *existingAttributes = nil;
                            if (newString.length > 0) {
                                existingAttributes = [newString attributesAtIndex:0 effectiveRange:NULL];
                            }
                            
                            // Add separator and source text
                            NSMutableAttributedString *appended = [[NSMutableAttributedString alloc] init];
                            [appended appendAttributedString:[[NSAttributedString alloc] initWithString:@" · " attributes:existingAttributes]];
                            
                            // Use current accent color for source text
                            NSMutableDictionary *sourceAttributes = [existingAttributes mutableCopy];
                            [sourceAttributes setObject:BHTCurrentAccentColor() forKey:NSForegroundColorAttributeName];
                            [appended appendAttributedString:[[NSAttributedString alloc] initWithString:sourceText attributes:sourceAttributes]];
                            
                            [newString appendAttributedString:appended];
                            [model setValue:newString forKey:@"attributedString"];
                        }
                    }
                }
            }
        } @catch (__unused NSException *e) {}
    }
    %orig(model);
}

%end

// --- Initialisation ---
%ctor {
    if (!tweetSources)      tweetSources      = [NSMutableDictionary dictionary];
    if (!viewToTweetID)     viewToTweetID     = [NSMutableDictionary dictionary];
    if (!fetchTimeouts)     fetchTimeouts     = [NSMutableDictionary dictionary];
    if (!viewInstances)     viewInstances     = [NSMutableDictionary dictionary];
    if (!fetchRetries)      fetchRetries      = [NSMutableDictionary dictionary];
    if (!updateRetries)     updateRetries     = [NSMutableDictionary dictionary];
    if (!updateCompleted)   updateCompleted   = [NSMutableDictionary dictionary];
    if (!fetchPending)      fetchPending      = [NSMutableDictionary dictionary];
    if (!cookieCache)       cookieCache       = [NSMutableDictionary dictionary];
    
    // Load cached cookies at initialization
    [TweetSourceHelper loadCachedCookies];
}

// MARK: Bird Icon Theming - Dirty hax for making the Nav Bird Icon themeable again.

%hook UIImageView

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    
    // Check if this is the Twitter bird logo by examining view hierarchy
    UIView *view = self;
    BOOL isNavBar = NO;
    BOOL isCorrectSize = CGSizeEqualToSize(self.frame.size, CGSizeMake(29, 29));
    
    while (view && !isNavBar) {
        if ([view isKindOfClass:%c(TFNNavigationBar)] || 
            [NSStringFromClass([view class]) containsString:@"NavigationBar"]) {
            isNavBar = YES;
            break;
        }
        view = view.superview;
    }
    
    if (isNavBar && isCorrectSize) {
        self.image = [self.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.tintColor = BHTCurrentAccentColor();
    }
}

- (void)setImage:(UIImage *)image {
    if (image && [self.superview isKindOfClass:%c(TFNNavigationBar)]) {
        UIView *view = self;
        BOOL isNavBar = NO;
        BOOL isCorrectSize = CGSizeEqualToSize(self.frame.size, CGSizeMake(29, 29));
        
        while (view && !isNavBar) {
            if ([view isKindOfClass:%c(TFNNavigationBar)] || 
                [NSStringFromClass([view class]) containsString:@"NavigationBar"]) {
                isNavBar = YES;
                break;
            }
            view = view.superview;
        }
        
        if (isNavBar && isCorrectSize) {
            image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            self.tintColor = BHTCurrentAccentColor();
        }
    }
    %orig(image);
}

%end

// MARK: Square Profile Pictures
%hook TUIAvatarImageView
- (id)initWithFrame:(CGRect)frame {
    id orig = %orig;
    [(UIView *)self layer].cornerRadius = 0;
    [(UIView *)self layer].masksToBounds = YES;
    return orig;
}

- (id)initWithCoder:(NSCoder *)coder {
    id orig = %orig;
    [(UIView *)self layer].cornerRadius = 0;
    [(UIView *)self layer].masksToBounds = YES;
    return orig;
}

- (void)setCornerRadius:(double)cornerRadius {
    %orig(0);
}
%end