#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h> // For objc_msgSend and objc_msgSend_stret
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>
#import "SAMKeychain/AuthViewController.h"
#import "Colours/Colours.h"
#import "BHTManager.h"
#import <math.h>
#import "BHTBundle/BHTBundle.h"

// Block type definitions for compatibility
typedef void (^VoidBlock)(void);
typedef id (^UnknownBlock)(void);

// Forward declare T1ColorSettings and its private method to satisfy the compiler
@interface T1ColorSettings : NSObject
+ (void)_t1_applyPrimaryColorOption;
+ (void)_t1_updateOverrideUserInterfaceStyle;
@end

// We don't need to declare TAEColorSettings here as it's already defined in TWHeaders.h

// Forward declaration for the immersive view controller
@interface T1ImmersiveFullScreenViewController : UIViewController
- (void)immersiveViewController:(id)immersiveViewController showHideNavigationButtons:(_Bool)showButtons;
- (void)playerViewController:(id)playerViewController playerStateDidChange:(NSInteger)state;
@end

// Now declare the category, after the main interface is known
@interface T1ImmersiveFullScreenViewController (BHTwitter)
- (BOOL)BHT_findAndPrepareTimestampLabelForVC:(T1ImmersiveFullScreenViewController *)activePlayerVC;
@end

// TweetSourceHelper is forward-declared at the top of the file

// Forward declarations
static void BHT_UpdateAllTabBarIcons(void);
static void BHT_applyThemeToWindow(UIWindow *window);
static void BHT_ensureTheming(void);
static void BHT_forceRefreshAllWindowAppearances(void);
static void BHT_ensureThemingEngineSynchronized(BOOL forceSynchronize);

// Forward declaration for TweetSourceHelper to be used in early hooks
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
+ (void)pruneSourceCachesIfNeeded;
+ (void)logDebugInfo:(NSString *)message;
+ (void)initializeCookiesWithRetry;
+ (void)retryFetchCookies;
@end

// Theme state tracking
static BOOL BHT_themeManagerInitialized = NO;
static BOOL BHT_isInThemeChangeOperation = NO;

// Map to store timestamp labels for each player instance
static NSMapTable<T1ImmersiveFullScreenViewController *, UILabel *> *playerToTimestampMap = nil;

// Performance optimization: Cache for label searches to avoid repeated expensive traversals
static NSMapTable<T1ImmersiveFullScreenViewController *, NSNumber *> *labelSearchCache = nil;
static NSTimeInterval lastCacheInvalidation = 0;
static const NSTimeInterval CACHE_INVALIDATION_INTERVAL = 10.0; // 10 seconds

// Static helper function for recursive view traversal - OPTIMIZED VERSION
static void BH_EnumerateSubviewsRecursively(UIView *view, void (^block)(UIView *currentView)) {
    if (!view || !block) return;
    
    // Performance optimization: Skip hidden views and their subviews
    if (view.hidden || view.alpha <= 0.01) return;
    
    block(view);
    
    // Performance optimization: Limit recursion depth to prevent excessive traversal
    static NSInteger recursionDepth = 0;
    if (recursionDepth > 15) return; // Reasonable depth limit
    
    recursionDepth++;
    for (UIView *subview in view.subviews) {
        BH_EnumerateSubviewsRecursively(subview, block);
    }
    recursionDepth--;
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
// MARK: - Core Theme Engine Hooks
%hook TAEColorSettings

- (instancetype)init {
    id instance = %orig;
    if (instance && !BHT_themeManagerInitialized) {
        // Register for system theme and appearance related notifications
        [[NSNotificationCenter defaultCenter] addObserverForName:@"UITraitCollectionDidChangeNotification"
                                                         object:nil
                                                          queue:[NSOperationQueue mainQueue]
                                                     usingBlock:^(NSNotification * _Nonnull note) {
            if ([NSUserDefaults.standardUserDefaults objectForKey:@"bh_color_theme_selectedColor"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BHT_ensureThemingEngineSynchronized(NO);
                });
            }
        }];
        
        // Also listen for app entering foreground
        [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationWillEnterForegroundNotification"
                                                         object:nil
                                                          queue:[NSOperationQueue mainQueue]
                                                     usingBlock:^(NSNotification * _Nonnull note) {
            if ([NSUserDefaults.standardUserDefaults objectForKey:@"bh_color_theme_selectedColor"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BHT_ensureThemingEngineSynchronized(YES);
                });
            }
        }];
        
        BHT_themeManagerInitialized = YES;
    }
    return instance;
}

- (void)setPrimaryColorOption:(NSInteger)colorOption {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // If we have a BHTwitter theme selected, ensure it takes precedence
    if ([defaults objectForKey:@"bh_color_theme_selectedColor"]) {
        NSInteger ourSelectedOption = [defaults integerForKey:@"bh_color_theme_selectedColor"];
        
        // Only allow changes that match our selection (avoids fighting with Twitter's system)
        if (colorOption == ourSelectedOption || BHT_isInThemeChangeOperation) {
            %orig(colorOption);
        } else {
            // If not from our theme operation, apply our own theme instead
            %orig(ourSelectedOption);
            
            // Also ensure Twitter's defaults match our setting for consistency
            [defaults setObject:@(ourSelectedOption) forKey:@"T1ColorSettingsPrimaryColorOptionKey"];
        }
    } else {
        // No BHTwitter theme active, let Twitter handle it normally
        %orig(colorOption);
    }
}

- (void)applyCurrentColorPalette {
    %orig;
    
    // Signal UI to refresh after Twitter applies its palette
    if ([NSUserDefaults.standardUserDefaults objectForKey:@"bh_color_theme_selectedColor"] && !BHT_isInThemeChangeOperation) {
        // This call happens after Twitter has applied its color changes,
        // so we need to force refresh our special UI elements
        dispatch_async(dispatch_get_main_queue(), ^{
            BHT_UpdateAllTabBarIcons();
            
            // Refresh our navigation bar bird logos
            for (UIWindow *window in UIApplication.sharedApplication.windows) {
                if (window.isHidden || !window.isOpaque) continue;
                
                if (window.rootViewController && window.rootViewController.isViewLoaded) {
                    BH_EnumerateSubviewsRecursively(window.rootViewController.view, ^(UIView *currentView) {
                        if ([currentView isKindOfClass:NSClassFromString(@"TFNNavigationBar")]) {
                            [(TFNNavigationBar *)currentView updateLogoTheme];
                        }
                    });
                }
            }
        });
    }
}

%end

// Hook T1ColorSettings to intercept Twitter's internal theme application
%hook T1ColorSettings

+ (void)_t1_applyPrimaryColorOption {
    // Execute original implementation to let Twitter update its internal state
    %orig;
    
    // If we have an active theme, ensure it's properly applied
    if ([NSUserDefaults.standardUserDefaults objectForKey:@"bh_color_theme_selectedColor"]) {
        // Synchronize our theme if needed (without forcing)
        BHT_ensureThemingEngineSynchronized(NO);
    }
}

+ (void)_t1_updateOverrideUserInterfaceStyle {
    // Let Twitter update its UI style
    %orig;
    
    // Ensure our theme isn't lost during dark/light mode changes
    if ([NSUserDefaults.standardUserDefaults objectForKey:@"bh_color_theme_selectedColor"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BHT_UpdateAllTabBarIcons();
        });
    }
}

%end

// This replaces the multiple NSUserDefaults method of protecting our theme key
%hook NSUserDefaults

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    // Protect our custom theme from being overwritten by Twitter
    if ([defaultName isEqualToString:@"T1ColorSettingsPrimaryColorOptionKey"]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        id selectedColor = [defaults objectForKey:@"bh_color_theme_selectedColor"];
        
        if (selectedColor != nil && !BHT_isInThemeChangeOperation) {
            // If our theme is active and this change isn't part of our operation,
            // only allow the change if it matches our selection
            if (![value isEqual:selectedColor]) {
                // Silently reject the change, our theme has priority
                return;
            }
        }
    }
    
    %orig;
}

%end

