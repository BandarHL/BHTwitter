#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "SAMKeychain/AuthViewController.h"
#import <objc/message.h> // For objc_msgSend
#import "Colours/Colours.h"
#import "BHTManager.h"
#import <math.h>
#import "BHTBundle/BHTBundle.h"

// Forward declare T1ColorSettings and its private method to satisfy the compiler
@interface T1ColorSettings : NSObject
+ (void)_t1_applyPrimaryColorOption;
+ (void)_t1_updateOverrideUserInterfaceStyle; // Add this line
@end

// Forward declaration for the immersive view controller
@interface T1ImmersiveFullScreenViewController : UIViewController // Assuming base class, adjust if known
- (void)immersiveViewController:(id)immersiveViewController showHideNavigationButtons:(_Bool)showButtons;
@end

// Forward declarations
static void BHT_UpdateAllTabBarIcons(void);
static void BHT_applyThemeToWindow(UIWindow *window);
static void BHT_ensureTheming(void);
static void BHT_forceRefreshAllWindowAppearances(void); // Renamed

// Static reference to the video timestamp label
static __weak UILabel *gVideoTimestampLabel = nil;

// Static helper function for recursive view traversal - DEFINED AT THE TOP
static void BH_EnumerateSubviewsRecursively(UIView *view, void (^block)(UIView *currentView)) {
    if (!view || !block) return;
    block(view);
    for (UIView *subview in view.subviews) {
        BH_EnumerateSubviewsRecursively(subview, block);
    }
}

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
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"dm_avatars"];
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"tab_bar_theming"];
    }
    [BHTManager cleanCache];
    if ([BHTManager FLEX]) {
        [[%c(FLEXManager) sharedManager] showExplorer];
    }
    
    // Apply theme immediately after launch
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        // We will call BH_changeTwitterColor directly in applicationDidBecomeActive
        // and then trigger a more focused UI refresh.
        // The dispatch_async might still be useful for the initial BH_changeTwitterColor if it interacts with UI.
        dispatch_async(dispatch_get_main_queue(), ^ {
            NSInteger selectedOption = [[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"];
            BH_changeTwitterColor(selectedOption);
            if ([%c(T1ColorSettings) respondsToSelector:@selector(_t1_applyPrimaryColorOption)]) {
                [%c(T1ColorSettings) _t1_applyPrimaryColorOption];
            }
            if ([%c(T1ColorSettings) respondsToSelector:@selector(_t1_updateOverrideUserInterfaceStyle)]) {
                [%c(T1ColorSettings) _t1_updateOverrideUserInterfaceStyle];
            }
        });
    }
    
    return true;
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;
    // Apply/Re-apply theme elements on becoming active
    // BH_changeTwitterColor is called on launch. Here, we'll focus on ensuring UI refresh.
    // The new BHT_forceUIRefresh will be called here later.

    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        NSInteger selectedOption = [[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"];
        BH_changeTwitterColor(selectedOption);

        if ([%c(T1ColorSettings) respondsToSelector:@selector(_t1_applyPrimaryColorOption)]) {
            [%c(T1ColorSettings) _t1_applyPrimaryColorOption];
        }
        if ([%c(T1ColorSettings) respondsToSelector:@selector(_t1_updateOverrideUserInterfaceStyle)]) {
            [%c(T1ColorSettings) _t1_updateOverrideUserInterfaceStyle];
        }

        BHT_forceRefreshAllWindowAppearances(); // Call renamed function

        BHT_UpdateAllTabBarIcons();
        // We might need to re-add nav bar bird icon updates here if they are still problematic
    }

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

- (void)setTabBarOpacity:(double)opacity {
    if ([BHTManager stopHidingTabBar]) {
        %orig(1.0);
    } else {
        %orig(opacity);
    }
}

// Combined with stopHidingTabBar
- (void)setTabBarScrolling:(BOOL)scrolling {
    if ([BHTManager stopHidingTabBar]) {
        %orig(NO); // Force scrolling to NO if fading is prevented
    } else {
        %orig(scrolling);
    }
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
    
    // Re-apply theme when this controller appears
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        BHT_ensureTheming();
    }
}
%end

%hook TFNNavigationController
- (void)viewDidAppear:(_Bool)animated {
    %orig(animated);
    
    // Re-apply theme when this controller appears
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        BHT_ensureTheming();
    }
}
%end

%hook T1AppSplitViewController
- (void)viewDidAppear:(_Bool)animated {
    %orig(animated);
    
    // Re-apply theme when this controller appears
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        BHT_ensureTheming();
    }
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
            BOOL isLikelyTwitterLogo = fabs(width - 29.0) < 2.0 && fabs(height - 29.0) < 2.0 && fabs(width - height) < 1.0;
            
            if (isLikelyTwitterLogo) {
                if (shouldTheme && [BHTManager tabBarTheming]) { // Also check if theming is enabled
                    // Get the original image
                    UIImage *originalImage = imageView.image;
                    if (originalImage && originalImage.renderingMode != UIImageRenderingModeAlwaysTemplate) {
                        // Create template image from original
                        UIImage *templateImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                        imageView.image = templateImage; // Setting image might trigger layout, potentially re-calling this. Guard needed?
                        imageView.tintColor = BHTCurrentAccentColor();
                    }
                }
            }
        }
    }
}

// Also hook layoutSubviews to catch changes
- (void)layoutSubviews {
    %orig;
    // Call updateLogoTheme, but perhaps with a guard to prevent infinite loops if setting the image triggers layout.
    // A simple flag or checking if the theme is already applied might work.
    [self updateLogoTheme];
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
+ (void)handleClearCacheNotification:(NSNotification *)notification;
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

+ (void)handleClearCacheNotification:(NSNotification *)notification {
    NSLog(@"TweetSourceTweak: Clearing source label cache via notification.");
    // Invalidate all pending timeout timers
    if (fetchTimeouts) {
        for (NSTimer *timer in [fetchTimeouts allValues]) {
            [timer invalidate];
        }
        [fetchTimeouts removeAllObjects];
    }

    // Clear actual source data and control flags
    if (tweetSources) [tweetSources removeAllObjects];
    if (fetchPending) [fetchPending removeAllObjects];
    if (fetchRetries) [fetchRetries removeAllObjects];
    if (updateRetries) [updateRetries removeAllObjects];
    if (updateCompleted) [updateCompleted removeAllObjects];

    // Force cookie refresh
    if (cookieCache) [cookieCache removeAllObjects];
    lastCookieRefresh = nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"TweetSourceTweak_CookieCache"];
    [defaults removeObjectForKey:@"TweetSourceTweak_LastCookieRefresh"];
    [defaults synchronize];
    
    // Re-initialize essential dictionaries
    if (!tweetSources) tweetSources = [NSMutableDictionary dictionary];
    if (!fetchTimeouts) fetchTimeouts = [NSMutableDictionary dictionary];
    if (!fetchPending) fetchPending = [NSMutableDictionary dictionary];
    if (!fetchRetries) fetchRetries = [NSMutableDictionary dictionary];
    if (!updateRetries) updateRetries = [NSMutableDictionary dictionary];
    if (!updateCompleted) updateCompleted = [NSMutableDictionary dictionary];
    if (!cookieCache) cookieCache = [NSMutableDictionary dictionary];

    // Trigger a poll to potentially refetch for visible items
    // This needs to be done carefully to avoid immediate thundering herd.
    // A short delay might be good.
    [self performSelector:@selector(pollForPendingUpdates) withObject:nil afterDelay:0.5];
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
            UIView  *targetView    = viewValue ? [viewValue nonretainedObjectValue] : nil; // Renamed to targetView for clarity
            if (targetView && targetView == self) { // Ensure we are updating the correct instance
                NSString *currentTweetID = viewToTweetID[@((uintptr_t)targetView)];
                if (currentTweetID && [currentTweetID isEqualToString:tweetID]) {
                    BH_EnumerateSubviewsRecursively(targetView, ^(UIView *subview) { // Use the static helper
                        if ([subview isKindOfClass:%c(TFNAttributedTextView)]) {
                            TFNAttributedTextView *textView = (TFNAttributedTextView *)subview;
                            TFNAttributedTextModel *model = [textView valueForKey:@"_textModel"];
                            if (model && model.attributedString.string) {
                                NSString *text = model.attributedString.string;
                                // Check for typical timestamp patterns or if the source might need to be appended/updated
                                if ([text containsString:@"PM"] || [text containsString:@"AM"] ||
                                    [text rangeOfString:@"\\\\d{1,2}[:.]\\\\d{1,2}" options:NSRegularExpressionSearch].location != NSNotFound) {
                                    
                                    // Check if this specific TFNAttributedTextView is NOT part of a quoted status view
                                    BOOL isSafeToUpdate = YES;
                                    UIView *parentCheck = textView;
                                    while(parentCheck && parentCheck != targetView) { // Traverse up to the main focal view
                                        if ([NSStringFromClass([parentCheck class]) isEqualToString:@"T1QuotedStatusView"]) {
                                            isSafeToUpdate = NO;
                                            break;
                                        }
                                        parentCheck = parentCheck.superview;
                                    }

                                    if (isSafeToUpdate) {
                                        // Force a refresh of the text model.
                                        // This will trigger setTextModel: again, where the source appending logic resides.
                                    [textView setTextModel:nil];
                                    [textView setTextModel:model];
                                }
                            }
                        }
                        }
                    });
                }
            }
        }
    } @catch (NSException *e) {
         NSLog(@"TweetSourceTweak: Exception in handleTweetSourceUpdated for T1ConversationFocalStatusView: %@", e);
    }
}

// %new - (void)enumerateSubviewsRecursively:(void (^)(UIView *))block {
// This method is now replaced by the static C function BH_EnumerateSubviewsRecursively
// }

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Observe for our own update notifications
        [[NSNotificationCenter defaultCenter] addObserver:self // Target is the class itself for class methods
                                                 selector:@selector(handleTweetSourceUpdatedNotificationDispatch:) // A new dispatcher
                                                     name:@"TweetSourceUpdated"
                                                   object:nil];
        [TweetSourceHelper performSelector:@selector(pollForPendingUpdates) withObject:nil afterDelay:3.0];
        [[NSNotificationCenter defaultCenter] addObserver:[TweetSourceHelper class]
                                                 selector:@selector(handleAppForeground:)
                                                     name:UIApplicationDidBecomeActiveNotification // Use the correct constant
                                                   object:nil];
        // Add observer for cache clearing
        [[NSNotificationCenter defaultCenter] addObserver:[TweetSourceHelper class]
                                                 selector:@selector(handleClearCacheNotification:)
                                                     name:@"BHTClearSourceLabelCacheNotification"
                                                   object:nil];
    });
}

// New class method to dispatch instance method calls
%new + (void)handleTweetSourceUpdatedNotificationDispatch:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *tweetID = userInfo[@"tweetID"];
    if (tweetID) {
        NSValue *viewValue = viewInstances[tweetID]; // viewInstances is a global static
        T1ConversationFocalStatusView *targetInstance = viewValue ? [viewValue nonretainedObjectValue] : nil;
        if (targetInstance && [targetInstance isKindOfClass:[self class]]) { // Check if it's an instance of T1ConversationFocalStatusView
            // Use performSelector for %new instance method from %new class method
            if ([targetInstance respondsToSelector:@selector(handleTweetSourceUpdated:)]) {
                [targetInstance performSelector:@selector(handleTweetSourceUpdated:) withObject:notification];
            } else {
                NSLog(@"TweetSourceTweak: ERROR - T1ConversationFocalStatusView instance does not respond to handleTweetSourceUpdated:");
            }
        }
    }
}


%end