%hook T1AppDelegate
- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    _Bool orig = %orig;
    
    // Remove the animation trigger entirely since it causes black screen
    // We'll rely solely on our hook to launchTransitionProvider to create the provider
    // and our hook to setBlueBackgroundView to ensure correct color
    
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
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"dm_avatars"];
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"tab_bar_theming"];
    }
    [BHTManager cleanCache];
    if ([BHTManager FLEX]) {
        [[%c(FLEXManager) sharedManager] showExplorer];
    }
    
    // Apply theme immediately after launch - simplified version using our new system
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Force synchronize our theme with Twitter's internal theme system
            BHT_ensureThemingEngineSynchronized(YES);
        });
    }
    
    // Start the cookie initialization process with retry mechanism
    if ([BHTManager RestoreTweetLabels]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [TweetSourceHelper initializeCookiesWithRetry];
        });
    }
    
    return orig;
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;
    
    // Re-apply theme on becoming active - simpler with our new management system
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        BHT_ensureThemingEngineSynchronized(YES);
    }

    // Check if we need to initialize cookies
    if ([BHTManager RestoreTweetLabels]) {
        // Check if we have valid cookies
        NSDictionary *cachedCookies = [TweetSourceHelper loadCachedCookies];
        if (!cachedCookies || cachedCookies.count == 0 || !cachedCookies[@"ct0"] || !cachedCookies[@"auth_token"]) {
            // If not, start the initialization process
            dispatch_async(dispatch_get_main_queue(), ^{
                [TweetSourceHelper initializeCookiesWithRetry];
            });
        }
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

// MARK: hide ADs - New Implementation
%hook TFNItemsDataViewAdapterRegistry
- (id)dataViewAdapterForItem:(id)item {
    if ([BHTManager HidePromoted]) {
        //Old Ads
        if ([item isKindOfClass:objc_getClass("T1URTTimelineStatusItemViewModel")] && ((T1URTTimelineStatusItemViewModel *)item).isPromoted) {
            return nil;
        }
        //New Ads
        if ([item isKindOfClass:objc_getClass("TwitterURT.URTTimelineGoogleNativeAdViewModel")]) {
            return nil;
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
// Previous view controller hooks for theme re-application have been removed
// We now use a centralized theme management approach through our TAEColorSettings hooks

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
                // MODIFIED: Use classicTabBarEnabled
                if (shouldTheme && [BHTManager classicTabBarEnabled]) { 
                    // Get the original image
                    UIImage *originalImage = imageView.image;
                    if (originalImage && originalImage.renderingMode != UIImageRenderingModeAlwaysTemplate) {
                        // Create template image from original
                        UIImage *templateImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                        imageView.image = templateImage; // Setting image might trigger layout, potentially re-calling this. Guard needed?
                        imageView.tintColor = BHTCurrentAccentColor();
                    }
                }
                // If classicTabBarEnabled is false, the bird icon should naturally revert
                // or be handled by BHT_forceRefreshAllWindowAppearances if needed.
                // For now, no explicit 'else' to revert here, assuming default behavior is okay
                // or other refresh mechanisms will handle it.
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
            id delegate = self.delegate;
            if (![delegate isKindOfClass:%c(TTAStatusInlineActionsView)]) {
                return %orig;
            }
            TTAStatusInlineActionsView *actionsView = (TTAStatusInlineActionsView *)delegate;
            T1StatusCell *tweetView;
            
            if ([actionsView.superview isKindOfClass:%c(T1StandardStatusView)]) { // normal tweet in the time line
                tweetView = (T1StatusCell *)[(T1StandardStatusView *)actionsView.superview eventHandler];
            } else if ([actionsView.superview isKindOfClass:%c(T1TweetDetailsFocalStatusView)]) { // Focus tweet
                tweetView = (T1StatusCell *)[(T1TweetDetailsFocalStatusView *)actionsView.superview eventHandler];
            } else if ([actionsView.superview isKindOfClass:%c(T1ConversationFocalStatusView)]) { // Focus tweet
                tweetView = (T1StatusCell *)[(T1ConversationFocalStatusView *)actionsView.superview eventHandler];
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
            id delegate = self.delegate;
            if (![delegate isKindOfClass:%c(T1StatusInlineActionsView)]) {
                return %orig;
            }
            T1StatusInlineActionsView *actionsView = (T1StatusInlineActionsView *)delegate;
            T1StatusCell *tweetView;
            
            if ([actionsView.superview isKindOfClass:%c(T1StandardStatusView)]) { // normal tweet in the time line
                tweetView = (T1StatusCell *)[(T1StandardStatusView *)actionsView.superview eventHandler];
            } else if ([actionsView.superview isKindOfClass:%c(T1TweetDetailsFocalStatusView)]) { // Focus tweet
                tweetView = (T1StatusCell *)[(T1TweetDetailsFocalStatusView *)actionsView.superview eventHandler];
            } else if ([actionsView.superview isKindOfClass:%c(T1ConversationFocalStatusView)]) { // Focus tweet
                tweetView = (T1StatusCell *)[(T1ConversationFocalStatusView *)actionsView.superview eventHandler];
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
- (BOOL)allowPromotedContent {
    return [BHTManager HidePromoted] ? NO : %orig;
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

// Declare private T1TweetComposeViewController methods
@interface T1TweetComposeViewController (BHTwitter)
- (void)_t1_showMediaRail;
- (void)_t1_hideMediaRail;
- (BOOL)_t1_mediaRailShowing;
- (void)_t1_loadMediaRailViewController;
- (void)_t1_updateMediaRailViewController;
@end

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

// MARK: Media Rail Restoration
- (BOOL)_t1_shouldShowMediaRail {
    return YES; // Always show media rail regardless of Twitter's logic
}

- (void)viewDidLoad {
    %orig;
    // Ensure media rail view controller is loaded and updated
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _t1_loadMediaRailViewController];
        [self _t1_updateMediaRailViewController];
    });
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

// Constants for cookie refresh interval (reduced to 1 day in seconds for more frequent refresh)
#define COOKIE_REFRESH_INTERVAL (24 * 60 * 60)
#define COOKIE_FORCE_REFRESH_RETRY_COUNT 1 // Force cookie refresh after this many consecutive failures

// --- Networking & Helper Implementation ---
// Full interface already declared at the top of the file

#define MAX_SOURCE_CACHE_SIZE 200 // Reduced cache size to prevent memory issues
#define MAX_CONSECUTIVE_FAILURES 3 // Maximum consecutive failures before backing off

// Static variables for cookie retry mechanism
static BOOL isInitializingCookies = NO;
static NSTimer *cookieRetryTimer = nil;
static int cookieRetryCount = 0;
static const int MAX_COOKIE_RETRIES = 8; // Reduced maximum retry attempts
static const NSTimeInterval INITIAL_RETRY_DELAY = 3.0; // Start with a short delay
static const NSTimeInterval MAX_RETRY_DELAY = 30.0; // Reduced max delay to 30 seconds

@implementation TweetSourceHelper

+ (void)logDebugInfo:(NSString *)message {
    // Only log in debug mode to reduce log spam
#if BHT_DEBUG
    if (message) {
        NSLog(@"[BHTwitter SourceLabel] %@", message);
    }
#endif
}

+ (void)initializeCookiesWithRetry {
    if (isInitializingCookies) {
        return; // Prevent multiple initializations
    }
    isInitializingCookies = YES;
    cookieRetryCount = 0;
    
    // First, try to load any cached cookies
    NSDictionary *cachedCookies = [self loadCachedCookies];
    BOOL hasValidCachedCookies = cachedCookies && cachedCookies.count > 0 && 
                                cachedCookies[@"ct0"] && cachedCookies[@"auth_token"];
                                
    if (hasValidCachedCookies) {
        // We have valid cookies from cache
        // Make them immediately available for pending tweets
        dispatch_async(dispatch_get_main_queue(), ^{
            // Direct notification - more reliable than delayed polling
            [[NSNotificationCenter defaultCenter] postNotificationName:@"BHTCookiesReadyNotification" object:nil];
        });
        
        isInitializingCookies = NO;
        return;
    }
    
    // Try fetching cookies once immediately before starting retry process
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *freshCookies = [self fetchCookies];
        BOOL hasValidFreshCookies = freshCookies && freshCookies.count > 0 && 
                                   freshCookies[@"ct0"] && freshCookies[@"auth_token"];
                                   
        if (hasValidFreshCookies) {
            // Got fresh cookies - cache them and notify
            [self cacheCookies:freshCookies];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Direct notification
                [[NSNotificationCenter defaultCenter] postNotificationName:@"BHTCookiesReadyNotification" object:nil];
                
                // Mark initialization as complete
                isInitializingCookies = NO;
            });
        } else {
            // If couldn't get cookies, start the retry process
            dispatch_async(dispatch_get_main_queue(), ^{
                [self retryFetchCookies];
            });
        }
    });
}

+ (void)retryFetchCookies {
    if (cookieRetryCount >= MAX_COOKIE_RETRIES) {
        isInitializingCookies = NO;
        
        // Invalidate any existing timer
        if (cookieRetryTimer) {
            [cookieRetryTimer invalidate];
            cookieRetryTimer = nil;
        }
        
        // Update any stuck tweets to "Source Unavailable"
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                // Build a list of tweets to update
                NSMutableArray *tweetsToUpdate = [NSMutableArray array];
                for (NSString *tweetID in tweetSources) {
                    NSString *source = tweetSources[tweetID];
                    if ([source isEqualToString:@"Fetching..."]) {
                        [tweetsToUpdate addObject:tweetID];
                        tweetSources[tweetID] = @"Source Unavailable";
                    }
                }
                
                // Only process in batches if we have a significant number of tweets
                if (tweetsToUpdate.count > 0) {
                    NSUInteger batchSize = tweetsToUpdate.count < 20 ? tweetsToUpdate.count : 10;
                    
                    for (NSUInteger i = 0; i < tweetsToUpdate.count; i += batchSize) {
                        @autoreleasepool {
                            NSUInteger end = MIN(i + batchSize, tweetsToUpdate.count);
                            NSArray *batchTweets = [tweetsToUpdate subarrayWithRange:NSMakeRange(i, end - i)];
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                for (NSString *tweetID in batchTweets) {
                                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" 
                                                                                       object:nil 
                                                                                     userInfo:@{@"tweetID": tweetID}];
                                }
                            });
                        }
                    }
                }
            }
        });
        return;
    }
    
    // Try to fetch cookies in background to avoid blocking UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *freshCookies = [self fetchCookies];
        BOOL hasCriticalCookies = freshCookies && freshCookies.count > 0 && 
                                  freshCookies[@"ct0"] && freshCookies[@"auth_token"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (hasCriticalCookies) {
                // Success! Cache cookies and notify
                [self cacheCookies:freshCookies];
                
                // Cleanup timer
                if (cookieRetryTimer) {
                    [cookieRetryTimer invalidate];
                    cookieRetryTimer = nil;
                }
                
                // Complete initialization
                isInitializingCookies = NO;
                
                // Directly notify to update pending tweets
                [[NSNotificationCenter defaultCenter] postNotificationName:@"BHTCookiesReadyNotification" object:nil];
                return;
            }
            
            // Failed to get cookies - try again if not maxed out
            cookieRetryCount++;
            
            // Use increasing delays to reduce resource usage
            // Start with short delays and increase over time
            NSTimeInterval nextDelay = MIN(INITIAL_RETRY_DELAY * pow(1.5, cookieRetryCount - 1), MAX_RETRY_DELAY);
            
            // Clean up existing timer
            if (cookieRetryTimer) {
                [cookieRetryTimer invalidate];
            }
            
            // Schedule next retry with increased delay
            cookieRetryTimer = [NSTimer scheduledTimerWithTimeInterval:nextDelay 
                                                                target:self 
                                                              selector:@selector(retryFetchCookies) 
                                                              userInfo:nil 
                                                               repeats:NO];
        });
    });
}

+ (void)pruneSourceCachesIfNeeded {
    if (!tweetSources) return;
    
    if (tweetSources.count > MAX_SOURCE_CACHE_SIZE) {
        [self logDebugInfo:[NSString stringWithFormat:@"Pruning cache with %ld entries", (long)tweetSources.count]];
        
        // Find oldest entries to remove (those with null values or "Source Unavailable")
        NSMutableArray *keysToRemove = [NSMutableArray array];
        
        for (NSString *key in tweetSources) {
            NSString *source = tweetSources[key];
            if (!source || [source isEqualToString:@""] || [source isEqualToString:@"Source Unavailable"]) {
                [keysToRemove addObject:key];
                if (keysToRemove.count >= tweetSources.count / 4) break; // Remove up to 25% at once
            }
        }
        
        // If we didn't find enough "empty" entries, remove some random ones
        if (keysToRemove.count < tweetSources.count / 5) {
            NSArray *allKeys = [tweetSources allKeys];
            for (int i = 0; i < 20 && keysToRemove.count < tweetSources.count / 4; i++) {
                NSString *randomKey = allKeys[arc4random_uniform((uint32_t)allKeys.count)];
                if (![keysToRemove containsObject:randomKey]) {
                    [keysToRemove addObject:randomKey];
                }
            }
        }
        
        [self logDebugInfo:[NSString stringWithFormat:@"Removing %ld cache entries", (long)keysToRemove.count]];
        
        // Remove the selected keys
        for (NSString *key in keysToRemove) {
            [tweetSources removeObjectForKey:key];
            
            // Also clean up associated data
            NSTimer *timeoutTimer = fetchTimeouts[key];
            if (timeoutTimer) {
                [timeoutTimer invalidate];
                [fetchTimeouts removeObjectForKey:key];
            }
            [fetchRetries removeObjectForKey:key];
            [updateRetries removeObjectForKey:key];
            [updateCompleted removeObjectForKey:key];
            [fetchPending removeObjectForKey:key];
        }
    }
}

+ (NSDictionary *)fetchCookies {
    NSMutableDictionary *cookiesDict = [NSMutableDictionary dictionary];
    NSArray *domains = @[@"api.twitter.com", @".twitter.com", @"twitter.com", @"x.com", @".x.com"];
    NSArray *requiredCookies = @[@"ct0", @"auth_token", @"twid", @"guest_id", @"guest_id_ads", @"guest_id_marketing", @"personalization_id"];
    
    // Get the shared cookie storage
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    // Go through each domain
    for (NSString *domain in domains) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", domain]];
        NSArray *cookies = [cookieStorage cookiesForURL:url];
        
        // Only log in debug mode
#if BHT_DEBUG
        [self logDebugInfo:[NSString stringWithFormat:@"Found %ld cookies for domain %@", (long)cookies.count, domain]];
#endif
        
        for (NSHTTPCookie *cookie in cookies) {
            if ([requiredCookies containsObject:cookie.name]) {
                cookiesDict[cookie.name] = cookie.value;
            }
        }
    }
    
    // Log status of required cookies only in debug mode
#if BHT_DEBUG
    BOOL hasCritical = cookiesDict[@"ct0"] && cookiesDict[@"auth_token"];
    [self logDebugInfo:[NSString stringWithFormat:@"Has critical cookies: %@", hasCritical ? @"Yes" : @"No"]];
#endif
    
    return cookiesDict;
}

+ (void)cacheCookies:(NSDictionary *)cookies {
    if (!cookies || cookies.count == 0) {
        return;
    }
    
    cookieCache = [cookies mutableCopy];
    lastCookieRefresh = [NSDate date];
    
    // Persist to NSUserDefaults using async to avoid blocking
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:cookies forKey:@"TweetSourceTweak_CookieCache"];
        [defaults setObject:lastCookieRefresh forKey:@"TweetSourceTweak_LastCookieRefresh"];
        [defaults synchronize];
    });
}