%hook TFNAttributedTextView
- (void)setTextModel:(TFNAttributedTextModel *)model {
    if (![BHTManager RestoreTweetLabels] || !model || !model.attributedString) {
        %orig(model);
        return;
    }

    NSString *currentText = model.attributedString.string;
    BOOL isTimestamp = NO;
    BOOL isLikelyTimestampForSourceLabel = NO;
    
    // More specific regex pattern to identify genuine timestamps in the correct format
    NSRegularExpression *timeRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\d{1,2}:\\d{2}(\\s(AM|PM))?\\s·\\s" options:0 error:nil];
    if (timeRegex) {
        NSRange range = [timeRegex rangeOfFirstMatchInString:currentText options:0 range:NSMakeRange(0, currentText.length)];
        if (range.location != NSNotFound) {
            isTimestamp = YES;
            isLikelyTimestampForSourceLabel = YES;
        }
    }

    // Check for date formats like "May 11, 2023 · "
    NSRegularExpression *dateRegex = [NSRegularExpression regularExpressionWithPattern:@"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s\\d{1,2}(,\\s\\d{4})?\\s·\\s" options:0 error:nil];
    if (dateRegex && !isTimestamp) {
        NSRange range = [dateRegex rangeOfFirstMatchInString:currentText options:0 range:NSMakeRange(0, currentText.length)];
        if (range.location != NSNotFound) {
            isTimestamp = YES;
            isLikelyTimestampForSourceLabel = YES;
        }
    }

    // More general check but less certain
    if (!isTimestamp && ([currentText containsString:@"PM"] || [currentText containsString:@"AM"])) {
        isTimestamp = YES;
        // Double check for correct format with dot separator
        if ([currentText containsString:@" · "]) {
            isLikelyTimestampForSourceLabel = YES;
        }
    }

    // Only proceed if we believe this is a proper timestamp header
    if (isTimestamp && isLikelyTimestampForSourceLabel) {
        @try {
            BOOL isInQuotedStatusView = NO;
            id mainTweetObject = nil; // The actual tweet model (e.g., TFNTwitterStatus)

            // Get ancestor hierarchy to determine if this is in a valid location
            UIView *ancestorView = self;
            BOOL isInValidContainer = NO;
            
            while (ancestorView) {
                NSString *className = NSStringFromClass([ancestorView class]);
                
                // Skip source labels in quoted tweets
                if ([className isEqualToString:@"T1QuotedStatusView"]) {
                    isInQuotedStatusView = YES;
                    break;
                }
                
                // Check if this is inside a reply container
                if ([className containsString:@"ReplyView"] || 
                    [className containsString:@"CommentView"] ||
                    [className containsString:@"RepliesTableView"]) {
                    // This is likely a reply timestamp, not the main tweet timestamp
                    isInValidContainer = NO;
                    break;
                }
                
                // These are the main valid containers for tweet headers
                if ([className containsString:@"TweetDetailsFocalStatusView"] ||
                    [className containsString:@"ConversationFocalStatusView"] ||
                    [className containsString:@"T1StandardStatusView"] ||
                    [className containsString:@"StatusHeaderView"]) {
                    isInValidContainer = YES;
                    break;
                }
                
                ancestorView = ancestorView.superview;
            }
            
            // Exit if this is not in a valid container or is in a quoted tweet
            if (isInQuotedStatusView || !isInValidContainer) {
                %orig(model);
                return;
            }

            // Continue with existing code to find mainTweetObject...
            ancestorView = self;
            while (ancestorView) {
                if ([NSStringFromClass([ancestorView class]) isEqualToString:@"T1QuotedStatusView"]) {
                    isInQuotedStatusView = YES;
                    break; 
                }
                // Check if this ancestor is the main tweet container and can provide the tweet model
                // T1ConversationFocalStatusView, T1TweetDetailsFocalStatusView often hold the primary view model
                if ([NSStringFromClass([ancestorView class]) containsString:@"ConversationFocalStatusView"] ||
                    [NSStringFromClass([ancestorView class]) containsString:@"TweetDetailsFocalStatusView"] ||
                    [NSStringFromClass([ancestorView class]) isEqualToString:@"T1StandardStatusView"]) { // Also check T1StandardStatusView which might be the top-level in some contexts
                    
                    id hostViewModel = nil;
                    if ([ancestorView respondsToSelector:@selector(viewModel)]) {
                         hostViewModel = [ancestorView performSelector:@selector(viewModel)];
                    } else if ([ancestorView respondsToSelector:@selector(statusViewModel)]) { // Some views use statusViewModel
                         hostViewModel = [ancestorView performSelector:@selector(statusViewModel)];
                            }
                            
                    if ([hostViewModel respondsToSelector:@selector(tweet)]) {
                        mainTweetObject = [hostViewModel performSelector:@selector(tweet)];
                    } else if ([hostViewModel respondsToSelector:@selector(status)]) { // Some view models have a 'status' property
                         mainTweetObject = [hostViewModel performSelector:@selector(status)];
            }
            
                    if (mainTweetObject) {
                        break;
                    }
                }
                ancestorView = ancestorView.superview;
            }

            if (isInQuotedStatusView) {
                %orig(model);
                return;
            }

            if (mainTweetObject) {
                NSString *tweetIDStr = nil;
                    @try {
                    id statusIDVal = [mainTweetObject valueForKey:@"statusID"];
                    if (statusIDVal && [statusIDVal respondsToSelector:@selector(longLongValue)] && [statusIDVal longLongValue] > 0) {
                        tweetIDStr = [statusIDVal stringValue];
                    }
                } @catch (NSException *e) { NSLog(@"TweetSourceTweak: Exception getting statusID: %@", e); }
                            
                if (!tweetIDStr || tweetIDStr.length == 0) {
                    @try {
                        tweetIDStr = [mainTweetObject valueForKey:@"rest_id"];
                        if (!tweetIDStr || tweetIDStr.length == 0) {
                             tweetIDStr = [mainTweetObject valueForKey:@"id_str"];
                                }
                        if (!tweetIDStr || tweetIDStr.length == 0) {
                            id genericID = [mainTweetObject valueForKey:@"id"];
                            if (genericID) tweetIDStr = [genericID description];
                            }
                    } @catch (NSException *e) { NSLog(@"TweetSourceTweak: Exception getting alt tweet ID: %@", e); }
                    }
                    
                if (tweetIDStr && tweetIDStr.length > 0) {
                        if (!tweetSources) tweetSources = [NSMutableDictionary dictionary];
                        if (!tweetSources[tweetIDStr]) {
                        tweetSources[tweetIDStr] = @""; // Placeholder
                            [TweetSourceHelper fetchSourceForTweetID:tweetIDStr];
                        }
                        
                            NSString *sourceText = tweetSources[tweetIDStr];
                    if (sourceText && sourceText.length > 0 && ![sourceText isEqualToString:@"Source Unavailable"] && ![sourceText isEqualToString:@""]) {
                        NSString *separator = @" · ";
                        NSString *fullSourceStringWithSeparator = [separator stringByAppendingString:sourceText];
                            
                        // Check if the source string (with separator) is already part of the current text
                        if ([model.attributedString.string rangeOfString:fullSourceStringWithSeparator].location == NSNotFound) {
                            NSMutableAttributedString *newString = [[NSMutableAttributedString alloc] initWithAttributedString:model.attributedString];
                            NSString *originalContentForRegex = newString.string;

                            // Remove " · X Views" before appending source label
                            NSRegularExpression *viewCountRegex = [NSRegularExpression regularExpressionWithPattern:@"\\s·\\s*\\d{1,3}(?:,\\d{3})*(?:\\.\\d+)?[KMGT]?\\s*View(s)?"
                                                                                                           options:NSRegularExpressionCaseInsensitive
                                                                                                             error:nil];
                            if (viewCountRegex) {
                                NSArray<NSTextCheckingResult *> *matches = [viewCountRegex matchesInString:originalContentForRegex
                                                                                                  options:0
                                                                                                    range:NSMakeRange(0, originalContentForRegex.length)];
                                if (matches.count > 0) {
                                    NSTextCheckingResult *lastMatch = [matches lastObject];
                                    [newString replaceCharactersInRange:lastMatch.range withString:@""];
                                }
                            }
                            
                            NSDictionary *baseAttributes;
                            if (model.attributedString.length > 0) {
                                 baseAttributes = [model.attributedString attributesAtIndex:0 effectiveRange:NULL];
                            } else {
                                 baseAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:12], NSForegroundColorAttributeName: [UIColor grayColor]};
                            }
                            
                            NSMutableAttributedString *sourceSuffix = [[NSMutableAttributedString alloc] init];
                            [sourceSuffix appendAttributedString:[[NSAttributedString alloc] initWithString:separator attributes:baseAttributes]];
                            
                            NSMutableDictionary *sourceAttributes = [baseAttributes mutableCopy];
                            [sourceAttributes setObject:BHTCurrentAccentColor() forKey:NSForegroundColorAttributeName];
                            [sourceSuffix appendAttributedString:[[NSAttributedString alloc] initWithString:sourceText attributes:sourceAttributes]];
                            
                            [newString appendAttributedString:sourceSuffix];
                           
                            // Use standard initializer and set activeRanges via KVC if available
                            TFNAttributedTextModel *newModel = [[%c(TFNAttributedTextModel) alloc] initWithAttributedString:newString];
                            @try {
                                id originalActiveRanges = [model valueForKey:@"activeRanges"];
                                if (originalActiveRanges) {
                                    [newModel setValue:originalActiveRanges forKey:@"activeRanges"];
            }
                            } @catch (NSException *exception) {
                                NSLog(@"TweetSourceTweak: Could not get/set activeRanges via KVC: %@", exception);
                            }
                            %orig(newModel);
                            return;
                        }
                    }
                }
            }
        } @catch (NSException *e) {
             NSLog(@"TweetSourceTweak: Exception in TFNAttributedTextView -setTextModel: %@", e);
        }
    } else if ([currentText containsString:@"your post"] || 
             [currentText containsString:@"your Post"] ||
             [currentText containsString:@"reposted"] ||
             [currentText containsString:@"Reposted"]) {
        @try {
            UIView *view = self;
            BOOL isNotificationView = NO;
            
            // Walk up the view hierarchy to find notification context
            while (view && !isNotificationView) {
                if ([NSStringFromClass([view class]) containsString:@"Notification"] ||
                    [NSStringFromClass([view class]) containsString:@"T1NotificationsTimeline"]) {
                    isNotificationView = YES;
                    break; // Exit loop once found
                }
                view = view.superview;
            }
            
            // Only proceed if we're in a notification view
            if (isNotificationView) {
                NSMutableAttributedString *newString = [[NSMutableAttributedString alloc] initWithAttributedString:model.attributedString];
                BOOL modified = NO;
                
                // Replace "your post" with "your Tweet"
                NSRange postRange = [currentText rangeOfString:@"your post"];
                if (postRange.location != NSNotFound) {
                    NSDictionary *existingAttributes = [newString attributesAtIndex:postRange.location effectiveRange:NULL];
                    [newString replaceCharactersInRange:postRange withString:@"your Tweet"];
                    [newString setAttributes:existingAttributes range:NSMakeRange(postRange.location, [@"your Tweet" length])];
                    modified = YES;
                }
                
                // Also check for capitalized "Post"
                postRange = [currentText rangeOfString:@"your Post"];
                if (postRange.location != NSNotFound) {
                    NSDictionary *existingAttributes = [newString attributesAtIndex:postRange.location effectiveRange:NULL];
                    [newString replaceCharactersInRange:postRange withString:@"your Tweet"];
                    [newString setAttributes:existingAttributes range:NSMakeRange(postRange.location, [@"your Tweet" length])];
                    modified = YES;
                }
                
                // Replace "reposted" with "Retweeted"
                NSRange repostRange = [currentText rangeOfString:@"reposted"];
                if (repostRange.location != NSNotFound) {
                    NSDictionary *existingAttributes = [newString attributesAtIndex:repostRange.location effectiveRange:NULL];
                    [newString replaceCharactersInRange:repostRange withString:@"Retweeted"];
                    [newString setAttributes:existingAttributes range:NSMakeRange(repostRange.location, [@"Retweeted" length])];
                    modified = YES;
                }
                
                // Also check for capitalized "Reposted"
                repostRange = [currentText rangeOfString:@"Reposted"];
                if (repostRange.location != NSNotFound) {
                    NSDictionary *existingAttributes = [newString attributesAtIndex:repostRange.location effectiveRange:NULL];
                    [newString replaceCharactersInRange:repostRange withString:@"Retweeted"];
                    [newString setAttributes:existingAttributes range:NSMakeRange(repostRange.location, [@"Retweeted" length])];
                    modified = YES;
                }
                
                // Update the model only if modifications were made
                if (modified) {
                    // Create a new model instance with the modified attributed string
                    // and attempt to preserve active ranges if possible
                    TFNAttributedTextModel *newModel = [[%c(TFNAttributedTextModel) alloc] initWithAttributedString:newString];
                     @try {
                        id originalActiveRanges = [model valueForKey:@"activeRanges"];
                        if (originalActiveRanges) {
                            [newModel setValue:originalActiveRanges forKey:@"activeRanges"];
                         }
                    } @catch (NSException *exception) {
                        NSLog(@"TweetSourceTweak: Could not preserve activeRanges for post/repost replacement: %@", exception);
                    }
                    %orig(newModel);
                    return; // Important: return here to avoid calling %orig again at the end
                }
            }
        } @catch (__unused NSException *e) {}
    }
    
    %orig(model);
}
%end

// --- Initialisation ---

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

// MARK: Replace "your post" with "your tweet" in notifications
%hook TFNAttributedTextModel
- (NSAttributedString *)attributedString {
    NSAttributedString *original = %orig;
    if (!original) return original;
    
    NSString *originalString = original.string;
    if ([originalString containsString:@"your post"]) {
        // Check if we're in a notification context by looking at the view hierarchy
        UIViewController *topVC = topMostController();
        if ([NSStringFromClass([topVC class]) containsString:@"Notification"] ||
            [NSStringFromClass([topVC class]) containsString:@"T1NotificationsTimeline"]) {
            
            NSMutableAttributedString *modified = [[NSMutableAttributedString alloc] initWithAttributedString:original];
            NSRange range = [originalString rangeOfString:@"your post"];
            if (range.location != NSNotFound) {
                [modified replaceCharactersInRange:range withString:@"your tweet"];
                // Preserve the original attributes
                NSDictionary *attributes = [original attributesAtIndex:range.location effectiveRange:NULL];
                [modified setAttributes:attributes range:NSMakeRange(range.location, [@"your tweet" length])];
                return modified;
            }
        }
    }
    
    return original;
}
%end

// MARK: - Hide Grok Analyze Button (TTAStatusAuthorView)

@interface TTAStatusAuthorView : UIView
- (id)grokAnalyzeButton;
@end

%hook TTAStatusAuthorView

- (id)grokAnalyzeButton {
    UIView *button = %orig;
    if (button && [BHTManager hideGrokAnalyze]) {
        button.hidden = YES;
    }
    return button;
}

%end

// MARK: - Hide Grok Analyze & Subscribe Buttons on Detail View (UIControl)

// Minimal interface for TFNButton, used by UIControl hook and FollowButton logic
@class TFNButton;

%hook UIControl
// Grok Analyze and Subscribe button
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents {
    if (action == @selector(didTapGrokAnalyze)) {
        if ([self isKindOfClass:NSClassFromString(@"TFNButton")] && [BHTManager hideGrokAnalyze]) {
            self.hidden = YES;
        }
    } else if (action == @selector(_didTapSubscribe)) {
        if ([self isKindOfClass:NSClassFromString(@"TFNButton")] && [BHTManager restoreFollowButton]) {
            self.alpha = 0.0;
            self.userInteractionEnabled = NO;
        }
    }
    %orig(target, action, controlEvents);
}

%end

// MARK: - Hide Follow Button (T1ConversationFocalStatusView)

// Minimal interface for T1ConversationFocalStatusView
@class T1ConversationFocalStatusView;

// Helper function to recursively find and hide a TFNButton by accessibilityIdentifier
static BOOL findAndHideButtonWithAccessibilityId(UIView *viewToSearch, NSString *targetAccessibilityId) {
    if ([viewToSearch isKindOfClass:NSClassFromString(@"TFNButton")]) {
        TFNButton *button = (TFNButton *)viewToSearch;
        if ([button.accessibilityIdentifier isEqualToString:targetAccessibilityId]) {
            button.hidden = YES;
            return YES;
        }
    }
    for (UIView *subview in viewToSearch.subviews) {
        if (findAndHideButtonWithAccessibilityId(subview, targetAccessibilityId)) {
            return YES;
        }
    }
    return NO;
}