+ (NSDictionary *)loadCachedCookies {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *cachedCookies = [defaults dictionaryForKey:@"TweetSourceTweak_CookieCache"];
    lastCookieRefresh = [defaults objectForKey:@"TweetSourceTweak_LastCookieRefresh"];
    
    if (cachedCookies) {
        cookieCache = [cachedCookies mutableCopy];
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
        // Initialize dictionaries if they are nil (important after a cache clear)
        if (!tweetSources)   tweetSources   = [NSMutableDictionary dictionary];
        if (!fetchTimeouts)  fetchTimeouts  = [NSMutableDictionary dictionary];
        if (!fetchRetries)   fetchRetries   = [NSMutableDictionary dictionary];
        if (!updateRetries)  updateRetries  = [NSMutableDictionary dictionary];
        if (!updateCompleted) updateCompleted = [NSMutableDictionary dictionary];
        if (!fetchPending)   fetchPending   = [NSMutableDictionary dictionary];

        [self pruneSourceCachesIfNeeded]; // Prune before potentially adding a new entry

        // Reset fetch pending flag after a certain time to prevent tweets from 
        // being stuck if a previous fetch didn't complete properly
        static NSTimeInterval maxPendingTime = 15.0; // 15 seconds max pending time
        
        NSNumber *pendingStartTime = objc_getAssociatedObject(fetchPending[tweetID], "pendingStartTime");
        if (fetchPending[tweetID] && [fetchPending[tweetID] boolValue] && pendingStartTime) {
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:(NSDate *)pendingStartTime];
            if (elapsed > maxPendingTime) {
                // Force reset of stuck pending state
                [fetchPending setObject:@NO forKey:tweetID];
            } else {
                // Still legitimately pending, skip
                return;
            }
        }
        
        // Check if we already have a valid source cached
        if (tweetSources[tweetID] && 
            ![tweetSources[tweetID] isEqualToString:@""] &&
            ![tweetSources[tweetID] isEqualToString:@"Source Unavailable"] &&
            ![tweetSources[tweetID] isEqualToString:@"Fetching..."]) {
            [self logDebugInfo:[NSString stringWithFormat:@"Using cached source for tweet %@: %@", 
                              tweetID, tweetSources[tweetID]]];
            
            // Still announce we have a source, but don't refetch
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" 
                                                                    object:nil 
                                                                  userInfo:@{@"tweetID": tweetID}];
                
                // Make sure this tweet source appears in the UI by retrying the update
                [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:0.2];
            });
            return;
        }

        fetchPending[tweetID] = @(YES);
        // Store the start time of this pending fetch
        objc_setAssociatedObject(fetchPending[tweetID], "pendingStartTime", [NSDate date], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // Initialize or increment retry count
        NSInteger retryCount = 0;
        if (fetchRetries[tweetID]) {
            retryCount = [fetchRetries[tweetID] integerValue];
        }
        fetchRetries[tweetID] = @(retryCount);
        
        // Check if we've exceeded max retries
        if (retryCount >= MAX_CONSECUTIVE_FAILURES) {
            [self logDebugInfo:[NSString stringWithFormat:@"Exceeded max retries (%d) for tweet %@", 
                              MAX_CONSECUTIVE_FAILURES, tweetID]];
            tweetSources[tweetID] = @"Source Unavailable";
            fetchPending[tweetID] = @(NO);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" 
                                                                    object:nil 
                                                                  userInfo:@{@"tweetID": tweetID}];
            });
            return;
        }

        // Set timeout timer
        NSTimer *timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:6.0
                                                                 target:self
                                                               selector:@selector(timeoutFetchForTweetID:)
                                                               userInfo:@{@"tweetID": tweetID}
                                                                repeats:NO];
        fetchTimeouts[tweetID] = timeoutTimer;

        // Build request URL
        NSString *urlString = [NSString stringWithFormat:@"https://api.twitter.com/2/timeline/conversation/%@.json?include_ext_alt_text=true&include_reply_count=true&tweet_mode=extended", tweetID];
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            [self logDebugInfo:@"Invalid URL string"];
            tweetSources[tweetID] = @"Source Unavailable";
            fetchPending[tweetID] = @(NO);
            [fetchTimeouts removeObjectForKey:tweetID];
            [timeoutTimer invalidate];
            return;
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"GET";
        request.timeoutInterval = 5.0;

        // Load cached cookies or start initialization if needed
        if (!cookieCache) {
            [self loadCachedCookies];
        }

        NSDictionary *cookiesToUse = cookieCache;
        
        // Check if we have valid cookies 
        BOOL hasCriticalCookies = cookiesToUse && cookiesToUse.count > 0 && 
                                  cookiesToUse[@"ct0"] && cookiesToUse[@"auth_token"];
        
        // Force cookie refresh if we're retrying and previous attempts failed
        BOOL forceRefresh = (retryCount >= COOKIE_FORCE_REFRESH_RETRY_COUNT);
        
        // If we don't have critical cookies, try to fetch them or initiate retry mechanism
        if (!hasCriticalCookies || forceRefresh || [self shouldRefreshCookies]) {
            [self logDebugInfo:@"Fetching fresh cookies"];
            NSDictionary *freshCookies = [self fetchCookies];
            
            // Check if the fresh cookies are valid
            BOOL freshCookiesValid = freshCookies && freshCookies.count > 0 && 
                                     freshCookies[@"ct0"] && freshCookies[@"auth_token"];
            
            if (freshCookiesValid) {
                [self cacheCookies:freshCookies];
                cookiesToUse = freshCookies;
                
                // If we just got valid cookies, notify listeners that cookies are ready
                if (!hasCriticalCookies) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"BHTCookiesReadyNotification" 
                                                                          object:nil];
                    });
                }
            } else {
                // If we couldn't get cookies and don't have cached ones, start the retry process
                if (!hasCriticalCookies) {
                    [self logDebugInfo:[NSString stringWithFormat:@"No cookies available for tweet %@, starting initialization", tweetID]];
                    
                    // Start cookie initialization if it's not already running
                    if (!isInitializingCookies) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self initializeCookiesWithRetry];
                        });
                    }
                    
                    // Mark this tweet as "Fetching..." instead of unavailable
                    tweetSources[tweetID] = @"Fetching...";
                fetchPending[tweetID] = @(NO);
                [fetchTimeouts removeObjectForKey:tweetID];
                [timeoutTimer invalidate];
                    
                    // Notify UI that we're waiting for login
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" 
                                                                            object:nil 
                                                                          userInfo:@{@"tweetID": tweetID}];
                    });
                return;
                }
            }
        }

        // Build cookie header string
        NSMutableArray *cookieStrings = [NSMutableArray array];
        NSString *ct0Value = cookiesToUse[@"ct0"];
        for (NSString *cookieName in cookiesToUse) {
            NSString *cookieValue = cookiesToUse[cookieName];
            [cookieStrings addObject:[NSString stringWithFormat:@"%@=%@", cookieName, cookieValue]];
        }

        // Set required HTTP headers
        [request setValue:@"Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA" forHTTPHeaderField:@"Authorization"];
        [request setValue:@"OAuth2Session" forHTTPHeaderField:@"x-twitter-auth-type"];
        [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

        // Set CSRF token if available
        if (ct0Value) {
            [request setValue:ct0Value forHTTPHeaderField:@"x-csrf-token"];
        } else {
            [self logDebugInfo:[NSString stringWithFormat:@"No ct0 cookie available for tweet %@", tweetID]];
            // Still proceed with request - it might work without ct0 in some cases
        }

        // Set cookie header
        if (cookieStrings.count > 0) {
            NSString *cookieHeader = [cookieStrings componentsJoinedByString:@"; "];
            [request setValue:cookieHeader forHTTPHeaderField:@"Cookie"];
        } else {
            [self logDebugInfo:[NSString stringWithFormat:@"No cookies to set for tweet %@", tweetID]];
            // Still proceed with request - it might work without cookies in some cases
        }

        // Execute network request
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            @try {
                // Cancel timeout timer
                NSTimer *timer = fetchTimeouts[tweetID];
                if (timer) {
                    [timer invalidate];
                    [fetchTimeouts removeObjectForKey:tweetID];
                }

                fetchPending[tweetID] = @(NO);

                if (error) {
                    [self logDebugInfo:[NSString stringWithFormat:@"Fetch error for tweet %@: %@", tweetID, error]];
                    fetchRetries[tweetID] = @(retryCount + 1);
                    
                    // Retry with exponential backoff
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(pow(2, retryCount) * 0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (retryCount < MAX_CONSECUTIVE_FAILURES) {
                        [self fetchSourceForTweetID:tweetID];
                    } else {
                        tweetSources[tweetID] = @"Source Unavailable";
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    }
                    });
                    return;
                }

                // Check HTTP status code
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode != 200) {
                    [self logDebugInfo:[NSString stringWithFormat:@"Fetch failed for tweet %@ with status code %ld", tweetID, (long)httpResponse.statusCode]];
                    fetchRetries[tweetID] = @(retryCount + 1);
                    
                    // Special handling for auth errors - force cookie refresh
                        if (httpResponse.statusCode == 401 || httpResponse.statusCode == 403) {
                            NSDictionary *freshCookies = [self fetchCookies];
                            if (freshCookies.count > 0) {
                                [self cacheCookies:freshCookies];
                            }
                        }
                    
                    // Retry with exponential backoff
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(pow(2, retryCount) * 0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (retryCount < MAX_CONSECUTIVE_FAILURES) {
                        [self fetchSourceForTweetID:tweetID];
                    } else {
                        tweetSources[tweetID] = @"Source Unavailable";
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    }
                    });
                    return;
                }

                // Parse JSON response
                NSError *jsonError;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (jsonError) {
                    [self logDebugInfo:[NSString stringWithFormat:@"JSON parse error for tweet %@: %@", tweetID, jsonError]];
                    fetchRetries[tweetID] = @(retryCount + 1);
                    
                    // Retry with exponential backoff
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(pow(2, retryCount) * 0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (retryCount < MAX_CONSECUTIVE_FAILURES) {
                        [self fetchSourceForTweetID:tweetID];
                    } else {
                        tweetSources[tweetID] = @"Source Unavailable";
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    }
                    });
                    return;
                }

                // Extract tweet source from JSON
                NSDictionary *tweets = json[@"globalObjects"][@"tweets"];
                if (!tweets || ![tweets isKindOfClass:[NSDictionary class]]) {
                    [self logDebugInfo:[NSString stringWithFormat:@"No tweets object in response for tweet %@", tweetID]];
                    tweetSources[tweetID] = @"Source Unavailable";
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    return;
                }
                
                NSDictionary *tweetData = tweets[tweetID];
                if (!tweetData) {
                    [self logDebugInfo:[NSString stringWithFormat:@"Tweet %@ not found in response", tweetID]];
                    
                    // Try to find the tweet in response by iterating through tweets
                    for (NSString *key in tweets) {
                        // If the ID is numeric and matches our tweetID (allowing for string/number conversion issues)
                        if ([key longLongValue] == [tweetID longLongValue]) {
                            tweetData = tweets[key];
                            [self logDebugInfo:[NSString stringWithFormat:@"Found tweet with alternate ID format: %@", key]];
                            break;
                        }
                    }
                    
                    if (!tweetData) {
                        tweetSources[tweetID] = @"Source Unavailable";
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                        return;
                    }
                }
                
                NSString *sourceHTML = tweetData[@"source"];

                if (sourceHTML) {
                    [self logDebugInfo:[NSString stringWithFormat:@"Found source HTML: %@", sourceHTML]];
                    NSString *sourceText = sourceHTML;
                    
                    // Extract the source text from HTML
                    NSRange startRange = [sourceHTML rangeOfString:@">"];
                    NSRange endRange = [sourceHTML rangeOfString:@"</a>"];
                    if (startRange.location != NSNotFound && endRange.location != NSNotFound && startRange.location + 1 < endRange.location) {
                        sourceText = [sourceHTML substringWithRange:NSMakeRange(startRange.location + 1, endRange.location - startRange.location - 1)];
                        
                        // Clean up sourceText by removing leading numeric string
                        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\d+" options:0 error:nil];
                        if (regex) {
                        sourceText = [regex stringByReplacingMatchesInString:sourceText options:0 range:NSMakeRange(0, sourceText.length) withTemplate:@""];
                    }
                        
                        // Trim any whitespace
                        sourceText = [sourceText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    }
                    
                    // Store the source
                    tweetSources[tweetID] = sourceText;
                    [self logDebugInfo:[NSString stringWithFormat:@"Extracted source for tweet %@: %@", tweetID, sourceText]];
                    
                    // Reset retries on success
                    fetchRetries[tweetID] = @(0);
                    
                    // Notify that source is available
                    dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:0.3];
                    });
                } else {
                    [self logDebugInfo:[NSString stringWithFormat:@"No source field in tweet %@", tweetID]];
                    tweetSources[tweetID] = @"Unknown Source";
                    
                    // Notify that source is available (even if it's "Unknown")
                    dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:0.3];
                    });
                }
            } @catch (NSException *e) {
                [self logDebugInfo:[NSString stringWithFormat:@"Exception in fetch completion for tweet %@: %@", tweetID, e]];
                tweetSources[tweetID] = @"Source Unavailable";
                fetchPending[tweetID] = @(NO);
                
                // Notify with error
                dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                });
            }
        }];
        [task resume];
        
    } @catch (NSException *e) {
        [self logDebugInfo:[NSString stringWithFormat:@"Exception in fetch setup for tweet %@: %@", tweetID, e]];
        tweetSources[tweetID] = @"Source Unavailable";
        fetchPending[tweetID] = @(NO);
        
        NSTimer *timer = fetchTimeouts[tweetID];
        if (timer) {
            [timer invalidate];
            [fetchTimeouts removeObjectForKey:tweetID];
        }
        
        // Notify with error
        dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
        });
    }
}

+ (void)timeoutFetchForTweetID:(NSTimer *)timer {
    NSDictionary *userInfo = timer.userInfo;
    NSString *tweetID = userInfo[@"tweetID"];
    
    if (!tweetID) return;
    
    [self logDebugInfo:[NSString stringWithFormat:@"Timeout for tweet %@", tweetID]];
    
    if (tweetID && fetchPending[tweetID] && [fetchPending[tweetID] boolValue]) {
        NSNumber *retryCount = fetchRetries[tweetID] ?: @(0);
        fetchRetries[tweetID] = @(retryCount.integerValue + 1);
        fetchPending[tweetID] = @(NO);
        [fetchTimeouts removeObjectForKey:tweetID];
        
        if (retryCount.integerValue < MAX_CONSECUTIVE_FAILURES) {
            // Retry with exponential backoff
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(pow(2, retryCount.integerValue) * 0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self fetchSourceForTweetID:tweetID];
            });
        } else {
            tweetSources[tweetID] = @"Source Unavailable";
            
            dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
            [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:0.3];
            });
        }
    }
}

+ (void)retryUpdateForTweetID:(NSString *)tweetID {
    @try {
        if (!tweetID) return;
        
        if (!updateRetries)   updateRetries   = [NSMutableDictionary dictionary];
        if (!updateCompleted) updateCompleted = [NSMutableDictionary dictionary];
        if (!viewInstances)   viewInstances   = [NSMutableDictionary dictionary];

        // Skip if already completed
        if (updateCompleted[tweetID] && [updateCompleted[tweetID] boolValue]) {
            return;
        }
        
        // Initialize or increment retry count
        NSInteger retryCount = 0;
        if (updateRetries[tweetID]) {
            retryCount = [updateRetries[tweetID] integerValue];
        }
        updateRetries[tweetID] = @(retryCount + 1);

        // Only retry for valid sources
        NSString *currentSource = tweetSources[tweetID];
        BOOL needsRetry = currentSource && 
                          ![currentSource isEqualToString:@""] && 
                          ![currentSource isEqualToString:@"Source Unavailable"];
                          
        // Check if this is a tweet waiting for source
        BOOL isTransitionalState = [currentSource isEqualToString:@"Fetching..."];
                                  
        if (needsRetry || isTransitionalState) {
            // Check if we have a view instance for this tweet ID
            BOOL hasViewInstance = viewInstances[tweetID] != nil;
            
            // Post update notification if needed - this refreshes the UI
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" 
                                                                   object:nil 
                                                                 userInfo:@{@"tweetID": tweetID}];
            });
            
            // Use an improved retry schedule:
            // - More frequent for initial retries (important for transitional states)
            // - Higher retry count for tweets in transitional states
            // - More attempts when we know there's a view instance
            
            NSInteger maxRetries = hasViewInstance ? 15 : 10;
            if (isTransitionalState) maxRetries += 5; // Extra retries for tweets waiting for login
            
            // Continue retrying until we reach max or source is no longer available
            if (retryCount < maxRetries) {
                // More frequent retries at the beginning, slower toward the end
                NSTimeInterval delay = (retryCount < 3) ? 0.3 : 
                                      (retryCount < 6) ? 0.5 : 
                                      (retryCount < 10) ? 0.7 : 1.0;
                                      
                // For transitional states, use even faster retries at the beginning
                if (isTransitionalState && retryCount < 5) {
                    delay = 0.2;
                }
                                 
                [self performSelector:@selector(retryUpdateForTweetID:) 
                           withObject:tweetID 
                           afterDelay:delay];
            } else {
                // Mark as completed after max retries
                updateCompleted[tweetID] = @(YES);
            }
        }
    } @catch (NSException *e) {
        // Add minimal error logging
        NSLog(@"[BHTwitter SourceLabel] Error in retryUpdateForTweetID: %@", e);
    }
}