%hook T1ConversationFocalStatusView

- (void)didMoveToWindow {
    %orig;
    if ([BHTManager hideFollowButton]) {
        findAndHideButtonWithAccessibilityId(self, @"FollowButton");
    }
}

%end

// MARK: - Restore Follow Button (TUIFollowControl) & Hide SuperFollow (T1SuperFollowControl)

@interface TUIFollowControl : UIControl
- (void)setVariant:(NSUInteger)variant;
- (NSUInteger)variant; // Ensure getter is declared
@end

%hook TUIFollowControl

- (void)setVariant:(NSUInteger)variant {
    if ([BHTManager restoreFollowButton]) {
        NSUInteger subscribeVariantID = 1;
        NSUInteger desiredFollowVariantID = 32;
        if (variant == subscribeVariantID) {
            %orig(desiredFollowVariantID);
        } else {
            %orig(variant);
        }
    } else {
        %orig;
    }
}

// This hook makes the control ALWAYS REPORT its variant as 32
- (NSUInteger)variant {
    if ([BHTManager restoreFollowButton]) {
        // This makes the control ALWAYS REPORT its variant as 32
        // to influence layout decisions that might cause the ellipsis issue.
        return 32;
    }
    return %orig;
}

%end

// Forward declare T1SuperFollowControl if its interface is not fully defined yet
@class T1SuperFollowControl;

// Helper function to recursively find and hide T1SuperFollowControl instances
static void findAndHideSuperFollowControl(UIView *viewToSearch) {
    if ([viewToSearch isKindOfClass:NSClassFromString(@"T1SuperFollowControl")]) {
        viewToSearch.hidden = YES;
        viewToSearch.alpha = 0.0;
    }
    for (UIView *subview in viewToSearch.subviews) {
        findAndHideSuperFollowControl(subview);
    }
}

@class T1ProfileHeaderViewController; // Forward declaration instead of interface definition

// It's good practice to also declare the class we are looking for, even if just minimally
@interface T1SuperFollowControl : UIView
@end

// Add global class pointer for T1ProfileHeaderViewController
static Class gT1ProfileHeaderViewControllerClass = nil;
// Add global class pointers for Dash specific views
static Class gDashAvatarImageViewClass = nil;
static Class gDashDrawerAvatarImageViewClass = nil; 
static Class gDashHostingControllerClass = nil;
static Class gGuideContainerVCClass = nil;
static Class gTombstoneCellClass = nil;
static Class gExploreHeroCellClass = nil;

// Helper function to find the UIViewController managing a UIView
static UIViewController* getViewControllerForView(UIView *view) {
    UIResponder *responder = view;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        // Stop if we reach top-level objects like UIWindow or UIApplication without finding a VC
        if ([responder isKindOfClass:[UIWindow class]] || [responder isKindOfClass:[UIApplication class]]) {
            break;
        }
    }
    return nil;
}

// Helper function to check if a view is inside T1ProfileHeaderViewController
static BOOL isViewInsideT1ProfileHeaderViewController(UIView *view) {
    if (!gT1ProfileHeaderViewControllerClass) {
        return NO; 
    }
    UIViewController *vc = getViewControllerForView(view);
    if (!vc) return NO;

    UIViewController *parent = vc; // Start with the direct VC
    while (parent) {
        if ([parent isKindOfClass:gT1ProfileHeaderViewControllerClass]) return YES;
        parent = parent.parentViewController;
    }
    UIViewController *presenting = vc.presentingViewController; // Check presenting chain from direct VC
    while(presenting){
        if([presenting isKindOfClass:gT1ProfileHeaderViewControllerClass]) return YES;
        if(presenting.presentingViewController){
            // Check containers in the presenting chain
            if([presenting isKindOfClass:[UINavigationController class]]){
                UINavigationController *nav = (UINavigationController*)presenting;
                for(UIViewController *childVc in nav.viewControllers){
                    if([childVc isKindOfClass:gT1ProfileHeaderViewControllerClass]) return YES;
                }
            }
            presenting = presenting.presentingViewController;
        } else {
            // Final check on the root of the presenting chain for container
            if([presenting isKindOfClass:[UINavigationController class]]){
                 UINavigationController *nav = (UINavigationController*)presenting;
                 for(UIViewController *childVc in nav.viewControllers){
                     if([childVc isKindOfClass:gT1ProfileHeaderViewControllerClass]) return YES;
                 }
            }
            break; 
        }
    }
    return NO;
}

// Helper function to check if a view is inside the Dash Hosting Controller
static BOOL isViewInsideDashHostingController(UIView *view) {
    if (!gDashHostingControllerClass) {
        return NO;
    }
    UIViewController *vc = getViewControllerForView(view);
    if (!vc) return NO;

    UIViewController *parent = vc; // Start with the direct VC
    while (parent) {
        if ([parent isKindOfClass:gDashHostingControllerClass]) return YES;
        parent = parent.parentViewController;
    }
    UIViewController *presenting = vc.presentingViewController; // Check presenting chain from direct VC
    while(presenting){
        if([presenting isKindOfClass:gDashHostingControllerClass]) return YES;
        if(presenting.presentingViewController){
            // Check containers in the presenting chain
            if([presenting isKindOfClass:[UINavigationController class]]){
                UINavigationController *nav = (UINavigationController*)presenting;
                for(UIViewController *childVc in nav.viewControllers){
                    if([childVc isKindOfClass:gDashHostingControllerClass]) return YES;
                }
            }
            presenting = presenting.presentingViewController;
        } else {
             // Final check on the root of the presenting chain for container
             if([presenting isKindOfClass:[UINavigationController class]]){
                 UINavigationController *nav = (UINavigationController*)presenting;
                 for(UIViewController *childVc in nav.viewControllers){
                     if([childVc isKindOfClass:gDashHostingControllerClass]) return YES;
                 }
            }
            break; 
        }
    }
    return NO;
}

%hook T1ProfileHeaderViewController

- (void)viewDidLayoutSubviews { // Or viewWillAppear:, depending on when controls are added
    %orig;
    // Search for and hide T1SuperFollowControl within this view controller's view
    if ([BHTManager restoreFollowButton] && self.isViewLoaded) { // Ensure the view is loaded
        findAndHideSuperFollowControl(self.view);
    }
}

%end

// MARK: - Timestamp Label Styling via UILabel -setText:

%hook UILabel