+ (void)pollForPendingUpdates {
    @try {
        if (!tweetSources || !updateCompleted) return;
        
        static NSUInteger pollCounter = 0;
        pollCounter++;
        
        // Only process every 3rd poll to reduce CPU usage (interval is now 15 seconds)
        if (pollCounter % 3 != 0) {
            // Just schedule next poll and return
            [self performSelector:@selector(pollForPendingUpdates) withObject:nil afterDelay:5.0];
            return;
        }
        
        NSArray *allTweetIDs = [tweetSources allKeys];
        NSMutableArray *pendingTweets = [NSMutableArray array];
        
        // First pass: just collect IDs that need updating (no UI work)
        for (NSString *tweetID in allTweetIDs) {
            NSString *source = tweetSources[tweetID];
            if (source && ![source isEqualToString:@""] && ![source isEqualToString:@"Source Unavailable"] &&
                (!updateCompleted[tweetID] || ![updateCompleted[tweetID] boolValue])) {
                [pendingTweets addObject:tweetID];
                if (pendingTweets.count >= 10) break; // Limit batch size
            }
        }
        
        // Now process them in batches to reduce UI work
        if (pendingTweets.count > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSUInteger i = 0; i < MIN(5, pendingTweets.count); i++) {
                    NSString *tweetID = pendingTweets[i];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" 
                                                                        object:nil 
                                                                      userInfo:@{@"tweetID": tweetID}];
                    
                    if (!updateRetries[tweetID] || [updateRetries[tweetID] integerValue] < 3) {
                        [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:0.5];
                    }
                }
                
                // Process the rest with a delay
                if (pendingTweets.count > 5) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        for (NSUInteger i = 5; i < pendingTweets.count; i++) {
                            NSString *tweetID = pendingTweets[i];
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" 
                                                                                object:nil 
                                                                              userInfo:@{@"tweetID": tweetID}];
                            
                            if (!updateRetries[tweetID] || [updateRetries[tweetID] integerValue] < 3) {
                                [self performSelector:@selector(retryUpdateForTweetID:) withObject:tweetID afterDelay:0.5];
                            }
                        }
                    });
                }
            });
        }
        
        // Schedule next poll
        [self performSelector:@selector(pollForPendingUpdates) withObject:nil afterDelay:5.0];
        
    } @catch (__unused NSException *e) {
        // Minimize logging in production
    }
}

+ (void)handleAppForeground:(NSNotification *)notification {
    @try {
        // Lazily fetch cookies when needed instead of on every foreground
        if (!cookieCache || cookieCache.count == 0 || [self shouldRefreshCookies]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                NSDictionary *freshCookies = [self fetchCookies];
                if (freshCookies.count > 0) {
                    [self cacheCookies:freshCookies];
                }
            });
        }
        
        // Start polling for updates (after a short delay)
        [self performSelector:@selector(pollForPendingUpdates) withObject:nil afterDelay:1.5];
        
    } @catch (__unused NSException *e) {
        // Minimized error logging in production
    }
}

+ (void)handleClearCacheNotification:(NSNotification *)notification {
    [self logDebugInfo:@"Clearing source label cache via notification"];
    
    // Invalidate all pending timeout timers
    if (fetchTimeouts) {
        for (NSTimer *timer in [fetchTimeouts allValues]) {
            [timer invalidate];
        }
        [fetchTimeouts removeAllObjects];
    }

    // Clear all dictionaries
    if (tweetSources) [tweetSources removeAllObjects];
    if (viewToTweetID) [viewToTweetID removeAllObjects];
    if (viewInstances) [viewInstances removeAllObjects];
    if (fetchPending) [fetchPending removeAllObjects];
    if (fetchRetries) [fetchRetries removeAllObjects];
    if (updateRetries) [updateRetries removeAllObjects];
    if (updateCompleted) [updateCompleted removeAllObjects];

    // Force cookie refresh
    if (cookieCache) [cookieCache removeAllObjects];
    lastCookieRefresh = nil;
    
    // Clear persistent storage
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"TweetSourceTweak_CookieCache"];
    [defaults removeObjectForKey:@"TweetSourceTweak_LastCookieRefresh"];
    [defaults synchronize];
    
    // Re-initialize dictionaries
    if (!tweetSources) tweetSources = [NSMutableDictionary dictionary];
    if (!viewToTweetID) viewToTweetID = [NSMutableDictionary dictionary];
    if (!viewInstances) viewInstances = [NSMutableDictionary dictionary];
    if (!fetchTimeouts) fetchTimeouts = [NSMutableDictionary dictionary];
    if (!fetchPending) fetchPending = [NSMutableDictionary dictionary];
    if (!fetchRetries) fetchRetries = [NSMutableDictionary dictionary];
    if (!updateRetries) updateRetries = [NSMutableDictionary dictionary];
    if (!updateCompleted) updateCompleted = [NSMutableDictionary dictionary];
    if (!cookieCache) cookieCache = [NSMutableDictionary dictionary];

    // Fetch fresh cookies
    NSDictionary *freshCookies = [self fetchCookies];
    if (freshCookies.count > 0) {
        [self cacheCookies:freshCookies];
    }
    
    // Restart polling
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
            if (!tweetSources) tweetSources = [NSMutableDictionary dictionary]; // Ensure initialized
            NSString *tweetIDStr = @(statusID).stringValue;
            if (!tweetSources[tweetIDStr]) {
                [TweetSourceHelper pruneSourceCachesIfNeeded]; // Prune before adding
                tweetSources[tweetIDStr] = @"";
                [TweetSourceHelper fetchSourceForTweetID:tweetIDStr];
            }
        }
    } @catch (__unused NSException *e) {}
    return originalSelf;
}

%end

// Declare the category interface first
@interface TweetSourceHelper (Notifications)
+ (void)handleCookiesReadyNotification:(NSNotification *)notification;
@end

// Implementation for TweetSourceHelper's missing method
@implementation TweetSourceHelper (Notifications)
+ (void)handleCookiesReadyNotification:(NSNotification *)notification {
    // Check for any tweets waiting for authentication
    if (tweetSources) {
        NSMutableArray *tweetsToRetry = [NSMutableArray array];
        
        // Find all tweets in "Fetching..." state or empty state
        for (NSString *tweetID in tweetSources) {
            NSString *source = tweetSources[tweetID];
            if ([source isEqualToString:@"Fetching..."] || [source isEqualToString:@""]) {
                [tweetsToRetry addObject:tweetID];
            }
        }
        
        if (tweetsToRetry.count == 0) {
            // No tweets need updating
            return;
        }
        
        // Process all tweets that need source labels - performance optimized
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Pre-fetch cookies once for all tweets (avoid repeated fetches)
            NSDictionary *cookiesToUse = cookieCache;
            if (!cookiesToUse || cookiesToUse.count == 0 || !cookiesToUse[@"ct0"] || !cookiesToUse[@"auth_token"]) {
                cookiesToUse = [self fetchCookies];
                if (cookiesToUse && cookiesToUse.count > 0 && cookiesToUse[@"ct0"] && cookiesToUse[@"auth_token"]) {
                    [self cacheCookies:cookiesToUse];
                }
            }
            
            // Only proceed if we have valid cookies
            if (cookiesToUse && cookiesToUse.count > 0 && cookiesToUse[@"ct0"] && cookiesToUse[@"auth_token"]) {
                // Calculate optimal batch size based on number of tweets
                NSUInteger totalTweets = tweetsToRetry.count;
                NSUInteger batchSize = totalTweets < 10 ? totalTweets : (totalTweets < 30 ? 5 : 10);
                
                // Process in batches to balance performance and responsiveness
                for (NSUInteger i = 0; i < tweetsToRetry.count; i += batchSize) {
                    @autoreleasepool {
                        NSUInteger end = MIN(i + batchSize, tweetsToRetry.count);
                        NSArray *currentBatch = [tweetsToRetry subarrayWithRange:NSMakeRange(i, end - i)];
                        
                        // Process current batch immediately
                        dispatch_async(dispatch_get_main_queue(), ^{
                            for (NSString *tweetID in currentBatch) {
                                // Only force fetch if it's still in Fetching state (it might have updated already)
                                if ([tweetSources[tweetID] isEqualToString:@"Fetching..."] || 
                                    [tweetSources[tweetID] isEqualToString:@""]) {
                                    // Reset counters and clear pending flags
                                    [fetchRetries setObject:@0 forKey:tweetID];
                                    [updateRetries setObject:@0 forKey:tweetID];
                                    [fetchPending setObject:@NO forKey:tweetID]; // Clear any stuck pending flags
                                    
                                    // Force a fresh fetch with the known-good cookies
                                    [TweetSourceHelper fetchSourceForTweetID:tweetID];
                                }
                            }
                        });
                        
                        // Small delay between batches but only if more batches exist
                        if (i + batchSize < tweetsToRetry.count) {
                            [NSThread sleepForTimeInterval:0.1]; // Minimal delay between batches
                        }
                    }
                }
            }
        });
    }
}
@end

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
                                [TweetSourceHelper pruneSourceCachesIfNeeded]; // ADDING THIS CALL HERE
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