- (void)setText:(NSString *)text {
    %orig(text);

    // Check if this label is the one we want to modify (e.g., video timestamp)
    if ([BHTManager restoreVideoTimestamp] && self.text && [self.text containsString:@":"] && [self.text containsString:@"/"]) {
        self.font = [UIFont systemFontOfSize:14.0];
        self.textColor = [UIColor whiteColor]; // White text for contrast
        self.textAlignment = NSTextAlignmentCenter; // Center text in the pill

        // Calculate size based on current text and font
        [self sizeToFit];
        CGRect currentFrame = self.frame;

        // Define padding
        CGFloat horizontalPadding = 16.0; // e.g., 8px on each side
        CGFloat verticalPadding = 8.0;   // e.g., 4px on top/bottom

        // Apply padding to the frame
        // Adjust origin to keep the label centered around its original position after resizing
        self.frame = CGRectMake(
            currentFrame.origin.x - horizontalPadding / 2.0f,
            currentFrame.origin.y - verticalPadding / 2.0f,
            currentFrame.size.width + horizontalPadding,
            currentFrame.size.height + verticalPadding
        );
        
        // Ensure a minimum height for very short text (e.g., "0:01/0:05") for a good pill shape
        if (self.frame.size.height < 22.0f) {
            CGFloat diff = 22.0f - self.frame.size.height;
            CGRect frame = self.frame;
            frame.size.height = 22.0f;
            frame.origin.y -= diff / 2.0f; // Keep it vertically centered
            self.frame = frame;
        }
        
        // Pill styling
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5]; // Dark semi-transparent
        self.layer.cornerRadius = self.frame.size.height / 2.0f;
        self.layer.masksToBounds = YES;
        
        // Set initial alpha to 0 for fade-in animation by the other hook
        // Only set to 0 if it's not already visible (e.g. if controls are already shown when text is set)
        if (self.alpha != 1.0) { // Avoid making it flicker if it was already visible
            self.alpha = 0.0;
        }


        // Store a weak reference to this label
        gVideoTimestampLabel = self;

        // Remove the old fallback frame logic as the new sizing should be more robust
        // if (CGRectGetWidth(self.frame) < 10 || CGRectGetHeight(self.frame) < 5) { ... }
    }
}

%end

// MARK: - Immersive Player Timestamp Visibility Control

%hook T1ImmersiveFullScreenViewController

- (void)immersiveViewController:(id)immersiveViewController showHideNavigationButtons:(_Bool)showButtons {
    %orig(immersiveViewController, showButtons);

    if ([BHTManager restoreVideoTimestamp]) {
        UILabel *timestampLabelToUpdate = nil;

        if (gVideoTimestampLabel && gVideoTimestampLabel.superview) {
            timestampLabelToUpdate = gVideoTimestampLabel;
        } else {
            UIView *searchView = self.view;
            if (immersiveViewController && [immersiveViewController respondsToSelector:@selector(view)]) {
                searchView = [immersiveViewController view];
            }
            NSMutableArray<UILabel *> *foundLabels = [NSMutableArray array];
            BH_EnumerateSubviewsRecursively(searchView, ^(UIView *currentView) {
                if ([currentView isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)currentView;
                    if (label.text && [label.text containsString:@":"] && [label.text containsString:@"/"]) {
                        [foundLabels addObject:label];
                    }
                }
            });
            if ([foundLabels containsObject:gVideoTimestampLabel]) {
                 timestampLabelToUpdate = gVideoTimestampLabel;
            } else if (foundLabels.count > 0) {
                timestampLabelToUpdate = foundLabels.firstObject;
                 gVideoTimestampLabel = timestampLabelToUpdate; 
            }
        }
        
        if (timestampLabelToUpdate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CGFloat targetAlpha = showButtons ? 1.0 : 0.0;
                NSTimeInterval animationDuration = 0.25; // Standard animation duration

                if (showButtons && timestampLabelToUpdate.hidden) {
                    // If we are showing, ensure it's unhidden before animation starts
                    // and its alpha might be 0 from a previous fade out or initial setup.
                    timestampLabelToUpdate.alpha = 0.0; // Start from alpha 0 for fade-in
                    timestampLabelToUpdate.hidden = NO;
                } else if (!showButtons && timestampLabelToUpdate.alpha == 0.0) {
                    // If already faded out and we want to hide, just ensure it's hidden and return.
                    timestampLabelToUpdate.hidden = YES;
                    return;
                }


                [UIView animateWithDuration:animationDuration
                                      delay:0.0
                                    options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                                 animations:^{
                                     timestampLabelToUpdate.alpha = targetAlpha;
                                 }
                                 completion:^(BOOL finished) {
                                     if (finished && !showButtons) {
                                         timestampLabelToUpdate.hidden = YES;
                                     }
                                 }];
            });
        }
    }
}

%end

// MARK: - Square Avatars (TFNAvatarImageView)

@interface TFNAvatarImageView : UIView // Assuming it's a UIView subclass, adjust if necessary
- (void)setStyle:(NSInteger)style;
- (NSInteger)style;
@end

%hook TFNAvatarImageView

- (void)setStyle:(NSInteger)style {
    if ([BHTManager squareAvatars]) {
        CGFloat activeCornerRadius;
        NSString *selfClassName = NSStringFromClass([self class]); // Get class name as string

        BOOL isDashAvatar = [selfClassName isEqualToString:@"TwitterDash.DashAvatarImageView"];
        BOOL isDashDrawerAvatar = [selfClassName isEqualToString:@"TwitterDash.DashDrawerAvatarImageView"];
        
        BOOL inDashHostingContext = isViewInsideDashHostingController(self);

        if (isDashDrawerAvatar) {
            // DashDrawerAvatarImageView always gets 8.0f regardless of context
            activeCornerRadius = 8.0f;
        } else if (isDashAvatar && inDashHostingContext) {
            // Regular DashAvatarImageView in hosting context gets 8.0f
            activeCornerRadius = 8.0f;
        } else if (isViewInsideT1ProfileHeaderViewController(self)) {
            // Avatars in profile header get 8.0f
            activeCornerRadius = 8.0f;
        } else {
            // Default for all other avatars is 12.0f
            activeCornerRadius = 12.0f;
        }

        %orig(3); // Call original with forced style 3

        // Force slightly rounded square on the main TFNAvatarImageView layer
        self.layer.cornerRadius = activeCornerRadius; 
        self.layer.masksToBounds = YES; // Ensure the main view clips

        // Find TIPImageViewObserver and force it to be slightly rounded
        for (NSUInteger i = 0; i < self.subviews.count; i++) {
            UIView *subview = [self.subviews objectAtIndex:i];
            NSString *subviewClassString = NSStringFromClass([subview class]);
            if ([subviewClassString isEqualToString:@"TIPImageViewObserver"]) {
                subview.layer.cornerRadius = activeCornerRadius;
                subview.layer.mask = nil;
                subview.clipsToBounds = YES;        // View property
                subview.layer.masksToBounds = YES;  // Layer property
                subview.contentMode = UIViewContentModeScaleAspectFill; // Set contentMode

                // Check for subviews of TIPImageViewObserver
                if (subview.subviews.count > 0) {
                    for (NSUInteger j = 0; j < subview.subviews.count; j++) {
                        UIView *tipSubview = [subview.subviews objectAtIndex:j];
                        tipSubview.layer.cornerRadius = activeCornerRadius;
                        tipSubview.layer.mask = nil;
                        tipSubview.clipsToBounds = YES;
                        tipSubview.layer.masksToBounds = YES;
                        tipSubview.contentMode = UIViewContentModeScaleAspectFill; // Set contentMode
                    }
                }
                break; // Assuming only one TIPImageViewObserver, exit loop
            }
        }
    } else {
        %orig;
    }
}