// Method now implemented in the TweetSourceHelper (Notifications) category

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
                                                     name:@"UIApplicationDidBecomeActiveNotification" // Use string instead of constant for compat
                                                   object:nil];
        // Add observer for cache clearing
        [[NSNotificationCenter defaultCenter] addObserver:[TweetSourceHelper class]
                                                 selector:@selector(handleClearCacheNotification:)
                                                     name:@"BHTClearSourceLabelCacheNotification"
                                                   object:nil];
        
        // Add observer for cookies ready notification
        [[NSNotificationCenter defaultCenter] addObserver:[TweetSourceHelper class]
                                                 selector:@selector(handleCookiesReadyNotification:)
                                                     name:@"BHTCookiesReadyNotification"
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
                        // [TweetSourceHelper pruneSourceCachesIfNeeded]; // This was correctly added by the model already in TFNAttributedTextView
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
                           
                            // Use standard initializer without trying to handle activeRanges
                            // The activeRanges property is likely private and not accessible via KVC
                            TFNAttributedTextModel *newModel = [[%c(TFNAttributedTextModel) alloc] initWithAttributedString:newString];
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
                    // Avoid trying to access private properties
                    TFNAttributedTextModel *newModel = [[%c(TFNAttributedTextModel) alloc] initWithAttributedString:newString];
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

// MARK: - Immersive Player Timestamp Visibility Control

%hook T1ImmersiveFullScreenViewController

// Forward declare the new helper method for visibility within this hook block
- (BOOL)BHT_findAndPrepareTimestampLabelForVC:(T1ImmersiveFullScreenViewController *)activePlayerVC;

// Helper method to find, style, and map the timestamp label for a given VC instance
%new - (BOOL)BHT_findAndPrepareTimestampLabelForVC:(T1ImmersiveFullScreenViewController *)activePlayerVC {
    if (!playerToTimestampMap || !activePlayerVC || !activePlayerVC.isViewLoaded) {
        return NO;
    }
    
    // Performance optimization: Check cache first to avoid repeated expensive searches
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    if (currentTime - lastCacheInvalidation > CACHE_INVALIDATION_INTERVAL) {
        if (labelSearchCache) {
            [labelSearchCache removeAllObjects];
        }
        lastCacheInvalidation = currentTime;
    }
    
    // Initialize cache if needed
    if (!labelSearchCache) {
        labelSearchCache = [NSMapTable weakToStrongObjectsMapTable];
    }

    UILabel *timestampLabel = [playerToTimestampMap objectForKey:activePlayerVC];

    // Performance optimization: Only do fresh find if really necessary
    BOOL needsFreshFind = (!timestampLabel || !timestampLabel.superview || ![timestampLabel.superview isDescendantOfView:activePlayerVC.view]);
    if (timestampLabel && timestampLabel.superview && 
        (![timestampLabel.text containsString:@":"] || ![timestampLabel.text containsString:@"/"])) {
        needsFreshFind = YES;
        [playerToTimestampMap removeObjectForKey:activePlayerVC];
        timestampLabel = nil;
    }
    
    if (needsFreshFind) {
        // Performance optimization: Check if we recently failed to find a label for this VC
        NSNumber *lastSearchResult = [labelSearchCache objectForKey:activePlayerVC];
        if (lastSearchResult && ![lastSearchResult boolValue]) {
            return NO;
        }
        __block UILabel *foundCandidate = nil;
        UIView *searchView = activePlayerVC.view;
        
        // Performance optimization: Limit search scope to likely container views
        __block NSInteger searchCount = 0;
        const NSInteger MAX_SEARCH_COUNT = 100; // Prevent excessive searching

        BH_EnumerateSubviewsRecursively(searchView, ^(UIView *currentView) {
            if (foundCandidate || ++searchCount > MAX_SEARCH_COUNT) return;
            
            // Performance optimization: Skip views that are unlikely to contain timestamp labels
            NSString *currentViewClass = NSStringFromClass([currentView class]);
            if ([currentViewClass containsString:@"Button"] || 
                [currentViewClass containsString:@"Image"] ||
                [currentViewClass containsString:@"Scroll"]) {
                return;
            }
            
            if ([currentView isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)currentView;
                
                // Performance optimization: Quick text validation before hierarchy check
                if (!label.text || label.text.length < 3 || 
                    ![label.text containsString:@":"] || ![label.text containsString:@"/"]) {
                    return;
                }
                
                UIView *v = label.superview;
                BOOL inImmersiveCardViewContext = NO;
                NSInteger hierarchyDepth = 0;
                
                while(v && v != searchView.window && v != searchView && hierarchyDepth < 10) {
                    NSString *className = NSStringFromClass([v class]);
                    if ([className isEqualToString:@"T1TwitterSwift.ImmersiveCardView"] || [className hasSuffix:@".ImmersiveCardView"]) {
                        inImmersiveCardViewContext = YES;
                        break;
                    }
                    v = v.superview;
                    hierarchyDepth++;
                }

                if (inImmersiveCardViewContext) {
                    foundCandidate = label;
                }
            }
        });

        if (foundCandidate) {
            timestampLabel = foundCandidate;
            
            // Don't set the visibility directly - let the player handle it
            // Just style the label for proper appearance
            
            // Now store it in our map
            [playerToTimestampMap setObject:timestampLabel forKey:activePlayerVC];
            [labelSearchCache setObject:@YES forKey:activePlayerVC];
        } else {
            // Performance optimization: Cache negative results to avoid repeated searches
            [labelSearchCache setObject:@NO forKey:activePlayerVC];
            if ([playerToTimestampMap objectForKey:activePlayerVC]) {
                [playerToTimestampMap removeObjectForKey:activePlayerVC];
            }
            return NO;
        }
    }

    if (timestampLabel && ![objc_getAssociatedObject(timestampLabel, "BHT_StyledTimestamp") boolValue]) {
        timestampLabel.font = [UIFont systemFontOfSize:14.0];
        timestampLabel.textColor = [UIColor whiteColor];
        timestampLabel.textAlignment = NSTextAlignmentCenter;
        timestampLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];

        [timestampLabel sizeToFit];
        CGRect currentFrame = timestampLabel.frame;
        CGFloat horizontalPadding = 2.0; // Padding on EACH side
        CGFloat verticalPadding = 12.0; // TOTAL vertical padding (6.0 on each side)
        
        CGRect newFrame = CGRectMake(
            currentFrame.origin.x - horizontalPadding, 
            currentFrame.origin.y - (verticalPadding / 2.0f),
            currentFrame.size.width + (horizontalPadding * 2),
                currentFrame.size.height + verticalPadding
            );
            
        if (newFrame.size.height < 22.0f) {
            CGFloat heightDiff = 22.0f - newFrame.size.height;
            newFrame.size.height = 22.0f;
            newFrame.origin.y -= heightDiff / 2.0f;
        }
        timestampLabel.frame = newFrame;
        timestampLabel.layer.cornerRadius = newFrame.size.height / 2.0f;
        timestampLabel.layer.masksToBounds = YES;
        objc_setAssociatedObject(timestampLabel, "BHT_StyledTimestamp", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return (timestampLabel != nil && timestampLabel.superview != nil); // Ensure it's also in a superview
}

- (void)immersiveViewController:(id)passedImmersiveViewController showHideNavigationButtons:(_Bool)showButtons {
    // Store the original value for "showButtons"
    BOOL originalShowButtons = showButtons;
    
    // No longer forcing controls to be visible on first load
    // Let Twitter's player handle everything normally
    
    // Always pass the original parameter - no overriding
    %orig(passedImmersiveViewController, originalShowButtons);
    
    T1ImmersiveFullScreenViewController *activePlayerVC = self;

    // The rest of the method remains unchanged
    if (![BHTManager restoreVideoTimestamp]) {
        if (playerToTimestampMap) {
            UILabel *labelToManage = [playerToTimestampMap objectForKey:activePlayerVC];
            if (labelToManage) {
                labelToManage.hidden = YES;

            }
        }
        return;
    }
    
    SEL findAndPrepareSelector = NSSelectorFromString(@"BHT_findAndPrepareTimestampLabelForVC:");
    BOOL labelReady = NO;

    if ([self respondsToSelector:findAndPrepareSelector]) {
        NSMethodSignature *signature = [self methodSignatureForSelector:findAndPrepareSelector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:findAndPrepareSelector];
        [invocation setTarget:self];
        [invocation setArgument:&activePlayerVC atIndex:2]; // Arguments start at index 2 (0 = self, 1 = _cmd)
        [invocation invoke];
        [invocation getReturnValue:&labelReady];
    } else {

    }

    if (labelReady) {
        UILabel *timestampLabel = [playerToTimestampMap objectForKey:activePlayerVC];
        if (timestampLabel) { 
            // Let the timestamp follow the controls visibility, but ensure it matches
            BOOL isVisible = showButtons;

            
            // Only adjust if there's a mismatch
            if (isVisible && timestampLabel.hidden) {
                // Controls are visible but label is hidden - fix it
                timestampLabel.hidden = NO;
                NSLog(@"[BHTwitter Timestamp] VC %@: Fixing hidden label to match visible controls", activePlayerVC);
            } else if (!isVisible && !timestampLabel.hidden) {
                // Controls are hidden but label is visible - fix it
                NSLog(@"[BHTwitter Timestamp] VC %@: Label is incorrectly visible, will be hidden by player", activePlayerVC);
            }
        } else {
            NSLog(@"[BHTwitter Timestamp] VC %@: Label was ready but map returned nil.", activePlayerVC);
        }
    } else {
        NSLog(@"[BHTwitter Timestamp] VC %@: Label not ready after findAndPrepare.", activePlayerVC);
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    T1ImmersiveFullScreenViewController *activePlayerVC = self;
    NSLog(@"[BHTwitter Timestamp] VC %@: viewDidAppear.", activePlayerVC);

    if ([BHTManager restoreVideoTimestamp]) {
        if (!playerToTimestampMap) { 
            playerToTimestampMap = [NSMapTable weakToStrongObjectsMapTable];
        }
        
        // Check if this is the first load for this controller
        BOOL isFirstLoad = ![objc_getAssociatedObject(activePlayerVC, "BHT_FirstLoadDone") boolValue];
        
        // Initialize label without using the result
        [self BHT_findAndPrepareTimestampLabelForVC:activePlayerVC];
        
        // Just mark this controller as processed for first load
        if (isFirstLoad) {
            // Mark first load as completed after a short delay
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self && self.view.window) {
                    objc_setAssociatedObject(self, "BHT_FirstLoadDone", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    NSLog(@"[BHTwitter Timestamp] VC %@: First load completed", activePlayerVC);
                }
            });
        }
        
        // Let the label visibility be managed by the player controls
        // Just ensure we have the label identified and styled
    }
}

- (void)playerViewController:(id)playerViewController playerStateDidChange:(NSInteger)state {
    %orig(playerViewController, state);
    T1ImmersiveFullScreenViewController *activePlayerVC = self;
    NSLog(@"[BHTwitter Timestamp] VC %@: playerStateDidChange: %ld", activePlayerVC, (long)state);

    if (![BHTManager restoreVideoTimestamp] || !playerToTimestampMap) {
        NSLog(@"[BHTwitter Timestamp] VC %@: playerStateDidChange - Bailing early (feature off or map nil)", activePlayerVC);
        return;
    }

    // Always try to find/prepare the label for the current video content.
    // This is crucial if the VC is reused and new video content has loaded.
    BOOL labelFoundAndPrepared = [self BHT_findAndPrepareTimestampLabelForVC:activePlayerVC];
    NSLog(@"[BHTwitter Timestamp] VC %@: playerStateDidChange - labelFoundAndPrepared: %d", activePlayerVC, labelFoundAndPrepared);

    if (labelFoundAndPrepared) {
        UILabel *timestampLabel = [playerToTimestampMap objectForKey:activePlayerVC];
        if (timestampLabel && timestampLabel.superview && [timestampLabel isDescendantOfView:activePlayerVC.view]) {
            // Determine current intended visibility of controls.
            // This relies on the main showHideNavigationButtons method being the source of truth for user-initiated toggles.
            // Here, we primarily react to player state changes that might imply controls should appear/disappear.
            BOOL controlsShouldBeVisible = NO;
            UIView *playerControls = nil;
            if ([activePlayerVC respondsToSelector:@selector(playerControlsView)]) { 
                playerControls = [activePlayerVC valueForKey:@"playerControlsView"];
                if (playerControls && [playerControls respondsToSelector:@selector(alpha)]) {
                    controlsShouldBeVisible = playerControls.alpha > 0.0f;
                    NSLog(@"[BHTwitter Timestamp] VC %@: playerStateDidChange - current playerControls.alpha: %f", activePlayerVC, playerControls.alpha);
                }
            }

            // If player state implies controls *should* be visible (e.g., paused, ready and controls were already up),
            // ensure our timestamp is visible. The primary toggling is done by showHideNavigationButtons.
            // This is more about reacting to player-induced control visibility changes.
            // For example, if the video pauses and Twitter automatically shows controls.
            
            // More direct: Mirror the state set by showHideNavigationButtons, which should be the authority.
            // The key is that showHideNavigationButtons should have ALREADY run if controls became visible due to player state.
            // So, if our label is hidden but controls are visible, something is out of sync OR this state change *caused* controls to show.

            // Only fix visibility if there's a clear mismatch
            if (controlsShouldBeVisible && timestampLabel.hidden) {
                // Controls visible but label hidden - fix it
                NSLog(@"[BHTwitter Timestamp] VC %@: playerStateDidChange - Fixing label visibility to match controls", activePlayerVC);
                timestampLabel.hidden = NO;
            } else if (!controlsShouldBeVisible && !timestampLabel.hidden && playerControls && playerControls.alpha == 0.0) {
                // Controls definitely hidden but label still showing - let player hide it
                NSLog(@"[BHTwitter Timestamp] VC %@: playerStateDidChange - Label visibility mismatch noted", activePlayerVC);
            }
        } else {
            NSLog(@"[BHTwitter Timestamp] VC %@: playerStateDidChange - Label was prepared but map/superview check failed.", activePlayerVC);
        }
    } else {
        NSLog(@"[BHTwitter Timestamp] VC %@: playerStateDidChange - Label not found/prepared.", activePlayerVC);
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
// MARK: - Restore Pull-To-Refresh Sounds

// Helper function to play sounds since we can't directly call methods on TFNPullToRefreshControl
static void PlayRefreshSound(int soundType) {
    static SystemSoundID sounds[2] = {0, 0};
    static BOOL soundsInitialized[2] = {NO, NO};
    
    // Ensure the sounds are only initialized once per type
    if (!soundsInitialized[soundType]) {
        NSString *soundFile = nil;
        if (soundType == 0) {
            // Sound when pulling down
            soundFile = @"psst2.aac";
        } else if (soundType == 1) {
            // Sound when refresh completes
            soundFile = @"pop.aac";
        }
        
        if (soundFile) {
            NSURL *soundURL = [[BHTBundle sharedBundle] pathForFile:soundFile];
            if (soundURL) {
                OSStatus status = AudioServicesCreateSystemSoundID((__bridge CFURLRef)soundURL, &sounds[soundType]);
                if (status == 0) {
                    soundsInitialized[soundType] = YES;
                    NSLog(@"[BHTwitter] Successfully initialized sound %@ (type %d)", soundFile, soundType);
                } else {
                    NSLog(@"[BHTwitter] Failed to initialize sound %@ (type %d), status: %d", soundFile, soundType, (int)status);
                }
            } else {
                NSLog(@"[BHTwitter] Could not find sound file: %@", soundFile);
            }
        }
    }
    
    // Play the sound if it was successfully initialized
    if (soundsInitialized[soundType]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            AudioServicesPlaySystemSound(sounds[soundType]);
        });
    }
}

%hook TFNPullToRefreshControl

// Track state with instance-specific variables using associated objects
static char kPreviousLoadingStateKey;
static char kManualRefreshInProgressKey;

// Always enable sound effects
+ (_Bool)_areSoundEffectsEnabled {
    return YES;
}

// Hook the simple loading property setter
- (void)setLoading:(_Bool)loading {
    NSLog(@"[BHTwitter] setLoading: called with loading=%d", loading);
    
    // Get previous loading state
    NSNumber *previousLoadingState = objc_getAssociatedObject(self, &kPreviousLoadingStateKey);
    BOOL wasLoading = previousLoadingState ? [previousLoadingState boolValue] : NO;
    
    %orig;
    
    // Store the new state AFTER calling original
    objc_setAssociatedObject(self, &kPreviousLoadingStateKey, @(loading), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // If loading went from YES to NO, refresh is complete - play pop sound
    if (wasLoading && !loading) {
        NSLog(@"[BHTwitter] Loading changed from YES to NO - playing pop sound");
        PlayRefreshSound(1);
    }
    
    if (!wasLoading && loading) {
        NSLog(@"[BHTwitter] Loading changed from NO to YES - refresh started");
    }
}

// Hook the completion-based loading setter
- (void)setLoading:(_Bool)loading completion:(void(^)(void))completion {
    NSLog(@"[BHTwitter] setLoading:completion: called with loading=%d", loading);
    
    // Get previous loading state
    NSNumber *previousLoadingState = objc_getAssociatedObject(self, &kPreviousLoadingStateKey);
    BOOL wasLoading = previousLoadingState ? [previousLoadingState boolValue] : NO;
    
    // Check if we're in a manual refresh
    NSNumber *manualRefresh = objc_getAssociatedObject(self, &kManualRefreshInProgressKey);
    BOOL isManualRefresh = manualRefresh ? [manualRefresh boolValue] : NO;
    
    %orig;
    
    // Store the new state AFTER calling original
    objc_setAssociatedObject(self, &kPreviousLoadingStateKey, @(loading), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // If loading went from YES to NO AND we're in a manual refresh, play pop sound
    if (wasLoading && !loading && isManualRefresh) {
        NSLog(@"[BHTwitter] Manual refresh completed (completion) - playing pop sound");
        PlayRefreshSound(1);
        // Clear the manual refresh flag
        objc_setAssociatedObject(self, &kManualRefreshInProgressKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    if (!wasLoading && loading) {
        NSLog(@"[BHTwitter] Loading changed from NO to YES (completion) - refresh started");
    }
}

// Detect manual pull-to-refresh and play pull sound
- (void)_setStatus:(unsigned long long)status fromScrolling:(_Bool)fromScrolling {
    NSLog(@"[BHTwitter] _setStatus:%llu fromScrolling:%d", status, fromScrolling);
    %orig;
    
    if (status == 1 && fromScrolling) {
        NSLog(@"[BHTwitter] Manual pull detected - playing pull sound");
        PlayRefreshSound(0);
        
        // Mark that we're in a manual refresh
        objc_setAssociatedObject(self, &kManualRefreshInProgressKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // Mark that loading started (even though setLoading: might not be called with loading=1)
        objc_setAssociatedObject(self, &kPreviousLoadingStateKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[BHTwitter] Set manual refresh flag and previous loading state to YES");
    }
}

%end

%ctor {
    // Import AudioServices framework
    dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", RTLD_LAZY);
    
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
    // REMOVED: Observer for BHTClassicTabBarSettingChanged (and its new equivalent CLASSIC_TAB_BAR_DISABLED_NOTIFICATION_NAME)
    // The logic for handling classic tab bar changes is now fully managed by restart.
    
    // Add observers for both window and theme changes
    [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeVisibleNotification 
                                                    object:nil 
                                                     queue:[NSOperationQueue mainQueue] 
                                                usingBlock:^(NSNotification * _Nonnull note) {
        UIWindow *window = note.object;
        if (window && [[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
            BHT_applyThemeToWindow(window);
        }
    }];
    
    // Note: UIApplicationDidBecomeActiveNotification is now primarily handled by
    // BHT_ensureThemingEngineSynchronized with the appropriate flags and hooks
    
    // Observe theme changes
    // REMOVED: Observer for BHTTabBarThemingChanged (second instance)
    // [[NSNotificationCenter defaultCenter] addObserverForName:@\"BHTTabBarThemingChanged\" 
    //                                                 object:nil 
    //                                                  queue:[NSOperationQueue mainQueue] 
    //                                             usingBlock:^(NSNotification * _Nonnull note) {
    //     BHT_ensureTheming(); // This was likely too broad, direct update is better.
    // }];

    static dispatch_once_t onceTokenPlayerMap;
    dispatch_once(&onceTokenPlayerMap, ^{
        playerToTimestampMap = [NSMapTable weakToStrongObjectsMapTable];
    });
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

    // MODIFIED: Logic for enabling/disabling theme
    if (![BHTManager classicTabBarEnabled]) {
        // Revert to default appearance
        imgView.tintColor = nil; 
        if (imgView.image) {
            // Attempt to set to a mode that respects original colors, or automatic.
            // UIImageRenderingModeAutomatic might be best if original isn't template.
            // If Twitter's default icons are always template, this might not show them correctly
            // without knowing their default non-themed tint color.
            // For now, assume nil tintColor and automatic rendering mode is the goal.
            imgView.image = [imgView.image imageWithRenderingMode:UIImageRenderingModeAutomatic];
        }
    } else {
        // Apply custom theme (existing logic)
        UIColor *targetColor;
        if ([[self valueForKey:@"selected"] boolValue]) { 
            targetColor = BHTCurrentAccentColor();
        } else {
            targetColor = [UIColor grayColor]; // Unselected but themed icon
        }
        
    if (imgView.image && imgView.image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
        imgView.image = [imgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
        
    SEL applyTintColorSelector = @selector(applyTintColor:);
    if ([self respondsToSelector:applyTintColorSelector]) {
            ((void (*)(id, SEL, UIColor *))objc_msgSend)(self, applyTintColorSelector, targetColor);
    } else {
        imgView.tintColor = targetColor;
    }
    }

    // Always call Twitter's internal update method to refresh the visual state
    SEL updateImageViewSelector = NSSelectorFromString(@"_t1_updateImageViewAnimated:");
    if ([self respondsToSelector:updateImageViewSelector]) {
        IMP imp = [self methodForSelector:updateImageViewSelector];
        void (*func)(id, SEL, _Bool) = (void *)imp;
        func(self, updateImageViewSelector, NO); // Animate NO for immediate change
    } else if (imgView) {
        [imgView setNeedsDisplay]; // Fallback if the specific update method isn't found
    }
}

- (void)setSelected:(_Bool)selected {
    %orig(selected);
    [self performSelector:@selector(bh_applyCurrentThemeToIcon)];
}

// Optional: Hook _t1_updateImageViewAnimated if setSelected is not enough
// or if other state changes (like theme color change) need to trigger this.
/*
- (void)_t1_updateImageViewAnimated:(_Bool)animated {
    %orig(animated);
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

// Helper to synchronize theme engine and ensure our theme is active
static void BHT_ensureThemingEngineSynchronized(BOOL forceSynchronize) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id selectedColorObj = [defaults objectForKey:@"bh_color_theme_selectedColor"];
    
    if (!selectedColorObj) return;
    
    NSInteger selectedColor = [selectedColorObj integerValue];
    id twitterColorObj = [defaults objectForKey:@"T1ColorSettingsPrimaryColorOptionKey"];
    
    // Check if Twitter's color setting matches our desired color
    if (forceSynchronize || !twitterColorObj || ![twitterColorObj isEqual:selectedColorObj]) {
        // Mark that we're performing our own theme change to avoid recursion
        BHT_isInThemeChangeOperation = YES;
        
        // Apply our theme color through Twitter's system
        TAEColorSettings *taeSettings = [%c(TAEColorSettings) sharedSettings];
        if ([taeSettings respondsToSelector:@selector(setPrimaryColorOption:)]) {
            [taeSettings setPrimaryColorOption:selectedColor];
        }
        
        // Set Twitter's user defaults key to match our selection
        [defaults setObject:selectedColorObj forKey:@"T1ColorSettingsPrimaryColorOptionKey"];
        
        // Call Twitter's internal theme application methods
        if ([%c(T1ColorSettings) respondsToSelector:@selector(_t1_applyPrimaryColorOption)]) {
            [%c(T1ColorSettings) _t1_applyPrimaryColorOption];
        }
        
        // Refresh UI to reflect these changes
        BHT_UpdateAllTabBarIcons();
        
        // Apply to each window
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (!window.isOpaque || window.isHidden) continue;
            
            // Apply theme to the specific window
        BHT_applyThemeToWindow(window);
        }
        
        // Reset our operation flag
        BHT_isInThemeChangeOperation = NO;
    }
}

// Legacy method for backward compatibility, now just calls our new function
static void BHT_ensureTheming(void) {
    BHT_ensureThemingEngineSynchronized(YES);
}

// Comprehensive UI refresh - used when we need to force a UI update
static void BHT_forceRefreshAllWindowAppearances(void) {
    // Update tab bar icons which are specifically customized by our tweak
    BHT_UpdateAllTabBarIcons(); 
    
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (!window.isOpaque || window.isHidden) continue;

        // Update our custom nav bar bird icon for this window
        if (window.rootViewController && window.rootViewController.isViewLoaded) {
            BH_EnumerateSubviewsRecursively(window.rootViewController.view, ^(UIView *currentView) {
                if ([currentView isKindOfClass:NSClassFromString(@"TFNNavigationBar")]) {
                    if ([BHTManager classicTabBarEnabled]) {
                        [(TFNNavigationBar *)currentView updateLogoTheme];
                    }
                }
            });
        }

        // Trigger UI refresh hierarchy
        UIViewController *rootVC = window.rootViewController;
        if (rootVC && rootVC.isViewLoaded) {
            // Trigger tintColorDidChange on relevant views
            BH_EnumerateSubviewsRecursively(rootVC.view, ^(UIView *subview) {
                if ([subview respondsToSelector:@selector(tintColorDidChange)]) {
                    [subview tintColorDidChange];
                }
                if ([subview respondsToSelector:@selector(setNeedsDisplay)]) {
                    [subview setNeedsDisplay];
                }
            });
            
            // Force layout update
            [rootVC.view setNeedsLayout];
            [rootVC.view layoutIfNeeded];
            [rootVC.view setNeedsDisplay];
        }
    }
}

// MARK: Theme TFNBarButtonItemButtonV1
%hook TFNBarButtonItemButtonV1
- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        self.tintColor = BHTCurrentAccentColor();
    }
}

- (void)setTintColor:(UIColor *)tintColor {
    %orig(BHTCurrentAccentColor());
}
%end

// MARK: - Timestamp Label Styling via UILabel -setText:

// Global reference to the timestamp label for the active immersive player
static UILabel *gVideoTimestampLabel = nil;

// Helper method to determine if a text is likely a timestamp
static BOOL isTimestampText(NSString *text) {
    if (!text || text.length == 0) {
        return NO;
    }
    
    // Check for common timestamp patterns like "0:01/0:05" or "00:20/01:30"
    NSRange colonRange = [text rangeOfString:@":"];
    NSRange slashRange = [text rangeOfString:@"/"];
    
    // Must have both colon and slash
    if (colonRange.location == NSNotFound || slashRange.location == NSNotFound) {
        return NO;
    }
    
    // Slash should come after colon in a timestamp (e.g., "0:01/0:05")
    if (slashRange.location < colonRange.location) {
        return NO;
    }
    
    // Should have another colon after the slash
    NSRange secondColonRange = [text rangeOfString:@":" options:0 range:NSMakeRange(slashRange.location, text.length - slashRange.location)];
    if (secondColonRange.location == NSNotFound) {
        return NO;
    }
    
    return YES;
}

// Helper to find player controls in view hierarchy
static UIView *findPlayerControlsInHierarchy(UIView *startView) {
    if (!startView) return nil;
    
    __block UIView *playerControls = nil;
    BH_EnumerateSubviewsRecursively(startView, ^(UIView *view) {
        if (playerControls) return;
        
        NSString *className = NSStringFromClass([view class]);
        if ([className containsString:@"PlayerControlsView"] || 
            [className containsString:@"VideoControls"]) {
            playerControls = view;
        }
    });
    
    return playerControls;
}

%hook UILabel

- (void)setText:(NSString *)text {
    %orig(text);
    
    // Skip processing if feature is disabled
    if (![BHTManager restoreVideoTimestamp]) {
        return;
    }
    
    // Skip if already our target label
    if (self == gVideoTimestampLabel) {
        return;
    }
    
    // Skip if text doesn't match timestamp pattern
    if (!isTimestampText(self.text)) {
        return;
    }
    
    // Check if already styled
    if ([objc_getAssociatedObject(self, "BHT_StyledTimestamp") boolValue]) {
        return;
    }
    
    // Find if we're in the correct view context
    UIView *parentView = self.superview;
    BOOL isInImmersiveContext = NO;
    
    while (parentView) {
        NSString *className = NSStringFromClass([parentView class]);
        if ([className isEqualToString:@"T1TwitterSwift.ImmersiveCardView"] || 
            [className hasSuffix:@".ImmersiveCardView"]) {
            isInImmersiveContext = YES;
            break;
        }
        parentView = parentView.superview;
    }
    
    if (isInImmersiveContext) {
        NSLog(@"[BHTwitter Timestamp] Styling timestamp label: %@", self.text);
        
        // Apply styling - ONLY styling, not visibility
        self.font = [UIFont systemFontOfSize:14.0];
        self.textColor = [UIColor whiteColor];
        self.textAlignment = NSTextAlignmentCenter;
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        
        // Calculate size and apply padding
        [self sizeToFit];
        CGRect frame = self.frame;
        CGFloat horizontalPadding = 4.0;
        CGFloat verticalPadding = 12.0;
        
        frame = CGRectMake(
            frame.origin.x - horizontalPadding / 2.0f,
            frame.origin.y - verticalPadding / 2.0f,
            frame.size.width + horizontalPadding,
            frame.size.height + verticalPadding
        );
        
        // Ensure minimum height
        if (frame.size.height < 22.0f) {
            CGFloat diff = 22.0f - frame.size.height;
            frame.size.height = 22.0f;
            frame.origin.y -= diff / 2.0f;
        }
        
        self.frame = frame;
        self.layer.cornerRadius = frame.size.height / 2.0f;
        self.layer.masksToBounds = YES;
        
        // Mark as styled and store reference
        objc_setAssociatedObject(self, "BHT_StyledTimestamp", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gVideoTimestampLabel = self;
    }
}

// For first-load mode, prevent hiding the timestamp
- (void)setHidden:(BOOL)hidden {
    // Only check labels that might be our timestamp
    if (self == gVideoTimestampLabel && [BHTManager restoreVideoTimestamp]) {
        // If trying to hide a fixed label, prevent it
        if (hidden) {
            BOOL isFixedForFirstLoad = [objc_getAssociatedObject(self, "BHT_FixedForFirstLoad") boolValue];
            if (isFixedForFirstLoad) {
                // Let the original method run but with "NO" instead of "YES"
                return %orig(NO);
            }
        }
    }
    
    // Default behavior
    %orig(hidden);
}

// Also prevent changing alpha to 0 for first-load labels
- (void)setAlpha:(CGFloat)alpha {
    // Only check our timestamp label
    if (self == gVideoTimestampLabel && [BHTManager restoreVideoTimestamp]) {
        // If trying to make a fixed label transparent, prevent it
        if (alpha == 0.0) {
            BOOL isFixedForFirstLoad = [objc_getAssociatedObject(self, "BHT_FixedForFirstLoad") boolValue];
            if (isFixedForFirstLoad) {
                // Keep it fully opaque during protected period
                return %orig(1.0);
            }
        }
    }
    
    // Default behavior
    %orig(alpha);
}

%end

// MARK: - Gemini AI Translation Integration

// Helper class to communicate with Gemini AI API
@interface GeminiTranslator : NSObject
+ (instancetype)sharedInstance;
- (void)translateText:(NSString *)text fromLanguage:(NSString *)sourceLanguage toLanguage:(NSString *)targetLanguage completion:(void (^)(NSString *translatedText, NSError *error))completion;
- (void)simplifiedTranslateAndDisplay:(NSString *)text fromViewController:(UIViewController *)viewController;
@end

// Required interface declarations to fix compiler errors
@interface TFSTwitterTranslation : NSObject
- (id)initWithTranslation:(NSString *)translation 
                 entities:(id)entities 
        translationSource:(NSString *)source 
  localizedSourceLanguage:(NSString *)localizedLang 
          sourceLanguage:(NSString *)sourceLang 
     destinationLanguage:(NSString *)destLang 
        translationState:(NSString *)state;
- (NSString *)sourceLanguage;
@end

// Do not redeclare T1StatusBodyTextView as it is already in TWHeaders.h
// Just declare T1CoreStatusViewModel with its status property
@interface T1CoreStatusViewModel : NSObject
@property (nonatomic, readonly) id status; // Using 'id' to match property in TWHeaders.h
@end

// The TFNTwitterStatus is already defined in TWHeaders.h

// Define _UINavigationBarContentView first since it's forward declared
@interface _UINavigationBarContentView : UIView
@end

@interface _UINavigationBarContentView (BHTwitter)
- (void)BHT_addTranslateButtonIfNeeded;
- (TFNTwitterStatus *)BHT_findStatusObjectInController:(UIViewController *)controller;
- (NSString *)BHT_extractTextFromStatusObjectInController:(UIViewController *)controller;
- (void)BHT_translateCurrentTweetAction:(UIButton *)sender;
@end

%hook _UINavigationBarContentView

static char kTranslateButtonKey;

// Removed createTextFinderWithTextRef and processView as they are not used by this feature.

%new
- (void)BHT_addTranslateButtonIfNeeded {
    // Check if translate feature is enabled
    if (![BHTManager enableTranslate]) {
        // Remove existing button if feature is disabled
        UIButton *existingButton = objc_getAssociatedObject(self, &kTranslateButtonKey);
        if (existingButton) {
            [existingButton removeFromSuperview];
            objc_setAssociatedObject(self, &kTranslateButtonKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    
    NSLog(@"[BHTwitter Translate] Attempting to add button in BHT_addTranslateButtonIfNeeded for view: %@", self);
    UIViewController *parentVCFromResponder = nil;
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
    }
    if (responder && [responder isKindOfClass:[UIViewController class]]) {
        parentVCFromResponder = (UIViewController *)responder;
    }

    UIViewController *actualContentVC = nil;
    if (parentVCFromResponder) {
        NSLog(@"[BHTwitter Translate] Found parentVCFromResponder: %@", NSStringFromClass([parentVCFromResponder class]));
        if ([parentVCFromResponder isKindOfClass:[UINavigationController class]]) {
            actualContentVC = [(UINavigationController *)parentVCFromResponder topViewController];
            NSLog(@"[BHTwitter Translate] parentVCFromResponder is a UINavigationController. ActualContentVC is topViewController: %@", NSStringFromClass([actualContentVC class]));
        } else {
            actualContentVC = parentVCFromResponder;
            NSLog(@"[BHTwitter Translate] parentVCFromResponder is not a UINavigationController. ActualContentVC is parentVCFromResponder: %@", NSStringFromClass([actualContentVC class]));
        }
    } else {
        NSLog(@"[BHTwitter Translate] Could not find parentVCFromResponder for _UINavigationBarContentView: %@", self);
        // Attempt to get VC from window if direct responder fails (existing fallback)
        UIWindow *keyWindow = self.window;
        if (keyWindow && keyWindow.rootViewController) {
            UIViewController *rootVC = keyWindow.rootViewController;
            UIViewController *topVC = rootVC;
            while (topVC.presentedViewController) {
                topVC = topVC.presentedViewController;
            }
            if ([topVC isKindOfClass:[UINavigationController class]]) {
                 actualContentVC = [(UINavigationController*)topVC topViewController];
                 NSLog(@"[BHTwitter Translate] Fallback: Found actualContentVC from window->topVC (UINav): %@", NSStringFromClass([actualContentVC class]));
            } else {
                 actualContentVC = topVC;
                 NSLog(@"[BHTwitter Translate] Fallback: Found actualContentVC from window->topVC: %@", NSStringFromClass([actualContentVC class]));
            }
        } else {
            NSLog(@"[BHTwitter Translate] Fallback: Could not get actualContentVC from window either.");
            return; // Can't proceed without a VC
        }
    }
    
    // Check if this is a conversation/tweet view by examining both title and controller class
    BOOL isTweetView = NO;
    UILabel *titleLabel = nil;
    
    NSLog(@"[BHTwitter Translate] Subviews of %@: %@", self, self.subviews);
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(UILabel)]) {
            UILabel *label = (UILabel *)subview;
            NSLog(@"[BHTwitter Translate] Found UILabel with text: ' %@ '", label.text);
            if ([label.text isEqualToString:@"Post"] || [label.text isEqualToString:@"Tweet"]) {
                titleLabel = label;
                NSLog(@"[BHTwitter Translate] Matched titleLabel: %@", titleLabel.text);
                break;
            }
        }
    }
    
    if (!titleLabel) {
        NSLog(@"[BHTwitter Translate] Did not find titleLabel with 'Post' or 'Tweet'.");
    }
    
    if (titleLabel && actualContentVC) {
        NSString *vcClassName = NSStringFromClass([actualContentVC class]);
        NSLog(@"[BHTwitter Translate] Checking actualContentVC className: %@", vcClassName);
        if ([vcClassName containsString:@"Conversation"] || 
            [vcClassName containsString:@"Tweet"] || 
            [vcClassName containsString:@"Status"] || 
            [vcClassName containsString:@"Detail"]) {
            isTweetView = YES;
            NSLog(@"[BHTwitter Translate] actualContentVC className matched. isTweetView = YES.");
        } else {
            NSLog(@"[BHTwitter Translate] actualContentVC className ('%@') did NOT match expected keywords.", vcClassName);
        }
    } else {
        if (!titleLabel) NSLog(@"[BHTwitter Translate] Condition failed for isTweetView: titleLabel is nil.");
        if (!actualContentVC) NSLog(@"[BHTwitter Translate] Condition failed for isTweetView: actualContentVC is nil.");
    }
    
    // Only proceed if this is a valid tweet view
    if (isTweetView) {
        NSLog(@"[BHTwitter Translate] isTweetView is YES. Proceeding to check/add button.");
        // Check if button already exists
        UIButton *existingButton = objc_getAssociatedObject(self, &kTranslateButtonKey);
        if (existingButton) {
            NSLog(@"[BHTwitter Translate] Translate button already exists: %@", existingButton);
            // Ensure it's visible and properly placed if it exists
            existingButton.hidden = NO;
            [self bringSubviewToFront:existingButton]; 
            return;
        }
        
        // If button doesn't exist, create it
        NSLog(@"[BHTwitter Translate] Creating new translate button.");
        UIButton *translateButton = [UIButton buttonWithType:UIButtonTypeSystem];
        if (@available(iOS 13.0, *)) {
            // Use a proper translation SF symbol
            [translateButton setImage:[UIImage systemImageNamed:@"text.bubble.fill"] forState:UIControlStateNormal];
            
            // Set proper tint color based on appearance
            if (@available(iOS 12.0, *)) {
                if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    translateButton.tintColor = [UIColor whiteColor];
                } else {
                    translateButton.tintColor = [UIColor blackColor];
                }
                
                // Add trait collection observer for dark/light mode changes
                [translateButton addObserver:self forKeyPath:@"traitCollection" options:NSKeyValueObservingOptionNew context:NULL];
            }
        } else {
            [translateButton setTitle:@"Translate" forState:UIControlStateNormal]; // Fallback for older iOS
        }
        [translateButton addTarget:self action:@selector(BHT_translateCurrentTweetAction:) forControlEvents:UIControlEventTouchUpInside];
        translateButton.tag = 12345; // Unique tag
        
        // Add button with higher z-index
        [self insertSubview:translateButton aboveSubview:titleLabel];
        translateButton.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Store button reference in associated object
        objc_setAssociatedObject(self, &kTranslateButtonKey, translateButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Place the button on the right with a moderate offset to avoid collisions
        NSArray *constraints = @[
            [translateButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [translateButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-55], // Move slightly more to the right
            [translateButton.widthAnchor constraintEqualToConstant:44],
            [translateButton.heightAnchor constraintEqualToConstant:44]
        ];
        
        // Store constraints reference to prevent deallocation
        objc_setAssociatedObject(translateButton, "translateButtonConstraints", constraints, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [NSLayoutConstraint activateConstraints:constraints];
    } else {
        // If this is not a tweet view but we have a button, remove it
        UIButton *existingButton = objc_getAssociatedObject(self, &kTranslateButtonKey);
        if (existingButton) {
            [existingButton removeFromSuperview];
            objc_setAssociatedObject(self, &kTranslateButtonKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

- (void)setTitle:(id)arg1 {
    %orig;
    
    // Use a dispatch_after to ensure we add the button after layout is complete
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self BHT_addTranslateButtonIfNeeded];
    });
}

// Also hook didMoveToWindow to improve persistence
- (void)didMoveToWindow {
    %orig;
    
    if (self.window) {
        // Use a short delay to ensure view is fully set up
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self BHT_addTranslateButtonIfNeeded];
        });
    }
}

// Handle dark/light mode changes
%new
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"traitCollection"] && [object isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)object;
        if (@available(iOS 12.0, *)) {
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                button.tintColor = [UIColor whiteColor];
            } else {
                button.tintColor = [UIColor blackColor];
            }
        }
    }
}

// Handle deallocation to clean up KVO
%new
- (void)dealloc {
    UIButton *translateButton = objc_getAssociatedObject(self, &kTranslateButtonKey);
    if (translateButton) {
        @try {
            [translateButton removeObserver:self forKeyPath:@"traitCollection"];
        } @catch (NSException *exception) {
            // Observer might not have been added
        }
    }
    // No %orig here because this is a new method, not an override
}

%new - (void)BHT_translateCurrentTweetAction:(UIButton *)sender {
    UIViewController *targetController = nil;
    UIResponder *responder = self;
    
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
    }
    if (responder && [responder isKindOfClass:[UIViewController class]]) {
        targetController = (UIViewController *)responder;
        if ([targetController isKindOfClass:[UINavigationController class]]) {
            targetController = [(UINavigationController *)targetController topViewController];
        }
    } else {
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            NSSet *connectedScenes = UIApplication.sharedApplication.connectedScenes;
            for (UIScene *scene in connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (keyWindow) break;
                }
            }
        } else {
            keyWindow = UIApplication.sharedApplication.keyWindow;
        }
        if (keyWindow) {
            targetController = keyWindow.rootViewController;
            while (targetController.presentedViewController) {
                targetController = targetController.presentedViewController;
            }
        }
    }

    if (!targetController) {
        NSLog(@"[BHTwitter Translate] Error: Could not find a suitable view controller to get tweet context.");
        return;
    }

    NSString *textToTranslate = [self BHT_extractTextFromStatusObjectInController:targetController];

    if (!textToTranslate || textToTranslate.length == 0) {
        NSLog(@"[BHTwitter Translate] No tweet text found for VC: %@. Displaying fallback message.", NSStringFromClass([targetController class]));
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Translation Error" 
                                                                       message:@"Could not find tweet text to translate." 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [targetController presentViewController:alert animated:YES completion:nil];
    } else {
        NSLog(@"[BHTwitter Translate] Text to translate: '%@' (from VC: %@)", textToTranslate, NSStringFromClass([targetController class]));
        
        // Call the GeminiTranslator with the extracted text
        [[GeminiTranslator sharedInstance] translateText:textToTranslate 
                                           fromLanguage:@"auto" 
                                             toLanguage:@"en" 
                                             completion:^(NSString *translatedText, NSError *error) {
            if (error || !translatedText) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Translation Error" 
                                                                               message:error ? error.localizedDescription : @"Failed to translate text." 
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [targetController presentViewController:alert animated:YES completion:nil];
                return;
            }
            
            // Show translation with Copy and Cancel options
            UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"Translation" 
                                                                                 message:translatedText 
                                                                          preferredStyle:UIAlertControllerStyleAlert];
            
            [resultAlert addAction:[UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = translatedText;
            }]];
            
            [resultAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            
            [targetController presentViewController:resultAlert animated:YES completion:nil];
        }];
    }
}

%new - (TFNTwitterStatus *)BHT_findStatusObjectInController:(UIViewController *)controller {
    if (!controller || !controller.isViewLoaded) {
        return nil;
    }
    
    // First, if the controller is T1ConversationContainerViewController, we need to find its T1URTViewController child
    if ([NSStringFromClass([controller class]) isEqualToString:@"T1ConversationContainerViewController"]) {
        NSLog(@"[BHTwitter Translate] Found container controller, searching for T1URTViewController...");
        for (UIViewController *childVC in controller.childViewControllers) {
            if ([NSStringFromClass([childVC class]) isEqualToString:@"T1URTViewController"]) {
                NSLog(@"[BHTwitter Translate] Found T1URTViewController, switching target");
                controller = childVC;
                break;
            }
        }
    }
    
    // Try to directly access the status from the view controller
    if ([controller respondsToSelector:@selector(viewModel)]) {
        id viewModel = [controller valueForKey:@"viewModel"];
        
        // If it's a T1URTViewController, we need to handle it specially
        if ([NSStringFromClass([controller class]) isEqualToString:@"T1URTViewController"]) {
            NSLog(@"[BHTwitter Translate] Extracting from T1URTViewController.viewModel");
            @try {
                // Inspect the view model or try to access specific properties
                if ([viewModel respondsToSelector:@selector(statusViewModel)]) {
                    id statusViewModel = [viewModel valueForKey:@"statusViewModel"];
                    if (statusViewModel && [statusViewModel respondsToSelector:@selector(status)]) {
                        id status = [statusViewModel valueForKey:@"status"];
                        if (status && [status isKindOfClass:%c(TFNTwitterStatus)]) {
                            NSLog(@"[BHTwitter Translate] Found TFNTwitterStatus from T1URTViewController.viewModel.statusViewModel.status");
                            return status;
                        }
                    }
                }
                
                // Try another common pattern
                if ([viewModel respondsToSelector:@selector(item)]) {
                    id item = [viewModel valueForKey:@"item"];
                    if ([item respondsToSelector:@selector(status)]) {
                        id status = [item valueForKey:@"status"];
                        if (status && [status isKindOfClass:%c(TFNTwitterStatus)]) {
                            NSLog(@"[BHTwitter Translate] Found TFNTwitterStatus from T1URTViewController.viewModel.item.status");
                            return status;
                        }
                    }
                }
            } @catch (NSException *e) {
                NSLog(@"[BHTwitter Translate] Exception accessing T1URTViewController viewModel: %@", e);
            }
        }
        
        // Generic approach - check if viewModel has status directly
        if ([viewModel respondsToSelector:@selector(status)]) {
            id status = [viewModel valueForKey:@"status"];
            if (status && [status isKindOfClass:%c(TFNTwitterStatus)]) {
                NSLog(@"[BHTwitter Translate] Found TFNTwitterStatus from controller.viewModel.status");
                return status;
            }
        }
    }
    
    // Fallback to looking for T1StatusBodyTextView for other controllers
    T1StatusBodyTextView *bodyTextView = nil;
    NSMutableArray *viewsToCheck = [NSMutableArray arrayWithObject:controller.view];
    
    while (viewsToCheck.count > 0) {
        UIView *currentView = viewsToCheck[0];
        [viewsToCheck removeObjectAtIndex:0];
        
        if ([currentView isKindOfClass:%c(T1StatusBodyTextView)]) {
            bodyTextView = (T1StatusBodyTextView *)currentView;
            break;
        }
        
        [viewsToCheck addObjectsFromArray:currentView.subviews];
    }
    
    // Extract status from bodyTextView
    if (bodyTextView) {
        @try {
            id viewModel = [bodyTextView valueForKey:@"viewModel"];
            if (viewModel && [viewModel respondsToSelector:@selector(status)]) {
                id status = [viewModel valueForKey:@"status"];
                if (status && [status isKindOfClass:%c(TFNTwitterStatus)]) {
                    NSLog(@"[BHTwitter Translate] Found TFNTwitterStatus from T1StatusBodyTextView");
                    return status;
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[BHTwitter Translate] Exception: %@", e);
        }
    }
    
    NSLog(@"[BHTwitter Translate] Failed to find TFNTwitterStatus in controller: %@", NSStringFromClass([controller class]));
    return nil;
}

// Helper function for finding the text view
static void findTextView(UIView *view, UITextView **tweetTextView) {
    // Check for TTAStatusBodySelectableContextTextView or any UITextView in T1URTViewController
    if ([NSStringFromClass([view class]) isEqualToString:@"TTAStatusBodySelectableContextTextView"] ||
        [view isKindOfClass:[UITextView class]]) {
        *tweetTextView = (UITextView *)view;
        NSLog(@"[BHTwitter Translate] Found text view: %@", NSStringFromClass([view class]));
        return;
    }
    
    // Recurse into subviews
    for (UIView *subview in view.subviews) {
        if (!*tweetTextView) {
            findTextView(subview, tweetTextView);
        }
    }
}

%new - (NSString *)BHT_extractTextFromStatusObjectInController:(UIViewController *)controller {
    // Don't limit to specific view controllers - search everywhere
    NSLog(@"[BHTwitter Translate] Searching for tweet text in %@", NSStringFromClass([controller class]));
    
    // First, try to find the T1URTViewController
    UIViewController *urtViewController = nil;
    
    // Check if the current controller is a T1URTViewController
    if ([NSStringFromClass([controller class]) isEqualToString:@"T1URTViewController"]) {
        urtViewController = controller;
        NSLog(@"[BHTwitter Translate] Found T1URTViewController directly");
    }
    
    // If not found, look through the view hierarchy for a T1URTViewController
    if (!urtViewController) {
        UIViewController *currentVC = controller;
        
        // First check child view controllers
        NSArray *childVCs = [currentVC childViewControllers];
        for (UIViewController *childVC in childVCs) {
            if ([NSStringFromClass([childVC class]) isEqualToString:@"T1URTViewController"]) {
                urtViewController = childVC;
                NSLog(@"[BHTwitter Translate] Found T1URTViewController in children");
                break;
            }
        }
        
        // Then check parent view controllers if not found
        if (!urtViewController) {
            while (currentVC.parentViewController) {
                currentVC = currentVC.parentViewController;
                
                if ([NSStringFromClass([currentVC class]) isEqualToString:@"T1URTViewController"]) {
                    urtViewController = currentVC;
                    NSLog(@"[BHTwitter Translate] Found T1URTViewController in parent hierarchy");
                    break;
                }
                
                // Also check siblings
                for (UIViewController *childVC in [currentVC childViewControllers]) {
                    if ([NSStringFromClass([childVC class]) isEqualToString:@"T1URTViewController"]) {
                        urtViewController = childVC;
                        NSLog(@"[BHTwitter Translate] Found T1URTViewController in sibling");
                        break;
                    }
                }
                
                if (urtViewController) break;
            }
        }
    }
    
    // If we found T1URTViewController, extract text from it
    if (urtViewController && urtViewController.isViewLoaded) {
        NSLog(@"[BHTwitter Translate] Found T1URTViewController, searching for text");
        UITextView *tweetTextView = nil;
        findTextView(urtViewController.view, &tweetTextView);
        
        if (tweetTextView) {
            NSString *tweetText = tweetTextView.text;
            if (tweetText && tweetText.length > 0) {
                NSLog(@"[BHTwitter Translate] Got tweet text from T1URTViewController: %@", tweetText);
                return tweetText;
            }
        }
    }
    
    // Fallback: Get the root view controller to search the entire hierarchy
    UIViewController *rootVC = controller;
    while (rootVC.parentViewController) {
        rootVC = rootVC.parentViewController;
    }
    
    // Find text view in the entire view hierarchy
    UITextView *tweetTextView = nil;
    
    // Start search from root view controller's view
    if (rootVC.isViewLoaded) {
        findTextView(rootVC.view, &tweetTextView);
    }
    
    if (tweetTextView) {
        // Get the text directly from the UITextView
        NSString *tweetText = tweetTextView.text;
        if (tweetText && tweetText.length > 0) {
            NSLog(@"[BHTwitter Translate] Got tweet text directly: %@", tweetText);
            return tweetText;
        }
    }
    
    // As a backup, search child view controllers explicitly
    if (!tweetTextView && [rootVC respondsToSelector:@selector(childViewControllers)]) {
        for (UIViewController *childVC in rootVC.childViewControllers) {
            NSLog(@"[BHTwitter Translate] Searching child VC: %@", NSStringFromClass([childVC class]));
            if (childVC.isViewLoaded) {
                findTextView(childVC.view, &tweetTextView);
                if (tweetTextView) break;
            }
        }
    }
    
    if (tweetTextView) {
        // Get the text directly from the UITextView
        NSString *tweetText = tweetTextView.text;
        if (tweetText && tweetText.length > 0) {
            NSLog(@"[BHTwitter Translate] Got tweet text directly from child VC: %@", tweetText);
            return tweetText;
        }
    }
    
    NSLog(@"[BHTwitter Translate] Could not find any text in T1URTViewController or elsewhere");
    return nil;
}



%end

@implementation GeminiTranslator

static GeminiTranslator *_sharedInstance;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[GeminiTranslator alloc] init];
    });
    return _sharedInstance;
}

- (void)translateText:(NSString *)text fromLanguage:(NSString *)sourceLanguage toLanguage:(NSString *)targetLanguage completion:(void (^)(NSString *translatedText, NSError *error))completion {
    @try {
        // Defensive check for empty text
        if (!text || text.length == 0) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"GeminiTranslator" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Empty text to translate"}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }
            return;
        }
        
        // Get configurable API settings from BHTManager
        NSString *apiKey = [BHTManager translateAPIKey];
        NSString *apiUrl = [BHTManager translateEndpoint];
        
        // Check if we have a valid API key
        if (!apiKey || apiKey.length == 0 || [apiKey isEqualToString:@"YOUR_API_KEY"]) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"GeminiTranslator" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Invalid or missing API key"}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }
            return;
        }
        
        // Construct the request URL with API key
        NSString *fullUrlString = [NSString stringWithFormat:@"%@?key=%@", apiUrl, apiKey];
        NSURL *url = [NSURL URLWithString:fullUrlString];
        
        // Create request
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        // Simplified prompt for translation only
        NSString *prompt = [NSString stringWithFormat:@"Translate this text from %@ to %@: \"%@\" \n\nOnly return the translated text without any explanation or notes.", 
                            [sourceLanguage isEqualToString:@"auto"] ? @"the original language" : sourceLanguage, 
                            targetLanguage, 
                            text];
        
        // Create JSON payload
        NSDictionary *content = @{
            @"parts": @[
                @{@"text": prompt}
            ]
        };
        
        NSDictionary *payload = @{
            @"contents": @[content],
            @"generationConfig": @{
                @"temperature": @0.2,
                @"topP": @0.8,
                @"topK": @40
            }
        };
        
        // Serialize to JSON
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
        
        if (jsonError) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, jsonError);
                });
            }
            return;
        }
        
        [request setHTTPBody:jsonData];
        
        // Create and start task
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil, error);
                    });
                }
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = [NSString stringWithFormat:@"API request failed with status code: %ld", (long)httpResponse.statusCode];
                if (data) {
                    // Try to parse error details from response
                    NSDictionary *errorInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if (errorInfo[@"error"] && errorInfo[@"error"][@"message"]) {
                        errorMsg = [NSString stringWithFormat:@"%@: %@", errorMsg, errorInfo[@"error"][@"message"]];
                    }
                }
                
                NSError *apiError = [NSError errorWithDomain:@"GeminiTranslator" code:httpResponse.statusCode userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil, apiError);
                    });
                }
                return;
            }
            
            // Handle successful response
            if (data) {
                NSError *parseError;
                NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
                
                if (parseError) {
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(nil, parseError);
                        });
                    }
                    return;
                }
                
                // Extract the translation text from the response
                NSString *translatedText = @"";
                if (responseDict[@"candidates"] && [responseDict[@"candidates"] isKindOfClass:[NSArray class]]) {
                    NSArray *candidates = responseDict[@"candidates"];
                    if (candidates.count > 0 && candidates[0][@"content"] && candidates[0][@"content"][@"parts"]) {
                        NSArray *parts = candidates[0][@"content"][@"parts"];
                        if (parts.count > 0 && parts[0][@"text"]) {
                            translatedText = parts[0][@"text"];
                            // Clean up any lingering quotes from the API's response
                            translatedText = [translatedText stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\"' \n"]];
                        }
                    }
                }
                
                if (translatedText.length > 0) {
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(translatedText, nil);
                        });
                    }
                } else {
                    NSError *noTextError = [NSError errorWithDomain:@"GeminiTranslator" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Could not parse translation from API response"}];
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(nil, noTextError);
                        });
                    }
                }
            } else {
                NSError *noDataError = [NSError errorWithDomain:@"GeminiTranslator" code:500 userInfo:@{NSLocalizedDescriptionKey: @"No data received from API"}];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil, noDataError);
                    });
                }
            }
        }];
        
        [task resume];
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"GeminiTranslator" code:500 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Translation failed with exception: %@", exception.reason]}];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
    }
}

- (void)simplifiedTranslateAndDisplay:(NSString *)text fromViewController:(UIViewController *)viewController {
    if (!text || text.length == 0 || !viewController) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Translation Error" 
                                                                       message:@"No valid text to translate." 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [viewController presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    [self translateText:text 
           fromLanguage:@"auto" 
             toLanguage:@"en" 
             completion:^(NSString *translatedText, NSError *error) {
        if (error || !translatedText) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Translation Error" 
                                                                           message:error ? error.localizedDescription : @"Failed to translate text." 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [viewController presentViewController:alert animated:YES completion:nil];
            return;
        }
        
        // Show translation with Copy and Cancel options
        UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"Translation" 
                                                                             message:translatedText 
                                                                      preferredStyle:UIAlertControllerStyleAlert];
        
        [resultAlert addAction:[UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            UIPasteboard.generalPasteboard.string = translatedText;
        }]];
        
        [resultAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        
        [viewController presentViewController:resultAlert animated:YES completion:nil];
    }];
}

@end

// No custom interface declarations needed - we'll use selectors

// MARK: Restore Launch Animation

// Add interface for T1AppLaunchTransition
@interface T1AppLaunchTransition : NSObject
@property(retain, nonatomic) UIView *hostView;
@property(retain, nonatomic) UIView *blueBackgroundView;
@property(retain, nonatomic) UIView *whiteBackgroundView;
- (void)runLaunchTransition;
@end

%hook T1AppDelegate
+ (id)launchTransitionProvider {
    id originalProvider = %orig;
    
    // Only create a new provider if the original is null (newer Twitter versions)
    if (!originalProvider) {
        Class T1AppLaunchTransitionClass = NSClassFromString(@"T1AppLaunchTransition");
        if (T1AppLaunchTransitionClass) {
            id provider = [[T1AppLaunchTransitionClass alloc] init];
            return provider;
        }
    }
    return originalProvider;
}

%end