- (NSInteger)style {
    if ([BHTManager squareAvatars]) {
        return 3;
    }
    return %orig;
}

%end

// --- UIImage Hook Implementation ---
%hook UIImage

// Hook the specific TFN rounding method
- (UIImage *)tfn_roundImageWithTargetDimensions:(CGSize)targetDimensions targetContentMode:(UIViewContentMode)targetContentMode {
    if ([BHTManager squareAvatars]) {
        if (targetDimensions.width <= 0 || targetDimensions.height <= 0) {
            return self; // Avoid issues with zero/negative size
        }

        CGFloat cornerRadius = 12.0f;
        CGRect imageRect = CGRectMake(0, 0, targetDimensions.width, targetDimensions.height);

        // Ensure cornerRadius is not too large for the dimensions
        CGFloat minSide = MIN(targetDimensions.width, targetDimensions.height);
        if (cornerRadius > minSide / 2.0f) {
            cornerRadius = minSide / 2.0f; // Cap radius to avoid weird shapes
        }
        
        UIGraphicsBeginImageContextWithOptions(targetDimensions, NO, self.scale); // Use self.scale for retina, NO for opaque if image has alpha
        if (!UIGraphicsGetCurrentContext()) {
            UIGraphicsEndImageContext(); // Defensive call
            return self;
        }
        
        [[UIBezierPath bezierPathWithRoundedRect:imageRect cornerRadius:cornerRadius] addClip];
        [self drawInRect:imageRect];
        
        UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (roundedImage) {
            return roundedImage;
        } else {
            return self; // Fallback to original image if rounding fails
        }
    } else {
        return %orig;
    }
}

%end

// --- TFNCircularAvatarShadowLayer Hook Implementation ---
%hook TFNCircularAvatarShadowLayer

- (void)setHidden:(BOOL)hidden {
    if ([BHTManager squareAvatars]) {
        %orig(YES); // Always hide this layer when square avatars are enabled
    } else {
        %orig;
    }
}

%end


// MARK: - Combined constructor to initialize all hooks and features
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
    
    // Initialize global Class pointers here when the tweak loads
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gGuideContainerVCClass = NSClassFromString(@"T1TwitterSwift.GuideContainerViewController");
        if (!gGuideContainerVCClass) gGuideContainerVCClass = NSClassFromString(@"T1TwitterSwift_GuideContainerViewController");

        gTombstoneCellClass = NSClassFromString(@"T1TwitterSwift.ConversationTombstoneCell");
        if (!gTombstoneCellClass) gTombstoneCellClass = NSClassFromString(@"T1TwitterSwift_ConversationTombstoneCell");

        gExploreHeroCellClass = NSClassFromString(@"T1ExploreEventSummaryHeroTableViewCell");
        
        // Initialize T1ProfileHeaderViewController class pointer
        gT1ProfileHeaderViewControllerClass = NSClassFromString(@"T1ProfileHeaderViewController");
        
        // Initialize Dash specific class pointers
        gDashAvatarImageViewClass = NSClassFromString(@"TwitterDash.DashAvatarImageView");
        gDashDrawerAvatarImageViewClass = NSClassFromString(@"TwitterDash.DashDrawerAvatarImageView");
        
        // The full name for the hosting controller is very long and specific.
        gDashHostingControllerClass = NSClassFromString(@"_TtGC7SwiftUI19UIHostingControllerGV10TFNUISwift22HostingEnvironmentViewV11TwitterDash18DashNavigationView__");
    });
    
    // Initialize dictionaries for Tweet Source Labels restoration
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
    
    %init;
    [[NSNotificationCenter defaultCenter] addObserverForName:@"BHTTabBarThemingChanged" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        BHT_UpdateAllTabBarIcons();
    }];
    
    // Add observers for both window and theme changes
    [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeKeyNotification 
                                                    object:nil 
                                                     queue:[NSOperationQueue mainQueue] 
                                                usingBlock:^(NSNotification * _Nonnull note) {
        UIWindow *window = note.object;
        if (window && [[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
            BHT_applyThemeToWindow(window);
        }
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                    object:nil 
                                                     queue:[NSOperationQueue mainQueue] 
                                                usingBlock:^(NSNotification * _Nonnull note) {
        BHT_ensureTheming();
    }];
    
    // Observe theme changes
    [[NSNotificationCenter defaultCenter] addObserverForName:@"BHTTabBarThemingChanged" 
                                                    object:nil 
                                                     queue:[NSOperationQueue mainQueue] 
                                                usingBlock:^(NSNotification * _Nonnull note) {
        BHT_ensureTheming();
    }];
}

// MARK: - DM Avatar Images
%hook T1DirectMessageEntryViewModel
- (BOOL)shouldShowAvatarImage {
    if (![BHTManager dmAvatars]) {
        return %orig;
    }
    
    if (self.isOutgoingMessage) {
        return NO; // Don't show avatar for your own messages
    }
    // For incoming messages, only show avatar if it's the last message in a group from that sender
    return [[self valueForKey:@"lastEntryInGroup"] boolValue];
}

- (BOOL)isAvatarImageEnabled {
    if (![BHTManager dmAvatars]) {
        return %orig;
    }
    
    // Always return YES so that space is allocated for the avatar,
    // allowing shouldShowAvatarImage to control actual visibility.
    return YES;
}
%end

// MARK: - Tab Bar Icon Theming
%hook T1TabView

%new
- (void)bh_applyCurrentThemeToIcon {
    // Only apply theming if the setting is ON.
    // If OFF, do nothing, and default colors will apply after app restart.
    if (![BHTManager tabBarTheming]) {
        return; 
    }
    
    UIColor *targetColor;
    if ([[self valueForKey:@"selected"] boolValue]) { 
        targetColor = BHTCurrentAccentColor();
    } else {
        targetColor = [UIColor grayColor]; // Unselected but themed icon
    }

    UIImageView *imgView = nil;
    @try {
        imgView = [self valueForKey:@"imageView"];
    } @catch (NSException *exception) {
        NSLog(@"[BHTwitter TabTheme] Exception getting imageView: %@", exception);
        return;
    }
    if (!imgView) {
        NSLog(@"[BHTwitter TabTheme] imageView is nil.");
        return;
    }
    if (imgView.image && imgView.image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
        imgView.image = [imgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    SEL applyTintColorSelector = @selector(applyTintColor:);
    if ([self respondsToSelector:applyTintColorSelector]) {
        // Use objc_msgSend to avoid performSelector warnings and be more explicit.
        // Assumes applyTintColor: returns void and takes a UIColor*.
        ((void (*)(id, SEL, UIColor *))objc_msgSend)(self, applyTintColorSelector, targetColor);
    } else {
        imgView.tintColor = targetColor;
    }
    SEL updateImageViewSelector = NSSelectorFromString(@"_t1_updateImageViewAnimated:");
    if ([self respondsToSelector:updateImageViewSelector]) {
        IMP imp = [self methodForSelector:updateImageViewSelector];
        void (*func)(id, SEL, _Bool) = (void *)imp;
        func(self, updateImageViewSelector, NO);
    } else if (imgView) {
        [imgView setNeedsDisplay];
    }
}

- (void)setSelected:(_Bool)selected {
    %orig(selected);
    // Call the new method using performSelector to ensure it's found at runtime
    [self performSelector:@selector(bh_applyCurrentThemeToIcon)];
}

/* Potential alternative or supplementary hook if setSelected: alone isn't enough:
- (void)_t1_updateImageViewAnimated:(_Bool)animated {
    %orig(animated);
    // We'd call bh_applyCurrentThemeToIcon here too, or replicate its logic if context differs.
    [self bh_applyCurrentThemeToIcon]; 
}
*/

%end

%hook T1TabBarViewController

// + (void)load { // REMOVED
    // Initialize the hash table once
    // static dispatch_once_t onceToken;
    // dispatch_once(&onceToken, ^{
        // gTabBarControllers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
        // [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification 
                                                          // object:nil 
                                                           // queue:[NSOperationQueue mainQueue] 
                                                      // usingBlock:^(NSNotification * _Nonnull note) {
            // BHTTabBarAccentColorChanged(NULL, NULL, NULL, NULL, NULL); 
        // }];
    // });
// }

- (void)viewDidLoad {
    %orig;
    // if (gTabBarControllers) { // REMOVED
        // [gTabBarControllers addObject:self]; // REMOVED
    // }
    // Apply theme on initial load
    if ([self respondsToSelector:@selector(tabViews)]) {
        NSArray *tabViews = [self valueForKey:@"tabViews"];
        for (id tabView in tabViews) {
            if ([tabView respondsToSelector:@selector(bh_applyCurrentThemeToIcon)]) {
                [tabView performSelector:@selector(bh_applyCurrentThemeToIcon)];
            }
        }
    }
}

- (void)dealloc {
    // if (gTabBarControllers) { // REMOVED
        // [gTabBarControllers removeObject:self]; // REMOVED
    // }
    %orig;
}

%end

// Helper: Update all tab bar icons
static void BHT_UpdateAllTabBarIcons(void) {
    // Iterate all windows and view controllers to find T1TabBarViewController
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        UIViewController *root = window.rootViewController;
        if (!root) continue;
        NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
        while (stack.count > 0) {
            UIViewController *vc = [stack lastObject];
            [stack removeLastObject];
            if ([vc isKindOfClass:NSClassFromString(@"T1TabBarViewController")]) {
                NSArray *tabViews = [vc valueForKey:@"tabViews"];
                for (id tabView in tabViews) {
                    if ([tabView respondsToSelector:@selector(bh_applyCurrentThemeToIcon)]) {
                        [tabView performSelector:@selector(bh_applyCurrentThemeToIcon)];
                    }
                }
            }
            // Add children
            for (UIViewController *child in vc.childViewControllers) {
                [stack addObject:child];
            }
            if (vc.presentedViewController) {
                [stack addObject:vc.presentedViewController];
            }
        }
    }
}

static void BHT_applyThemeToWindow(UIWindow *window) {
    if (!window) return;

    // 1. Update our custom themed elements first
    // Update our custom tab bar icons
    if ([window.rootViewController isKindOfClass:NSClassFromString(@"T1TabBarViewController")]) {
        // Ensure BHT_UpdateAllTabBarIcons properly targets the tabViews of this specific window's rootVC
        // If BHT_UpdateAllTabBarIcons iterates all T1TabBarViewControllers globally, this direct call might be okay,
        // but targeting is safer if possible.
        BHT_UpdateAllTabBarIcons(); 
    }

    // Update our custom nav bar bird icon by recursively finding TFNNavigationBars
    BH_EnumerateSubviewsRecursively(window.rootViewController.view, ^(UIView *currentView) {
        if ([currentView isKindOfClass:NSClassFromString(@"TFNNavigationBar")]) {
            // updateLogoTheme should internally use BHTCurrentAccentColor()
            [(TFNNavigationBar *)currentView updateLogoTheme];
        }
    });

    // 2. Force a refresh of the currently visible content view hierarchy.
    // This is an attempt to make Twitter's own views re-evaluate the (now changed) accent color.
    UIViewController *rootVC = window.rootViewController;
    if (rootVC) {
        UIViewController *currentContentVC = rootVC;
        // Traverse to the most relevant visible content view controller
        if ([rootVC isKindOfClass:NSClassFromString(@"T1TabBarViewController")]) {
            // T1TabBarViewController is a UITabBarController subclass.
            // Cast to UITabBarController to access standard 'selectedViewController' property.
            if ([rootVC isKindOfClass:[UITabBarController class]]) {
                currentContentVC = ((UITabBarController *)rootVC).selectedViewController;
            }
        }
        
        // If the selected VC in a tab bar is a Nav controller, go to its visible VC
        if ([currentContentVC isKindOfClass:[UINavigationController class]]) {
            currentContentVC = [(UINavigationController *)currentContentVC visibleViewController];
        }

        // If we have a valid, loaded content view, tell it to redraw and re-layout.
        if (currentContentVC && currentContentVC.isViewLoaded) {
            [currentContentVC.view setNeedsDisplay];
            [currentContentVC.view setNeedsLayout];
            // Optionally, for a more immediate effect, though it can be costly if overused:
            // [currentContentVC.view layoutIfNeeded]; 
        }
    }
}

static void BHT_ensureTheming(void) {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) return;
    
    // Apply the main color theme
    BH_changeTwitterColor([[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"]);
    
    // Apply to all windows
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        BHT_applyThemeToWindow(window);
    }
}

static void BHT_forceRefreshAllWindowAppearances(void) { // Renamed and logic adjusted
    // 1. Update our custom elements (these seem to work reliably)
    BHT_UpdateAllTabBarIcons(); 
    
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (!window.isOpaque || window.isHidden) continue; // Skip non-visible or transparent windows

        // Update our custom nav bar bird icon for this window
        if (window.rootViewController && window.rootViewController.isViewLoaded) {
            BH_EnumerateSubviewsRecursively(window.rootViewController.view, ^(UIView *currentView) {
                if ([currentView isKindOfClass:NSClassFromString(@"TFNNavigationBar")]) {
                    if ([BHTManager tabBarTheming]) { 
                        [(TFNNavigationBar *)currentView updateLogoTheme];
                    }
                }
            });
        }

        // Attempt to "jolt" this window's hierarchy
        UIViewController *rootVC = window.rootViewController;
        if (rootVC && rootVC.isViewLoaded) {
            BH_EnumerateSubviewsRecursively(rootVC.view, ^(UIView *subview) {
                if ([subview respondsToSelector:@selector(tintColorDidChange)]) {
                    [subview tintColorDidChange];
                }
                if ([subview respondsToSelector:@selector(setNeedsDisplay)]) {
                    [subview setNeedsDisplay]; // Force redraw
                }
            });
            [rootVC.view setNeedsLayout];
            [rootVC.view layoutIfNeeded];
            [rootVC.view setNeedsDisplay]; // Redraw the whole root view of the window
        }
    }
}
