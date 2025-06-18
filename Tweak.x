//
//  Tweak.x
//  BHTwitter/NeoFreeBird
//
//  Created by BandarHelal
//  Modified by nyaathea
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h> // For objc_msgSend and objc_msgSend_stret
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
#import <dlfcn.h>
#import "SAMKeychain/AuthViewController.h"
#import "Colours/Colours.h"
#import "BHTManager.h"
#import <math.h>
#import "BHTBundle/BHTBundle.h"
#import "TWHeaders.h"
#import "SAMKeychain/SAMKeychain.h"
#import "CustomTabBar/BHCustomTabBarUtility.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "ModernSettingsViewController.h"

@class T1SettingsViewController;

// Declare topViewController to silence compiler warnings, as it's a private API.
@interface T1AppDelegate (BHTwitter)
@property (nonatomic, readonly) UIViewController *topViewController;
@end


// Forward declarations
static void BHT_UpdateAllTabBarIcons(void);
static void BHT_applyThemeToWindow(UIWindow *window);
static void BHT_ensureTheming(void);
static void BHT_forceRefreshAllWindowAppearances(void);
static void BHT_ensureThemingEngineSynchronized(BOOL forceSynchronize);
static UIViewController* getViewControllerForView(UIView *view);

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

// MARK: imports to hook into Twitters TAE color system

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

// Helper function to get Twitter's current dark mode state
static BOOL BHT_isTwitterDarkThemeActive() {
    Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
    if (!TAEColorSettingsCls) {
        if (@available(iOS 13.0, *)) {
            return UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        }
        return NO; // Default to light mode if essential classes are missing
    }

    id settings = [TAEColorSettingsCls sharedSettings];
    if (!settings || ![settings respondsToSelector:@selector(currentColorPalette)]) {
        if (@available(iOS 13.0, *)) {
            return UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        }
        return NO;
    }
    
    id currentPaletteContainer = [settings currentColorPalette]; // This is TAEThemeColorPalette
    // TAETwitterColorPaletteSettingInfo is returned by [TAEThemeColorPalette colorPalette]
    if (!currentPaletteContainer || ![currentPaletteContainer respondsToSelector:@selector(colorPalette)]) { 
         if (@available(iOS 13.0, *)) {
            return UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        }
        return NO;
    }

    id actualPaletteInfo = [currentPaletteContainer colorPalette]; 
    if (actualPaletteInfo && [actualPaletteInfo respondsToSelector:@selector(isDark)]) {
        // Use objc_msgSend to call the isDark method
        return ((BOOL (*)(id, SEL))objc_msgSend)(actualPaletteInfo, @selector(isDark));
    }

    // Fallback to system trait if Twitter's internal state is inaccessible
    if (@available(iOS 13.0, *)) {
        return UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
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

// MARK: - Core TAE Color hooks
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
    if ([NSUserDefaults.standardUserDefaults objectForKey:@"bh_color_theme_selectedColor"] && 
        !BHT_isInThemeChangeOperation && 
        [BHTManager classicTabBarEnabled]) {
        // This call happens after Twitter has applied its color changes,
        // so we need to refresh our tab bar theming
        dispatch_async(dispatch_get_main_queue(), ^{
            BHT_UpdateAllTabBarIcons();
        });
    }
}

%end

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
    if ([NSUserDefaults.standardUserDefaults objectForKey:@"bh_color_theme_selectedColor"] && 
        [BHTManager classicTabBarEnabled]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BHT_UpdateAllTabBarIcons();
        });
    }
}

%end

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

// MARK: App Delegate hooks
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
    NSLog(@"[BHTwitter] applicationDidBecomeActive - START");
    %orig;
    NSLog(@"[BHTwitter] applicationDidBecomeActive - orig called");
    
    // Re-apply theme on becoming active - simpler with our new management system
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        NSLog(@"[BHTwitter] applicationDidBecomeActive - applying theme");
        BHT_ensureThemingEngineSynchronized(YES);
    }

    // Initialize cookies if tweet labels are enabled
    if ([BHTManager RestoreTweetLabels]) {
        NSLog(@"[BHTwitter] applicationDidBecomeActive - initializing cookies");
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"[BHTwitter] applicationDidBecomeActive - calling initializeCookiesWithRetry");
            [TweetSourceHelper initializeCookiesWithRetry];
        });
    }
    NSLog(@"[BHTwitter] applicationDidBecomeActive - END");

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
    
    // Clean up source label timers to prevent crashes
    if ([BHTManager RestoreTweetLabels]) {
        [TweetSourceHelper cleanupTimersForBackground];
    }
    
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

- (_Bool)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    if ([[url scheme] isEqualToString:@"twitter"] && [[url host] isEqualToString:@"neofreebird"]) {
        
        // Use the established helper method from BHTManager to get the top-most view controller.
        UIViewController *topController = topMostController();
        
        UINavigationController *navController = nil;

        // Find the navigation controller from the top-most view controller.
        if ([topController isKindOfClass:[UINavigationController class]]) {
            navController = (UINavigationController *)topController;
        } else {
            navController = topController.navigationController;
        }

        if (navController) {
            TFNTwitterAccount *account = nil;
            // Safely get the current account from the app delegate.
            if ([self respondsToSelector:@selector(_t1_currentAccount)]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                account = [self performSelector:@selector(_t1_currentAccount)];
                #pragma clang diagnostic pop
            }
            
            ModernSettingsViewController *settingsVC = [[ModernSettingsViewController alloc] initWithAccount:account];
            
            // Prevent pushing the same view controller twice.
            if (![navController.topViewController isKindOfClass:[ModernSettingsViewController class]]) {
                [navController pushViewController:settingsVC animated:YES];
            }
            return YES; // We handled the URL.
        }
    }
    
    // If we didn't handle the URL, pass it to the original implementation.
    return %orig;
}
%end

// MARK: prevent tab bar fade 
%hook T1TabBarViewController

- (void)setTabBarScrolling:(BOOL)scrolling {
    if ([BHTManager stopHidingTabBar]) {
        %orig(NO); // Force scrolling to NO if fading is prevented
    } else {
        %orig(scrolling);
    }
}

- (void)loadView {
    %orig;
    NSArray <NSString *> *hiddenBars = [BHCustomTabBarUtility getHiddenTabBars];
    for (T1TabView *tabView in self.tabViews) {
        if ([hiddenBars containsObject:tabView.scribePage]) {
            [tabView setHidden:true];
        }
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

// MARK: Show unrounded follower/following counts
%hook T1ProfileFriendsFollowingViewModel
- (id)_t1_followCountTextWithLabel:(id)label singularLabel:(id)singularLabel count:(id)count highlighted:(_Bool)highlighted {
    // First get the original result to understand the expected return type
    id originalResult = %orig;
    
    // Only proceed if we have a valid count that's an NSNumber
    if (count && [count isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)count;
        
        // Only show full numbers for counts under 10,000
        if ([number integerValue] >= 10000) {
            return originalResult;
        }
        
        // Format the number with the current locale's formatting
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [formatter setUsesGroupingSeparator:YES];
        NSString *formattedCount = [formatter stringFromNumber:number];
        
        // If original result is an NSString, find and replace abbreviated numbers
        if ([originalResult isKindOfClass:[NSString class]]) {
            NSString *originalString = (NSString *)originalResult;
            // Updated regex to match patterns like "1.7K", "1,7K", "6.2K", "6,2K", etc.
            // This handles both period and comma as decimal separators
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+[.,]\\d+[KMB]|\\d+[KMB]" options:0 error:nil];
            NSString *result = [regex stringByReplacingMatchesInString:originalString options:0 range:NSMakeRange(0, originalString.length) withTemplate:formattedCount];
            return result;
        }
        // If original result is an NSAttributedString, modify that
        else if ([originalResult isKindOfClass:[NSAttributedString class]]) {
            NSMutableAttributedString *mutableResult = [[NSMutableAttributedString alloc] initWithAttributedString:(NSAttributedString *)originalResult];
            NSString *originalText = mutableResult.string;
            
            // Updated regex to match patterns like "1.7K", "1,7K", "6.2K", "6,2K", etc.
            // This handles both period and comma as decimal separators
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+[.,]\\d+[KMB]|\\d+[KMB]" options:0 error:nil];
            NSArray *matches = [regex matchesInString:originalText options:0 range:NSMakeRange(0, originalText.length)];
            
            // Replace matches in reverse order to maintain correct indices
            for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
                [mutableResult replaceCharactersInRange:match.range withString:formattedCount];
            }
            return [mutableResult copy];
        }
    }
    return originalResult;
}
%end

// MARK: hide ADS - New Implementation
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
            // Hide all EventSummaryViewModel items, not just promoted ones
            [_orig setHidden:true];
        }
        if ([BHTManager HidePromoted] && [class_name isEqualToString:@"TwitterURT.URTTimelineTrendViewModel"]) {
            _TtC10TwitterURT25URTTimelineTrendViewModel *trendModel = tweet;
            if ([[trendModel.scribeItem allKeys] containsObject:@"promoted_id"]) {
                [_orig setHidden:true];
            }
        }
        if ([BHTManager hideTrendVideos] && ([class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"T1TwitterSwift.URTTimelineCarouselViewModel"])) {
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

        if ([BHTManager hideWhoToFollow]) {
            if ([class_name isEqualToString:@"T1URTTimelineUserItemViewModel"] || [class_name isEqualToString:@"T1TwitterSwift.URTTimelineCarouselViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"]) {
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
            // Hide all EventSummaryViewModel items, not just promoted ones
            return 0;
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

        if ([BHTManager hideWhoToFollow]) {
            if ([class_name isEqualToString:@"T1URTTimelineUserItemViewModel"] || [class_name isEqualToString:@"T1TwitterSwift.URTTimelineCarouselViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleHeaderViewModel"] || [class_name isEqualToString:@"TwitterURT.URTModuleFooterViewModel"]) {
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

// MARK: Save tweet as an image

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

// MARK: Timeline download

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

// MARK: Always open in Safari

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

- (instancetype)initWithURL:(NSURL *)URL configuration:(SFSafariViewControllerConfiguration *)configuration {
    if (![BHTManager alwaysOpenSafari]) {
        return %orig;
    }
    
    NSString *urlStr = [URL absoluteString];
    
    // In-app browser is used for two-factor authentication with security key,
    // login will not complete successfully if it's redirected to Safari
    if ([urlStr containsString:@"twitter.com/account/"] || [urlStr containsString:@"twitter.com/i/flow/"]) {
        return %orig;
    }
    
    // Open in Safari instead and return nil to prevent SFSafariViewController creation
    [[UIApplication sharedApplication] openURL:URL options:@{} completionHandler:nil];
    return nil;
}

- (instancetype)initWithURL:(NSURL *)URL {
    if (![BHTManager alwaysOpenSafari]) {
        return %orig;
    }
    
    NSString *urlStr = [URL absoluteString];
    
    // In-app browser is used for two-factor authentication with security key,
    // login will not complete successfully if it's redirected to Safari
    if ([urlStr containsString:@"twitter.com/account/"] || [urlStr containsString:@"twitter.com/i/flow/"]) {
        return %orig;
    }
    
    // Open in Safari instead and return nil to prevent SFSafariViewController creation
    [[UIApplication sharedApplication] openURL:URL options:@{} completionHandler:nil];
    return nil;
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
    
    if ([key isEqualToString:@"grok_ios_profile_summary_enabled"] || [key isEqualToString:@"creator_monetization_dashboard_enabled"] || [key isEqualToString:@"creator_monetization_profile_subscription_tweets_tab_enabled"] || [key isEqualToString:@"creator_purchases_dashboard_enabled"]) {
        return false;
    }
    
    if ([key isEqualToString:@"subscriptions_verification_info_is_identity_verified"] || [key isEqualToString:@"subscriptions_verification_info_reason_enabled"] || [key isEqualToString:@"subscriptions_verification_info_verified_since_enabled"]) {
        return false;
    }

    if ([key isEqualToString:@"articles_timeline_profile_tab_enabled"]) {
        return ![BHTManager disableArticles];
    }

    if ([key isEqualToString:@"ios_dm_dash_enabled"]) {
        return ![BHTManager disableXChat];
    }

    if ([key isEqualToString:@"highlights_tweets_tab_ui_enabled"]) {
        return ![BHTManager disableHighlights];
    }

    if ([key isEqualToString:@"media_tab_profile_videos_tab_enabled"] || [key isEqualToString:@"media_tab_profile_photos_tab_enabled"]) {
        return ![BHTManager disableMediaTab];
    }

    if ([key isEqualToString:@"communities_enable_explore_tab"] || [key isEqualToString:@"subscriptions_settings_item_enabled"]) {
        return false;
    }

    if ([key isEqualToString:@"dash_items_download_grok_enabled"]) {
        return false;
    }
    
    if ([key isEqualToString:@"conversational_replies_ios_minimal_detail_enabled"]) {
        return ![BHTManager OldStyle];
    }
    
    if ([key isEqualToString:@"dm_compose_bar_v2_enabled"]) {
        return ![BHTManager dmComposeBarV2];
    }

    if ([key isEqualToString:@"reply_sorting_enabled"]) {
        return ![BHTManager replySorting];
    }

    if ([key isEqualToString:@"dm_voice_creation_enabled"]) {
        return ![BHTManager dmVoiceCreation];
    }

    if ([key isEqualToString:@"ios_tweet_detail_overflow_in_navigation_enabled"]) {
        return false;
    }

    if ([key isEqualToString:@"ios_subscription_journey_enabled"]) {
        return false;
    }

    if ([key isEqualToString:@"ios_tweet_detail_conversation_context_removal_enabled"]) {
        return ![BHTManager restoreReplyContext];
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
- (_Bool)isXChatEnabled {
    return [BHTManager disableXChat] ? false : %orig;
}
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
        
        // Use Twitter's internal vector image system to get the Twitter bird icon
        UIImage *twitterIcon = nil;
        
        // Choose color based on interface style
        UIColor *iconColor;
        if (@available(iOS 12.0, *)) {
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                iconColor = [UIColor systemGray2Color];
            } else {
                iconColor = [UIColor secondaryLabelColor];
            }
        } else {
            iconColor = [UIColor secondaryLabelColor];
        }
        
        // Twitter vector image
        twitterIcon = [UIImage tfn_vectorImageNamed:@"twitter" fitsSize:CGSizeMake(20, 20) fillColor:iconColor];
        
        // Create the settings item
        TFNSettingsNavigationItem *bhtwitter = [[%c(TFNSettingsNavigationItem) alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_TITLE"] detail:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_DETAIL"] iconName:nil controllerFactory:^UIViewController *{
            return [BHTManager BHTSettingsWithAccount:self.account];
        }];
        
        // Set our Twitter icon
        if (twitterIcon) {
            [bhtwitter setValue:twitterIcon forKey:@"_icon"];
        }
        
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
    if (indexPath.section == 0 && indexPath.row == 1) {
        
        TFNTextCell *Tweakcell = [[%c(TFNTextCell) alloc] init];
        [Tweakcell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [Tweakcell.textLabel setText:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_DETAIL"]];
        return Tweakcell;
    } else if (indexPath.section == 0 && indexPath.row == 0) {
        
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

// start of NFB features

// MARK: Restore Source Labels - This is still pretty experimental and may break. This restores Tweet Source Labels by using an Legacy API. by: @nyaathea

static NSMutableDictionary *tweetSources      = nil;
static NSMutableDictionary *viewToTweetID     = nil;
static NSMutableDictionary *fetchTimeouts     = nil;
static NSMutableDictionary *viewInstances     = nil;
static NSMutableDictionary *fetchRetries      = nil;
static NSMutableDictionary *updateRetries      = nil;
static NSMutableDictionary *updateCompleted   = nil;
static NSMutableDictionary *fetchPending      = nil;
static NSMutableDictionary *cookieCache       = nil;
static NSDate *lastCookieRefresh              = nil;

// Add a dispatch queue for thread-safe access to shared data
static dispatch_queue_t sourceLabelDataQueue = nil;

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

@implementation TweetSourceHelper

+ (void)logDebugInfo:(NSString *)message {
    // Only log in debug mode to reduce log spam
#if BHT_DEBUG
    if (message) {
    }
#endif
}

+ (void)initializeCookiesWithRetry {
    // Simplified initialization - just load hardcoded cookies
    isInitializingCookies = YES;
    
    NSDictionary *hardcodedCookies = [self fetchCookies];
    [self cacheCookies:hardcodedCookies];
    
    isInitializingCookies = NO;
}

+ (void)retryFetchCookies {
    // No need to retry with hardcoded cookies - just call initialize
    [self initializeCookiesWithRetry];
}

+ (void)pruneSourceCachesIfNeeded {
    // This is a write operation, use a barrier
    dispatch_barrier_async(sourceLabelDataQueue, ^{
        if (!tweetSources) return;
        
        __block NSUInteger count = 0;
        count = tweetSources.count;

        if (count > MAX_SOURCE_CACHE_SIZE) {
            [self logDebugInfo:[NSString stringWithFormat:@"Pruning cache with %ld entries", (long)count]];
            
            NSMutableArray *keysToRemove = [NSMutableArray array];
            
            [tweetSources enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (!obj || [obj isEqualToString:@""] || [obj isEqualToString:@"Source Unavailable"]) {
                    [keysToRemove addObject:key];
                    if (keysToRemove.count >= count / 4) *stop = YES;
                }
            }];
            
            if (keysToRemove.count < count / 5) {
                NSArray *allKeys = [tweetSources allKeys];
                for (int i = 0; i < 20 && keysToRemove.count < count / 4; i++) {
                    NSString *randomKey = allKeys[arc4random_uniform((uint32_t)allKeys.count)];
                    if (![keysToRemove containsObject:randomKey]) {
                        [keysToRemove addObject:randomKey];
                    }
                }
            }
            
            [self logDebugInfo:[NSString stringWithFormat:@"Removing %ld cache entries", (long)keysToRemove.count]];
            
            for (NSString *key in keysToRemove) {
                [tweetSources removeObjectForKey:key];
                
                NSTimer *timeoutTimer = fetchTimeouts[key];
                if (timeoutTimer) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [timeoutTimer invalidate];
                    });
                    [fetchTimeouts removeObjectForKey:key];
                }
                [fetchRetries removeObjectForKey:key];
                [updateRetries removeObjectForKey:key];
                [updateCompleted removeObjectForKey:key];
                [fetchPending removeObjectForKey:key];
            }
        }
    });
}

+ (NSDictionary *)fetchCookies {
    // First try to get real cookies from the user's actual account
    NSMutableDictionary *realCookies = [NSMutableDictionary dictionary];
    NSArray *domains = @[@"api.twitter.com", @".twitter.com", @"x.com", @"api.x.com"];
    NSArray *requiredCookies = @[@"ct0", @"auth_token"];
    
    for (NSString *domain in domains) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", domain]];
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url];
        for (NSHTTPCookie *cookie in cookies) {
            if ([requiredCookies containsObject:cookie.name]) {
                realCookies[cookie.name] = cookie.value;
            }
        }
    }
    
    // Check if we have valid real cookies
    BOOL hasValidRealCookies = realCookies.count > 0 && 
                               realCookies[@"ct0"] && realCookies[@"auth_token"] &&
                               [realCookies[@"ct0"] length] > 10 && 
                               [realCookies[@"auth_token"] length] > 10;
    
    if (hasValidRealCookies) {
        [self logDebugInfo:@"Using real user cookies"];
        return [realCookies copy];
    } else {
        // Fall back to hardcoded cookies for reliability
        [self logDebugInfo:@"Falling back to hardcoded alt cookies"];
        return @{
            @"ct0": @"91cc6876b96a35f91adeedc4ef149947c4d58907ca10fc2b17f64b17db0cccfb714ae61ede34cf34866166dcaf8e1c3a86085fa35c41aacc3e3927f7aa1f9b850b49139ad7633344059ff04af302d5d3",
            @"auth_token": @"71fc90d6010d76ec4473b3e42c6802a8f1185316",
            @"twid": @"u%3D1930115366878871552"
        };
    }
}

+ (void)cacheCookies:(NSDictionary *)cookies {
    // Simplified caching - just store in memory since we're using hardcoded values
    cookieCache = [cookies mutableCopy];
    lastCookieRefresh = [NSDate date];
}

+ (NSDictionary *)loadCachedCookies {
    // Always return hardcoded cookies
    NSDictionary *hardcodedCookies = [self fetchCookies];
    cookieCache = [hardcodedCookies mutableCopy];
    lastCookieRefresh = [NSDate date];
    return hardcodedCookies;
}

+ (BOOL)shouldRefreshCookies {
    // Allow refresh if we don't have cookies cached, or if we're using real cookies that might expire
    if (!cookieCache || cookieCache.count == 0) {
        return YES;
    }
    
    // Check if we're using real cookies (not hardcoded)
    BOOL usingRealCookies = ![cookieCache[@"ct0"] isEqualToString:@"91cc6876b96a35f91adeedc4ef149947c4d58907ca10fc2b17f64b17db0cccfb714ae61ede34cf34866166dcaf8e1c3a86085fa35c41aacc3e3927f7aa1f9b850b49139ad7633344059ff04af302d5d3"];
    
    if (usingRealCookies && lastCookieRefresh) {
        // Refresh real cookies every 4 hours
        NSTimeInterval timeSinceRefresh = [[NSDate date] timeIntervalSinceDate:lastCookieRefresh];
        return timeSinceRefresh >= (4 * 60 * 60);
    }
    
    // Never refresh hardcoded cookies
    return NO;
}

+ (void)fetchSourceForTweetID:(NSString *)tweetID {
    if (!tweetID) return;
    
    // Defer the entire operation to our concurrent queue to handle state checks and request creation safely
    dispatch_async(sourceLabelDataQueue, ^{
        @try {
            // Initialize dictionaries if needed
            if (!tweetSources) tweetSources = [NSMutableDictionary dictionary];
            if (!fetchTimeouts) fetchTimeouts = [NSMutableDictionary dictionary];
            if (!fetchRetries) fetchRetries = [NSMutableDictionary dictionary];
            if (!fetchPending) fetchPending = [NSMutableDictionary dictionary];

            // Simple cache size management
            if (tweetSources.count > MAX_SOURCE_CACHE_SIZE) {
                // Pruning is now async, so we just call it
                [self pruneSourceCachesIfNeeded];
            }

        // Skip if already pending or has valid result
        if ([fetchPending[tweetID] boolValue] || 
            (tweetSources[tweetID] && ![tweetSources[tweetID] isEqualToString:@""] && ![tweetSources[tweetID] isEqualToString:@"Source Unavailable"])) {
            return;
        }

        // Check retry limit
        NSInteger retryCount = [fetchRetries[tweetID] integerValue];
        if (retryCount >= MAX_CONSECUTIVE_FAILURES) {
            tweetSources[tweetID] = @"Source Unavailable";
            return;
        }

        fetchPending[tweetID] = @(YES);
        fetchRetries[tweetID] = @(retryCount + 1);

                // Set simple timeout on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            NSTimer *timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:8.0
                                                                    target:self
                                                                  selector:@selector(timeoutFetchForTweetID:)
                                                                  userInfo:@{@"tweetID": tweetID}
                                                                   repeats:NO];
            dispatch_barrier_async(sourceLabelDataQueue, ^{
                fetchTimeouts[tweetID] = timeoutTimer;
            });
        });

        // Build request
        NSString *urlString = [NSString stringWithFormat:@"https://api.twitter.com/2/timeline/conversation/%@.json?include_ext_alt_text=true&include_reply_count=true&tweet_mode=extended", tweetID];
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            [self handleFetchFailure:tweetID];
            return;
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"GET";
        request.timeoutInterval = 7.0;

        // Get cookies
        if (!cookieCache) {
            [self loadCachedCookies];
        }
        NSDictionary *cookiesToUse = cookieCache;
        
        // Check if using real cookies
        BOOL usingRealCookies = cookiesToUse && 
                               ![cookiesToUse[@"ct0"] isEqualToString:@"91cc6876b96a35f91adeedc4ef149947c4d58907ca10fc2b17f64b17db0cccfb714ae61ede34cf34866166dcaf8e1c3a86085fa35c41aacc3e3927f7aa1f9b850b49139ad7633344059ff04af302d5d3"];

        // Build headers
        NSMutableArray *cookieStrings = [NSMutableArray array];
        for (NSString *cookieName in cookiesToUse) {
            [cookieStrings addObject:[NSString stringWithFormat:@"%@=%@", cookieName, cookiesToUse[cookieName]]];
        }

        [request setValue:@"Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA" forHTTPHeaderField:@"Authorization"];
        [request setValue:@"OAuth2Session" forHTTPHeaderField:@"x-twitter-auth-type"];
        [request setValue:@"CFNetwork/1331.0.7 Darwin/25.2.0" forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
        [request setValue:cookiesToUse[@"ct0"] forHTTPHeaderField:@"x-csrf-token"];
        [request setValue:[cookieStrings componentsJoinedByString:@"; "] forHTTPHeaderField:@"Cookie"];

        // Execute request
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            // The completion handler runs on a background thread
            // We must use our queue to modify shared state
            dispatch_barrier_async(sourceLabelDataQueue, ^{
                @try {
                    // Cleanup timeout
                    NSTimer *timer = fetchTimeouts[tweetID];
                    if (timer) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [timer invalidate];
                        });
                        [fetchTimeouts removeObjectForKey:tweetID];
                    }
                    fetchPending[tweetID] = @(NO);

                // Handle errors
                if (error || !data) {
                    [self handleFetchFailure:tweetID];
                    return;
                }

                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                
                // Handle auth errors with fallback
                if ((httpResponse.statusCode == 401 || httpResponse.statusCode == 403) && usingRealCookies && retryCount == 1) {
                    // Try hardcoded cookies once
                    NSDictionary *hardcodedCookies = @{
                        @"ct0": @"91cc6876b96a35f91adeedc4ef149947c4d58907ca10fc2b17f64b17db0cccfb714ae61ede34cf34866166dcaf8e1c3a86085fa35c41aacc3e3927f7aa1f9b850b49139ad7633344059ff04af302d5d3",
                        @"auth_token": @"71fc90d6010d76ec4473b3e42c6802a8f1185316",
                        @"twid": @"u%3D1930115366878871552"
                    };
                                            [self cacheCookies:hardcodedCookies];
                        [self fetchSourceForTweetID:tweetID]; // Re-call, which will be queued
                        return;
                }

                if (httpResponse.statusCode != 200) {
                    [self handleFetchFailure:tweetID];
                    return;
                }

                // Parse JSON
                NSError *jsonError;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (jsonError || !json) {
                    [self handleFetchFailure:tweetID];
                    return;
                }
                
                // Extract source
                NSDictionary *tweets = json[@"globalObjects"][@"tweets"];
                NSDictionary *tweetData = tweets[tweetID];
                    
                // Try alternate ID format if not found
                if (!tweetData) {
                    for (NSString *key in tweets) {
                        if ([key longLongValue] == [tweetID longLongValue]) {
                            tweetData = tweets[key];
                            break;
                        }
                    }
                }
                
                NSString *sourceHTML = tweetData[@"source"];
                NSString *sourceText = @"Unknown Source";

                if (sourceHTML) {
                    NSRange startRange = [sourceHTML rangeOfString:@">"];
                    NSRange endRange = [sourceHTML rangeOfString:@"</a>"];
                    if (startRange.location != NSNotFound && endRange.location != NSNotFound && startRange.location + 1 < endRange.location) {
                        sourceText = [sourceHTML substringWithRange:NSMakeRange(startRange.location + 1, endRange.location - startRange.location - 1)];
                        sourceText = [sourceText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    }
                    }
                    
                // Store and notify
                    tweetSources[tweetID] = sourceText;
                fetchRetries[tweetID] = @(0); // Reset on success
                
                dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
                    [self updateFooterTextViewsForTweetID:tweetID];
                });
                
                            } @catch (NSException *e) {
                    [self handleFetchFailure:tweetID];
                }
            });
        }];
        [task resume];
        
        } @catch (NSException *e) {
            [self handleFetchFailure:tweetID];
        }
    });
}

+ (void)handleFetchFailure:(NSString *)tweetID {
    if (!tweetID) return;
    
    // This is a write operation, but it's called from other synchronized blocks
    // So we don't need to wrap it again, but the caller must be synchronized
    fetchPending[tweetID] = @(NO);
    NSTimer *timer = fetchTimeouts[tweetID];
    if (timer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [timer invalidate];
        });
        [fetchTimeouts removeObjectForKey:tweetID];
    }
        
    NSInteger retryCount = [fetchRetries[tweetID] integerValue];
    if (retryCount < MAX_CONSECUTIVE_FAILURES) {
        // Simple retry after delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), sourceLabelDataQueue, ^{
            [self fetchSourceForTweetID:tweetID];
        });
    } else {
        // Mark as unavailable
        tweetSources[tweetID] = @"Source Unavailable";
        dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetSourceUpdated" object:nil userInfo:@{@"tweetID": tweetID}];
        });
    }
}

+ (void)timeoutFetchForTweetID:(NSTimer *)timer {
    NSString *tweetID = timer.userInfo[@"tweetID"];
    if (!tweetID) return;
    
    dispatch_barrier_async(sourceLabelDataQueue, ^{
        // Safely invalidate timer on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([timer isValid]) {
                [timer invalidate];
            }
        });
        [fetchTimeouts removeObjectForKey:tweetID];
        [self handleFetchFailure:tweetID];
    });
}

+ (void)retryUpdateForTweetID:(NSString *)tweetID {
    // Removed complex retry mechanism
}

+ (void)pollForPendingUpdates {
    // Removed complex polling mechanism
}

+ (void)handleAppForeground:(NSNotification *)notification {
    // Removed complex app foreground handling
}

+ (void)handleClearCacheNotification:(NSNotification *)notification {
    // Simplified cache clearing - just clear the source cache
    if (tweetSources) [tweetSources removeAllObjects];
}

+ (void)cleanupTimersForBackground {
    // Clean up timers to prevent crashes when app resumes
    if (fetchTimeouts) {
        dispatch_barrier_async(sourceLabelDataQueue, ^{
            for (NSTimer *timer in [fetchTimeouts allValues]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([timer isValid]) {
                        [timer invalidate];
                    }
                });
            }
            [fetchTimeouts removeAllObjects];
        });
    }
}

+ (void)updateFooterTextViewsForTweetID:(NSString *)tweetID {
    // Removed notification-based updates
}

@end

%hook TFNTwitterStatus

- (id)init {
    id originalSelf = %orig;
    @try {
        NSInteger statusID = self.statusID;
        if (statusID > 0) {
            NSString *tweetIDStr = @(statusID).stringValue;
            // Write operation
            dispatch_barrier_async(sourceLabelDataQueue, ^{
                if (!tweetSources) tweetSources = [NSMutableDictionary dictionary];
                if (!tweetSources[tweetIDStr]) {
                    [TweetSourceHelper pruneSourceCachesIfNeeded]; // This is async now
                    tweetSources[tweetIDStr] = @"";
                    [TweetSourceHelper fetchSourceForTweetID:tweetIDStr];
                }
            });
        }
    } @catch (__unused NSException *e) {}
    return originalSelf;
}

%end

// Declare the category interface first
@interface TweetSourceHelper (Notifications)
+ (void)handleCookiesReadyNotification:(NSNotification *)notification;
@end

// Simplified implementation without notifications
@implementation TweetSourceHelper (Notifications)
+ (void)handleCookiesReadyNotification:(NSNotification *)notification {
    // Removed complex notification handling - now handled directly in fetchSourceForTweetID
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

                        if (!tweetSources[tweetIDStr]) {
                            tweetSources[tweetIDStr] = @"";
                            [TweetSourceHelper fetchSourceForTweetID:tweetIDStr];
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

                            if (!tweetSources[altID]) {
                                [TweetSourceHelper pruneSourceCachesIfNeeded]; // ADDING THIS CALL HERE
                                tweetSources[altID] = @"";
                                [TweetSourceHelper fetchSourceForTweetID:altID];
                            }
                        }
                    } @catch (__unused NSException *e) {}
                }
            }
        }
    } @catch (__unused NSException *e) {}
}

- (void)dealloc {
    // Removed complex view tracking cleanup
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
        // Removed all notification observers - they were causing crashes
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

// MARK: - Source Labels via T1ConversationFocalStatusView (Clean Approach)

@interface T1ConversationFocalStatusView (BHTSourceLabels)
- (void)BHT_updateFooterTextWithSource:(NSString *)sourceText tweetID:(NSString *)tweetID;
- (void)BHT_applyColoredTextToFooterTextView:(id)footerTextView timeAgoText:(NSString *)timeAgoText sourceText:(NSString *)sourceText;
- (id)footerTextView;
@end

%hook T1ConversationFocalStatusView

- (void)setViewModel:(id)viewModel options:(unsigned long long)options account:(id)account {
    %orig(viewModel, options, account);
    
    if (![BHTManager RestoreTweetLabels] || !viewModel) {
        return;
    }
    
    // Get the TFNTwitterStatus - it might be the viewModel itself or a property
    TFNTwitterStatus *status = nil;
    
    if ([viewModel isKindOfClass:%c(TFNTwitterStatus)]) {
        status = (TFNTwitterStatus *)viewModel;
    } else if ([viewModel respondsToSelector:@selector(status)]) {
        status = [viewModel performSelector:@selector(status)];
    }
    
    if (!status) {
        return;
    }
    
    // Get the tweet ID
    long long statusID = [status statusID];
    if (statusID <= 0) {
        return;
    }
    
    NSString *tweetIDStr = [NSString stringWithFormat:@"%lld", statusID];
    if (!tweetIDStr || tweetIDStr.length == 0) {
                return;
            }

    // Initialize tweet sources if needed
    if (!tweetSources) {
        tweetSources = [NSMutableDictionary dictionary];
    }
    
    // Fetch source if not cached
    if (!tweetSources[tweetIDStr]) {
        tweetSources[tweetIDStr] = @""; // Placeholder
        [TweetSourceHelper fetchSourceForTweetID:tweetIDStr];
    }
    
    // Update footer text immediately if we have the source
    NSString *sourceText = tweetSources[tweetIDStr];
    if (sourceText && sourceText.length > 0 && ![sourceText isEqualToString:@"Source Unavailable"] && ![sourceText isEqualToString:@""]) {
        // Delay the update to ensure the view is fully configured, using a weak reference to self to prevent retain cycles
        __weak __typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf BHT_updateFooterTextWithSource:sourceText tweetID:tweetIDStr];
            }
        });
    }
}

%new
- (void)BHT_updateFooterTextWithSource:(NSString *)sourceText tweetID:(NSString *)tweetID {
    // Look for T1ConversationFooterItem in the view hierarchy
    __block id footerItem = nil;
    BH_EnumerateSubviewsRecursively(self, ^(UIView *view) {
        if (footerItem) return;
        
        // Check if this view has a footerItem property
        if ([view respondsToSelector:@selector(footerItem)]) {
            id item = [view performSelector:@selector(footerItem)];
            if (item && [item isKindOfClass:%c(T1ConversationFooterItem)]) {
                footerItem = item;
            }
        }
    });
    
    if (!footerItem || ![footerItem respondsToSelector:@selector(timeAgo)]) {
        return;
    }

    NSString *currentTimeAgo = [footerItem performSelector:@selector(timeAgo)];
    if (!currentTimeAgo || currentTimeAgo.length == 0) {
                return;
            }

    // Don't append if source is already there
    if ([currentTimeAgo containsString:sourceText] || [currentTimeAgo containsString:@"Twitter for"] || [currentTimeAgo containsString:@"via "]) {
        return;
    }
    
    // Create new timeAgo with source appended
    NSString *newTimeAgo = [NSString stringWithFormat:@"%@ · %@", currentTimeAgo, sourceText];
    
    // Set the new timeAgo and hide view count
    if ([footerItem respondsToSelector:@selector(setTimeAgo:)]) {
        [footerItem performSelector:@selector(setTimeAgo:) withObject:newTimeAgo];
        
        // Hide view count by setting it to nil
        if ([footerItem respondsToSelector:@selector(setViewCount:)]) {
            [footerItem performSelector:@selector(setViewCount:) withObject:nil];
        }
        
        // Now update the footer text view to refresh the display
        id footerTextView = [self footerTextView];
        if (footerTextView && [footerTextView respondsToSelector:@selector(updateFooterTextView)]) {
            [footerTextView performSelector:@selector(updateFooterTextView)];
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
    NSMutableAttributedString *newString = nil;
    BOOL modified = NO;
    
    // Check if this text contains any of our cached source labels
    if (tweetSources && [tweetSources count] > 0) {
        for (NSString *sourceText in [tweetSources allValues]) {
            if (sourceText && sourceText.length > 0 && ![sourceText isEqualToString:@""] && 
                ![sourceText isEqualToString:@"Source Unavailable"] && [currentText containsString:sourceText]) {
                
                // Check if the source text is already colored to avoid redundant updates
                NSRange sourceRange = [currentText rangeOfString:sourceText];
                if (sourceRange.location != NSNotFound) {
                    UIColor *existingColor = [model.attributedString attribute:NSForegroundColorAttributeName 
                                                                       atIndex:sourceRange.location 
                                                                effectiveRange:NULL];
                    UIColor *accentColor = BHTCurrentAccentColor();
                    
                    // Only apply coloring if it's not already colored with our accent color
                    if (!existingColor || ![existingColor isEqual:accentColor]) {
                        newString = [[NSMutableAttributedString alloc] initWithAttributedString:model.attributedString];
                        [newString addAttribute:NSForegroundColorAttributeName 
                                           value:accentColor 
                                           range:sourceRange];
                        modified = YES;
                    }
                    break;
                }
            }
        }
    }
    
    // Handle notification text replacements (your post -> your Tweet, etc.)
    if ([currentText containsString:@"your post"] || [currentText containsString:@"your Post"] ||
        [currentText containsString:@"reposted"] || [currentText containsString:@"Reposted"]) {
            UIView *view = self;
            BOOL isNotificationView = NO;
            
            // Walk up the view hierarchy to find notification context
            while (view && !isNotificationView) {
                if ([NSStringFromClass([view class]) containsString:@"Notification"] ||
                    [NSStringFromClass([view class]) containsString:@"T1NotificationsTimeline"]) {
                    isNotificationView = YES;
                break;
                }
                view = view.superview;
            }
            
            // Only proceed if we're in a notification view
            if (isNotificationView) {
            if (!newString) {
                newString = [[NSMutableAttributedString alloc] initWithAttributedString:model.attributedString];
            }
                
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
        }
    }
    
    // Apply the modified text model if we made any changes
    if (modified && newString) {
                    TFNAttributedTextModel *newModel = [[%c(TFNAttributedTextModel) alloc] initWithAttributedString:newString];
                    %orig(newModel);
        return;
    }
    
    %orig(model);
}
%end

// --- Initialisation ---

// MARK: Bird Icon Theming - Dirty hax for making the Nav Bird Icon themeable again.

%hook UIImageView

- (void)setImage:(UIImage *)image {
    %orig(image);
    
    if (!image) return;
    
    // Check if this is the Twitter bird icon by examining the image's dynamic color name
    if ([image respondsToSelector:@selector(tfn_dynamicColorImageName)]) {
        NSString *imageName = [image performSelector:@selector(tfn_dynamicColorImageName)];
        if ([imageName isEqualToString:@"twitter"]) {
            if (image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
                UIImage *templateImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                self.image = templateImage;
                self.tintColor = BHTCurrentAccentColor();
            }
        }
    }
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

// MARK: - Hide Grok Analyze & Subscribe Buttons on Detail View

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
    @try {
        // Safety check: Ensure view and target are valid
        if (!viewToSearch || !targetAccessibilityId || !viewToSearch.superview) {
            return NO;
        }
        
        if ([viewToSearch isKindOfClass:NSClassFromString(@"TFNButton")]) {
            TFNButton *button = (TFNButton *)viewToSearch;
            if ([button.accessibilityIdentifier isEqualToString:targetAccessibilityId]) {
                button.hidden = YES;
                return YES;
            }
        }
        
        // Create a copy of subviews to avoid mutation during iteration
        NSArray *subviews = [viewToSearch.subviews copy];
        for (UIView *subview in subviews) {
            if (findAndHideButtonWithAccessibilityId(subview, targetAccessibilityId)) {
                return YES;
            }
        }
        return NO;
    } @catch (NSException *exception) {
        NSLog(@"[BHTwitter] Exception in findAndHideButtonWithAccessibilityId: %@", exception);
        return NO;
    }
}

%hook T1ConversationFocalStatusView

- (void)didMoveToWindow {
    %orig;
    if ([BHTManager hideFollowButton]) {
        findAndHideButtonWithAccessibilityId(self, @"FollowButton");
    }
}

%end

// MARK: - Hide Follow Button (T1ImmersiveViewController)

// Minimal interface for T1ImmersiveViewController
@interface T1ImmersiveViewController : UIViewController
@end

%hook T1ImmersiveViewController

- (void)viewDidLoad {
    %orig;
    @try {
        if ([BHTManager hideFollowButton] && self.view) {
            findAndHideButtonWithAccessibilityId(self.view, @"FollowButton");
        }
    } @catch (NSException *exception) {
        NSLog(@"[BHTwitter] Exception in T1ImmersiveViewController viewDidLoad: %@", exception);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    @try {
        if ([BHTManager hideFollowButton] && self.view) {
            findAndHideButtonWithAccessibilityId(self.view, @"FollowButton");
        }
    } @catch (NSException *exception) {
        NSLog(@"[BHTwitter] Exception in T1ImmersiveViewController viewWillAppear: %@", exception);
    }
}

%end

// MARK: - Restore Follow Button (TUIFollowControl)

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
@property(retain, nonatomic) UIButton *button;
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
    @try {
        // Safety check: Ensure view is valid
        if (!view) {
            return nil;
        }
        
        UIResponder *responder = view;
        NSInteger maxIterations = 20; // Prevent infinite loops
        NSInteger currentIteration = 0;
        
        while ((responder = [responder nextResponder]) && currentIteration < maxIterations) {
            currentIteration++;
            
            // Safety check: Ensure responder is still valid
            if (!responder) {
                break;
            }
            
            if ([responder isKindOfClass:[UIViewController class]]) {
                return (UIViewController *)responder;
            }
            // Stop if we reach top-level objects like UIWindow or UIApplication without finding a VC
            if ([responder isKindOfClass:[UIWindow class]] || [responder isKindOfClass:[UIApplication class]]) {
                break;
            }
        }
        return nil;
    } @catch (NSException *exception) {
        NSLog(@"[BHTwitter] Exception in getViewControllerForView: %@", exception);
        return nil;
    }
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

    if ([BHTManager restoreVideoTimestamp]) {
        if (!playerToTimestampMap) { 
            playerToTimestampMap = [NSMapTable weakToStrongObjectsMapTable];
        }
        
        // Ensure the label is found and prepared if the view appears.
        [self BHT_findAndPrepareTimestampLabelForVC:activePlayerVC];
        
        // REMOVED: BHT_FirstLoadDone and related logic for forced first-load visibility.
        // BOOL isFirstLoad = ![objc_getAssociatedObject(activePlayerVC, "BHT_FirstLoadDone") boolValue];
        // if (isFirstLoad) {
            // dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // if (self && self.view.window) {
                    // objc_setAssociatedObject(self, "BHT_FirstLoadDone", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                // }
            // });
        // }
    }
}

- (void)playerViewController:(id)playerViewController playerStateDidChange:(NSInteger)state {
    %orig(playerViewController, state);
    T1ImmersiveFullScreenViewController *activePlayerVC = self;

    if (![BHTManager restoreVideoTimestamp] || !playerToTimestampMap) {
        return;
    }

    // Always try to find/prepare the label for the current video content.
    // This is crucial if the VC is reused and new video content has loaded.
    BOOL labelFoundAndPrepared = [self BHT_findAndPrepareTimestampLabelForVC:activePlayerVC];

    if (labelFoundAndPrepared) {
        UILabel *timestampLabel = [playerToTimestampMap objectForKey:activePlayerVC];
        if (timestampLabel && timestampLabel.superview && [timestampLabel isDescendantOfView:activePlayerVC.view]) {
            // Determine current intended visibility of controls.
            BOOL controlsShouldBeVisible = NO;
            UIView *playerControls = nil;
            if ([activePlayerVC respondsToSelector:@selector(playerControlsView)]) { 
                playerControls = [activePlayerVC valueForKey:@"playerControlsView"];
                if (playerControls && [playerControls respondsToSelector:@selector(alpha)]) {
                    controlsShouldBeVisible = playerControls.alpha > 0.0f;
                }
            }

            // Directly set the label's visibility based on controls
            timestampLabel.hidden = !controlsShouldBeVisible; 
        }
    }
}

%end

// MARK: - Square Avatars (TFNAvatarImageView)

@interface TFNAvatarImageView : UIView // Assuming it's a UIView subclass, adjust if necessary
- (void)setStyle:(NSInteger)style;
- (NSInteger)style;
@end

// MARK: - Blur Handler

@interface TFNBlurHandler : NSObject
@property(retain, nonatomic) UIView *blurBackgroundView;
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

%hook TFNCircularAvatarShadowLayer

- (void)setHidden:(BOOL)hidden {
    if ([BHTManager squareAvatars]) {
        %orig(YES); // Always hide this layer when square avatars are enabled
    } else {
        %orig;
    }
}

%end

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
                if (status == kAudioServicesNoError) {
                    soundsInitialized[soundType] = YES;
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
    static BOOL previousLoading = NO;
    static BOOL manualRefresh = NO;
    
    if (!loading && previousLoading && manualRefresh) {
        PlayRefreshSound(1);
        manualRefresh = NO;
    }
    
    if (!loading && previousLoading) {
        manualRefresh = NO;
    } else if (loading && !previousLoading) {
        // This is likely a manual refresh
        manualRefresh = YES;
    }
    
    previousLoading = loading;
    %orig;
}

// Hook the completion-based loading setter
- (void)setLoading:(_Bool)loading completion:(void(^)(void))completion {
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
    %orig;
    
    if (status == 1 && fromScrolling) {
        PlayRefreshSound(0);
        
        // Mark that we're in a manual refresh
        objc_setAssociatedObject(self, &kManualRefreshInProgressKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // Mark that loading started (even though setLoading: might not be called with loading=1)
        objc_setAssociatedObject(self, &kPreviousLoadingStateKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
        
        // Initialize the concurrent queue for source label data access
        sourceLabelDataQueue = dispatch_queue_create("com.bandarhelal.bhtwitter.sourceLabelQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    // Initialize dictionaries for Tweet Source Labels restoration
    dispatch_barrier_async(sourceLabelDataQueue, ^{
        if (!tweetSources)      tweetSources      = [NSMutableDictionary dictionary];
        if (!fetchTimeouts)     fetchTimeouts     = [NSMutableDictionary dictionary];
        if (!fetchRetries)      fetchRetries      = [NSMutableDictionary dictionary];
        if (!updateRetries)     updateRetries     = [NSMutableDictionary dictionary];
        if (!updateCompleted)   updateCompleted   = [NSMutableDictionary dictionary];
        if (!fetchPending)      fetchPending      = [NSMutableDictionary dictionary];
        if (!cookieCache)       cookieCache       = [NSMutableDictionary dictionary];
    });
    // These dictionaries are UI-related and should only be accessed on the main thread
    if (!viewToTweetID)     viewToTweetID     = [NSMutableDictionary dictionary];
    if (!viewInstances)     viewInstances     = [NSMutableDictionary dictionary];
    
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

// MARK: - Classic Tab Bar Icon Theming
%hook T1TabView

%new
- (void)bh_applyCurrentThemeToIcon {
    UIImageView *imageView = [self valueForKey:@"imageView"];
    UILabel *titleLabel = [self valueForKey:@"titleLabel"];
    if (!imageView) return;
    
    BOOL isSelected = [[self valueForKey:@"selected"] boolValue];
    
    if ([BHTManager classicTabBarEnabled]) {
        // Apply custom theming
        UIColor *targetColor = isSelected ? BHTCurrentAccentColor() : [UIColor secondaryLabelColor];
        
        // Ensure image is in template mode for proper tinting
        if (imageView.image && imageView.image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
            imageView.image = [imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        
        // Apply tint color to icon
        imageView.tintColor = targetColor;
        
        // Apply color to label
        if (titleLabel) {
            titleLabel.textColor = targetColor;
        }
    } else {
        // Revert to default Twitter appearance
        imageView.tintColor = nil;
        
        // Reset image rendering mode to automatic
        if (imageView.image) {
            imageView.image = [imageView.image imageWithRenderingMode:UIImageRenderingModeAutomatic];
        }
        
        // Reset label color to default
        if (titleLabel) {
            titleLabel.textColor = nil;
        }
    }
}

- (BOOL)_t1_showsTitle {
    if ([BHTManager restoreTabLabels]) {
        return true;
    }
    return %orig;
}

- (void)_t1_updateTitleLabel {
    %orig;
    
    // Ensure titleLabel is not hidden when restore tab labels is enabled
    if ([BHTManager restoreTabLabels]) {
        UILabel *titleLabel = [self valueForKey:@"titleLabel"];
        if (titleLabel) {
            titleLabel.hidden = NO;
        }
    }
}

- (void)_t1_updateImageViewAnimated:(_Bool)animated {
    %orig(animated);
    
    // Always apply theming logic (handles both enabled and disabled cases)
    [self performSelector:@selector(bh_applyCurrentThemeToIcon)];
}

- (void)setSelected:(_Bool)selected {
    %orig(selected);
    
    // Always apply theming logic (handles both enabled and disabled cases)
    [self performSelector:@selector(bh_applyCurrentThemeToIcon)];
}

%end



// MARK: - Tab Bar Controller Theme Integration
%hook T1TabBarViewController

- (void)_t1_updateTabBarAppearance {
    %orig;
    
    // Apply our custom theming after Twitter updates the tab bar
    if ([BHTManager classicTabBarEnabled]) {
        NSArray *tabViews = [self valueForKey:@"tabViews"];
        for (id tabView in tabViews) {
            if ([tabView respondsToSelector:@selector(bh_applyCurrentThemeToIcon)]) {
                [tabView performSelector:@selector(bh_applyCurrentThemeToIcon)];
            }
        }
    }
}

%end

// Helper: Update all tab bar icons using Twitter's internal methods
static void BHT_UpdateAllTabBarIcons(void) {
    // Use Twitter's notification system to refresh tab bars
    [[NSNotificationCenter defaultCenter] postNotificationName:@"T1TabBarAppearanceDidChangeNotification" object:nil];
    
    // Also trigger a direct refresh on visible tab bar controllers
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow && window.rootViewController) {
            UIViewController *rootVC = window.rootViewController;
            
            if ([rootVC isKindOfClass:NSClassFromString(@"T1TabBarViewController")]) {
                // Use Twitter's internal tab bar refresh method if available
                if ([rootVC respondsToSelector:@selector(_t1_updateTabBarAppearance)]) {
                    [rootVC performSelector:@selector(_t1_updateTabBarAppearance)];
                }
            }
        }
    }
}

static void BHT_applyThemeToWindow(UIWindow *window) {
    if (!window || !window.rootViewController) return;

    // Simply trigger Twitter's internal appearance update
    if ([window.rootViewController isKindOfClass:NSClassFromString(@"T1TabBarViewController")]) {
        if ([window.rootViewController respondsToSelector:@selector(_t1_updateTabBarAppearance)]) {
            [window.rootViewController performSelector:@selector(_t1_updateTabBarAppearance)];
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
        
        // Refresh only tab bar icons when classic theming is enabled
        if ([BHTManager classicTabBarEnabled]) {
            BHT_UpdateAllTabBarIcons();
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
    // Only update tab bar icons if classic theming is enabled
    if ([BHTManager classicTabBarEnabled]) {
        BHT_UpdateAllTabBarIcons();
    }
    
    // Trigger system-wide appearance updates
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow && window.rootViewController) {
            [window.rootViewController.view setNeedsLayout];
        }
    }
}

// MARK: - Timestamp Label Styling via UILabel -setText:

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
        // gVideoTimestampLabel = self; // REMOVED
    }
}

// For first-load mode, prevent hiding the timestamp
- (void)setHidden:(BOOL)hidden {
    // Only check labels that might be our timestamp
    // if (self == gVideoTimestampLabel && [BHTManager restoreVideoTimestamp]) { // REMOVED gVideoTimestampLabel logic
        // If trying to hide a fixed label, prevent it
        // if (hidden) {
            // BOOL isFixedForFirstLoad = [objc_getAssociatedObject(self, "BHT_FixedForFirstLoad") boolValue];
            // if (isFixedForFirstLoad) {
                // Let the original method run but with "NO" instead of "YES"
                // return %orig(NO);
            // }
        // }
    // }
    
    // Default behavior
    %orig(hidden);
}

// Also prevent changing alpha to 0 for first-load labels
- (void)setAlpha:(CGFloat)alpha {
    // Only check our timestamp label
    // if (self == gVideoTimestampLabel && [BHTManager restoreVideoTimestamp]) { // REMOVED gVideoTimestampLabel logic
        // If trying to make a fixed label transparent, prevent it
        // if (alpha == 0.0) {
            // BOOL isFixedForFirstLoad = [objc_getAssociatedObject(self, "BHT_FixedForFirstLoad") boolValue];
            // if (isFixedForFirstLoad) {
                // Keep it fully opaque during protected period
                // return %orig(1.0);
            // }
        // }
    // }
    
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
- (BOOL)BHT_findConversationViewInView:(UIView *)view;
- (TFNTwitterStatus *)BHT_findStatusObjectInController:(UIViewController *)controller;
- (UITextView *)BHT_findTweetTextViewInController:(UIViewController *)controller;
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
        if ([parentVCFromResponder isKindOfClass:[UINavigationController class]]) {
            actualContentVC = [(UINavigationController *)parentVCFromResponder topViewController];
        } else {
            actualContentVC = parentVCFromResponder;
        }
    } else {
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
            } else {
                 actualContentVC = topVC;
            }
        } else {
            return; // Can't proceed without a VC
        }
    }
    
    // Check if this is a conversation/tweet view by looking for T1ConversationFocalStatusView
    BOOL isTweetView = NO;
    UILabel *titleLabel = nil;
    
    // Get the first label as our title label reference (for positioning)
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(UILabel)]) {
            titleLabel = (UILabel *)subview;
                break;
        }
    }
    
    // Simple and reliable check: look for T1ConversationFocalStatusView in the view hierarchy
    if (actualContentVC && actualContentVC.isViewLoaded) {
        isTweetView = [self BHT_findConversationViewInView:actualContentVC.view];
    }
    
    // Only proceed if this is a valid tweet view
    if (isTweetView) {
        // Check if button already exists
        UIButton *existingButton = objc_getAssociatedObject(self, &kTranslateButtonKey);
        if (existingButton) {
            // Ensure it's visible and properly placed if it exists
            existingButton.hidden = NO;
            [self bringSubviewToFront:existingButton]; 
            return;
        }
        
        // If button doesn't exist, create it
        UIButton *translateButton = [UIButton buttonWithType:UIButtonTypeSystem];
        
        // Load translate icon from Twitter's vector bundle (injected during build)
        UIImage *translateIcon = [UIImage tfn_vectorImageNamed:@"translate" fitsSize:CGSizeMake(24, 24) fillColor:[UIColor systemGray2Color]];
        

        
        [translateButton setImage:translateIcon forState:UIControlStateNormal];
        
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

        [translateButton addTarget:self action:@selector(BHT_translateCurrentTweetAction:) forControlEvents:UIControlEventTouchUpInside];
        translateButton.tag = 12345; // Unique tag
        
        // Add button with higher z-index - defensive insertion
        if (titleLabel) {
        [self insertSubview:translateButton aboveSubview:titleLabel];
        } else {
            [self addSubview:translateButton];
        }
        translateButton.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Store button reference in associated object
        objc_setAssociatedObject(self, &kTranslateButtonKey, translateButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Defensive constraint creation - ensure views are in same hierarchy
        @try {
            // Verify the button is actually in our view hierarchy
            if (translateButton.superview == self) {
        NSArray *constraints = @[
            [translateButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [translateButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [translateButton.widthAnchor constraintEqualToConstant:44],
            [translateButton.heightAnchor constraintEqualToConstant:44]
        ];
        
        // Store constraints reference to prevent deallocation
        objc_setAssociatedObject(translateButton, "translateButtonConstraints", constraints, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [NSLayoutConstraint activateConstraints:constraints];
            } else {
                // Fallback to frame-based positioning if constraints fail
                CGRect selfBounds = self.bounds;
                translateButton.frame = CGRectMake(selfBounds.size.width - 54, 
                                                 (selfBounds.size.height - 44) / 2, 
                                                 44, 44);
                translateButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            }
        } @catch (NSException *exception) {
            // Last resort: use frame-based positioning
            CGRect selfBounds = self.bounds;
            translateButton.frame = CGRectMake(selfBounds.size.width - 54, 
                                             (selfBounds.size.height - 44) / 2, 
                                             44, 44);
            translateButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        }
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
- (BOOL)BHT_findConversationViewInView:(UIView *)view {
    if ([view isKindOfClass:%c(T1ConversationFocalStatusView)]) {
        return YES;
    }
    for (UIView *subview in view.subviews) {
        if ([self BHT_findConversationViewInView:subview]) {
            return YES;
        }
    }
    return NO;
}

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
        return;
    }

    // Find the TTAStatusBodySelectableContentTextView
    UITextView *tweetTextView = [self BHT_findTweetTextViewInController:targetController];
    
    if (!tweetTextView || ![tweetTextView isKindOfClass:%c(TTAStatusBodySelectableContentTextView)]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Translation Error" 
                                                                       message:@"Could not find tweet text to translate." 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [targetController presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    TTAStatusBodySelectableContentTextView *selectableTextView = (TTAStatusBodySelectableContentTextView *)tweetTextView;
    
    // Check if already translated - if so, toggle back to original
    if ([selectableTextView BHT_isShowingTranslatedText]) {
        [selectableTextView BHT_restoreOriginalText];
        return;
    }
    
    NSString *textToTranslate = tweetTextView.text;
    if (!textToTranslate || textToTranslate.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Translation Error" 
                                                                       message:@"No text found to translate." 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [targetController presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Call the GeminiTranslator with the extracted text
    [[GeminiTranslator sharedInstance] translateText:textToTranslate 
                                       fromLanguage:@"auto" 
                                         toLanguage:@"en" 
                                         completion:^(NSString *translatedText, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !translatedText) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Translation Error" 
                                                                               message:error ? error.localizedDescription : @"Failed to translate text." 
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [targetController presentViewController:alert animated:YES completion:nil];
                return;
            }
            
            // Create new attributed string with the translated text
            NSAttributedString *originalAttributedText = selectableTextView.attributedText;
            NSMutableAttributedString *translatedAttributedText = [[NSMutableAttributedString alloc] initWithString:translatedText];
            
            // Preserve the original text attributes
            if (originalAttributedText.length > 0) {
                NSDictionary *attributes = [originalAttributedText attributesAtIndex:0 effectiveRange:NULL];
                [translatedAttributedText addAttributes:attributes range:NSMakeRange(0, translatedText.length)];
            }
            
            // Use our custom method to set the translated text
            [selectableTextView BHT_setTranslatedText:translatedAttributedText];
        });
    }];
}

%new - (TFNTwitterStatus *)BHT_findStatusObjectInController:(UIViewController *)controller {
    if (!controller || !controller.isViewLoaded) {
        return nil;
    }
    
    // First, if the controller is T1ConversationContainerViewController, we need to find its T1URTViewController child
    if ([NSStringFromClass([controller class]) isEqualToString:@"T1ConversationContainerViewController"]) {
        for (UIViewController *childVC in controller.childViewControllers) {
            if ([NSStringFromClass([childVC class]) isEqualToString:@"T1URTViewController"]) {
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
            @try {
                // Inspect the view model or try to access specific properties
                if ([viewModel respondsToSelector:@selector(statusViewModel)]) {
                    id statusViewModel = [viewModel valueForKey:@"statusViewModel"];
                    if (statusViewModel && [statusViewModel respondsToSelector:@selector(status)]) {
                        id status = [statusViewModel valueForKey:@"status"];
                        if (status && [status isKindOfClass:%c(TFNTwitterStatus)]) {
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
                            return status;
                        }
                    }
                }
            } @catch (NSException *e) {
                // Exception accessing T1URTViewController viewModel
            }
        }
        
        // Generic approach - check if viewModel has status directly
        if ([viewModel respondsToSelector:@selector(status)]) {
            id status = [viewModel valueForKey:@"status"];
            if (status && [status isKindOfClass:%c(TFNTwitterStatus)]) {
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
                    return status;
                }
            }
        } @catch (NSException *e) {
            // Exception occurred
        }
    }
    
    return nil;
}

// Helper function for finding the TTAStatusBodySelectableContentTextView
static void findTweetTextView(UIView *view, UITextView **tweetTextView) {
    // Check specifically for TTAStatusBodySelectableContentTextView
    if ([NSStringFromClass([view class]) isEqualToString:@"TTAStatusBodySelectableContentTextView"]) {
        *tweetTextView = (UITextView *)view;
        return;
    }
    
    // Recurse into subviews
    for (UIView *subview in view.subviews) {
        if (!*tweetTextView) {
            findTweetTextView(subview, tweetTextView);
        }
    }
}

// Helper function for finding the text view (legacy)
static void findTextView(UIView *view, UITextView **tweetTextView) {
    // Check for TTAStatusBodySelectableContextTextView or any UITextView in T1URTViewController
    if ([NSStringFromClass([view class]) isEqualToString:@"TTAStatusBodySelectableContextTextView"] ||
        [view isKindOfClass:[UITextView class]]) {
        *tweetTextView = (UITextView *)view;
        return;
    }
    
    // Recurse into subviews
    for (UIView *subview in view.subviews) {
        if (!*tweetTextView) {
            findTextView(subview, tweetTextView);
        }
    }
}

%new - (UITextView *)BHT_findTweetTextViewInController:(UIViewController *)controller {
    if (!controller || !controller.isViewLoaded) {
        return nil;
    }
    
    UITextView *tweetTextView = nil;
    
    // First, try to find T1URTViewController
    UIViewController *urtViewController = nil;
    
    // Check if the current controller is a T1URTViewController
    if ([NSStringFromClass([controller class]) isEqualToString:@"T1URTViewController"]) {
        urtViewController = controller;
    }
    
    // If not found, look through the view hierarchy for a T1URTViewController
    if (!urtViewController) {
        UIViewController *currentVC = controller;
        
        // First check child view controllers
        NSArray *childVCs = [currentVC childViewControllers];
        for (UIViewController *childVC in childVCs) {
            if ([NSStringFromClass([childVC class]) isEqualToString:@"T1URTViewController"]) {
                urtViewController = childVC;
                break;
            }
        }
        
        // Then check parent view controllers if not found
        if (!urtViewController) {
            while (currentVC.parentViewController) {
                currentVC = currentVC.parentViewController;
                
                if ([NSStringFromClass([currentVC class]) isEqualToString:@"T1URTViewController"]) {
                    urtViewController = currentVC;
                    break;
                }
                
                // Also check siblings
                for (UIViewController *childVC in [currentVC childViewControllers]) {
                    if ([NSStringFromClass([childVC class]) isEqualToString:@"T1URTViewController"]) {
                        urtViewController = childVC;
                        break;
                    }
                }
                
                if (urtViewController) break;
            }
        }
    }
    
    // If we found T1URTViewController, search for TTAStatusBodySelectableContentTextView
    if (urtViewController && urtViewController.isViewLoaded) {
        findTweetTextView(urtViewController.view, &tweetTextView);
        if (tweetTextView) {
            return tweetTextView;
        }
    }
    
    // Fallback: Search the entire view hierarchy
    UIViewController *rootVC = controller;
    while (rootVC.parentViewController) {
        rootVC = rootVC.parentViewController;
    }
    
    if (rootVC.isViewLoaded) {
        findTweetTextView(rootVC.view, &tweetTextView);
    }
    
    return tweetTextView;
}

%new - (NSString *)BHT_extractTextFromStatusObjectInController:(UIViewController *)controller {
    // Don't limit to specific view controllers - search everywhere
    
    // First, try to find the T1URTViewController
    UIViewController *urtViewController = nil;
    
    // Check if the current controller is a T1URTViewController
    if ([NSStringFromClass([controller class]) isEqualToString:@"T1URTViewController"]) {
        urtViewController = controller;
    }
    
    // If not found, look through the view hierarchy for a T1URTViewController
    if (!urtViewController) {
        UIViewController *currentVC = controller;
        
        // First check child view controllers
        NSArray *childVCs = [currentVC childViewControllers];
        for (UIViewController *childVC in childVCs) {
            if ([NSStringFromClass([childVC class]) isEqualToString:@"T1URTViewController"]) {
                urtViewController = childVC;
                break;
            }
        }
        
        // Then check parent view controllers if not found
        if (!urtViewController) {
            while (currentVC.parentViewController) {
                currentVC = currentVC.parentViewController;
                
                if ([NSStringFromClass([currentVC class]) isEqualToString:@"T1URTViewController"]) {
                    urtViewController = currentVC;
                    break;
                }
                
                // Also check siblings
                for (UIViewController *childVC in [currentVC childViewControllers]) {
                    if ([NSStringFromClass([childVC class]) isEqualToString:@"T1URTViewController"]) {
                        urtViewController = childVC;
                        break;
                    }
                }
                
                if (urtViewController) break;
            }
        }
    }
    
    // If we found T1URTViewController, extract text from it
    if (urtViewController && urtViewController.isViewLoaded) {
        UITextView *tweetTextView = nil;
        findTextView(urtViewController.view, &tweetTextView);
        
        if (tweetTextView) {
            NSString *tweetText = tweetTextView.text;
            if (tweetText && tweetText.length > 0) {
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
            return tweetText;
        }
    }
    
    // As a backup, search child view controllers explicitly
    if (!tweetTextView && [rootVC respondsToSelector:@selector(childViewControllers)]) {
        for (UIViewController *childVC in rootVC.childViewControllers) {
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
            return tweetText;
        }
    }
    
    return nil;
}

%end

// Hook TTAStatusBodySelectableContentTextView to prevent text reversion
%hook TTAStatusBodySelectableContentTextView

static char kIsTranslatedKey;
static char kOriginalTextKey;
static char kTranslatedTextKey;

- (void)setAttributedText:(NSAttributedString *)attributedText {
    // Check if we're currently showing translated text
    NSNumber *isTranslated = objc_getAssociatedObject(self, &kIsTranslatedKey);
    
    if (isTranslated && [isTranslated boolValue]) {
        // If we're in translated mode, don't allow external updates to override our translation
        NSAttributedString *currentTranslatedText = objc_getAssociatedObject(self, &kTranslatedTextKey);
        if (currentTranslatedText && ![attributedText.string isEqualToString:currentTranslatedText.string]) {
            // External code is trying to revert our translation, ignore it
            return;
        }
    }
    
    // Store original text if this is the first time setting text (not translated)
    if (!isTranslated || ![isTranslated boolValue]) {
        objc_setAssociatedObject(self, &kOriginalTextKey, attributedText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    %orig(attributedText);
}

%new - (void)BHT_setTranslatedText:(NSAttributedString *)translatedText {
    // Store the translated text and mark as translated
    objc_setAssociatedObject(self, &kTranslatedTextKey, translatedText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kIsTranslatedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Set the text directly
    [self setAttributedText:translatedText];
}

%new - (void)BHT_restoreOriginalText {
    NSAttributedString *originalText = objc_getAssociatedObject(self, &kOriginalTextKey);
    if (originalText) {
        objc_setAssociatedObject(self, &kIsTranslatedKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self setAttributedText:originalText];
    }
}

%new - (BOOL)BHT_isShowingTranslatedText {
    NSNumber *isTranslated = objc_getAssociatedObject(self, &kIsTranslatedKey);
    return isTranslated && [isTranslated boolValue];
}

%end

// Hook TFNComposableViewAdapterSet to filter out translate adapters
%hook TFNComposableViewAdapterSet

- (id)initWithViewAdaptersByIdentifier:(id)arg1 {
    if ([arg1 isKindOfClass:[NSDictionary class]]) {
        NSDictionary *originalDict = (NSDictionary *)arg1;
        NSMutableDictionary *filteredDict = [NSMutableDictionary dictionary];
        
        for (id key in originalDict) {
            id adapter = originalDict[key];
            NSString *adapterClassName = NSStringFromClass([adapter class]);
            
            // Filter out Grok adapter
            if ([adapterClassName isEqualToString:@"T1StandardStatusAskGrokButtonViewAdapter"]) {
                continue; // Skip this adapter
            }
            
            // Filter out translate-related adapters if translate is enabled
            if ([BHTManager enableTranslate] && 
                ([adapterClassName containsString:@"Translate"] || 
                 [adapterClassName containsString:@"Translation"])) {
                continue; // Skip translate adapters
            }
            
            // Keep all other adapters
            filteredDict[key] = adapter;
        }
        
        return %orig([filteredDict copy]);
    }
    
    return %orig(arg1);
}

%end

%hook TFNComposableViewSet

- (void)_tfn_addView:(id)arg1 toHostViewWithViewAdapter:(id)arg2 {
    // Check if this is a translate view and our feature is enabled
    if ([BHTManager enableTranslate] && [arg1 isKindOfClass:%c(T1StandardStatusTranslateView)]) {
        // Don't add translate views to the view set
        return;
    }
    
    %orig(arg1, arg2);
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
        NSString *model = [BHTManager translateModel];
        
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
        
        // Construct the request URL properly using the user's model setting
        NSString *fullUrlString;
        if ([apiUrl containsString:@"generativelanguage.googleapis.com"] && ![apiUrl containsString:@":generateContent"]) {
            // For default Gemini API base URL, construct full URL with the user's chosen model
            fullUrlString = [NSString stringWithFormat:@"%@/%@:generateContent?key=%@", apiUrl, model, apiKey];
        } else {
            // For custom endpoints or already complete URLs, just append the API key
            if ([apiUrl containsString:@"?"]) {
                fullUrlString = [NSString stringWithFormat:@"%@&key=%@", apiUrl, apiKey];
            } else {
                fullUrlString = [NSString stringWithFormat:@"%@?key=%@", apiUrl, apiKey];
            }
        }
        
        NSURL *url = [NSURL URLWithString:fullUrlString];
        
        // Create request
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        // Simplified prompt for translation only
        NSString *prompt = [NSString stringWithFormat:@"Translate this text from %@ to %@: \"%@\" \n\nOnly return the translated text without any explanation or notes. include emojis if in original text.", 
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

// MARK: Restore Launch Animation

%hook T1AppDelegate
+ (id)launchTransitionProvider {
    Class T1AppLaunchTransitionClass = NSClassFromString(@"T1AppLaunchTransition");
    if (T1AppLaunchTransitionClass) {
        return [[T1AppLaunchTransitionClass alloc] init];
    }
    return nil;
}
%end

// MARK: Source Label using T1ConversationFooterTextView

%hook T1ConversationFooterTextView

- (void)updateFooterTextView {
    %orig;
    
    // Add source label to footer text view
    if ([BHTManager RestoreTweetLabels] && self.viewModel) {
        @try {
            // Get the tweet object from the view model
            id tweetObject = nil;
            if ([self.viewModel respondsToSelector:@selector(tweet)]) {
                tweetObject = [self.viewModel performSelector:@selector(tweet)];
            } else if ([self.viewModel respondsToSelector:@selector(status)]) {
                tweetObject = [self.viewModel performSelector:@selector(status)];
            }
            
            if (tweetObject) {
                // Get tweet ID
                NSString *tweetIDStr = nil;
                @try {
                    id statusIDVal = [tweetObject valueForKey:@"statusID"];
                    if (statusIDVal && [statusIDVal respondsToSelector:@selector(longLongValue)] && [statusIDVal longLongValue] > 0) {
                        tweetIDStr = [statusIDVal stringValue];
                    }
                } @catch (NSException *e) {}
                
                if (!tweetIDStr || tweetIDStr.length == 0) {
                    @try {
                        tweetIDStr = [tweetObject valueForKey:@"rest_id"];
                        if (!tweetIDStr || tweetIDStr.length == 0) {
                            tweetIDStr = [tweetObject valueForKey:@"id_str"];
                        }
                        if (!tweetIDStr || tweetIDStr.length == 0) {
                            id genericID = [tweetObject valueForKey:@"id"];
                            if (genericID) tweetIDStr = [genericID description];
                        }
                    } @catch (NSException *e) {}
                }
                
                if (tweetIDStr && tweetIDStr.length > 0) {
                    // Initialize source tracking if needed
                    if (!tweetSources) tweetSources = [NSMutableDictionary dictionary];
                    
                    // Fetch source if not already available
                    if (!tweetSources[tweetIDStr]) {
                        tweetSources[tweetIDStr] = @""; // Placeholder
                        [TweetSourceHelper fetchSourceForTweetID:tweetIDStr];
                    }
                    
                    // Legacy source code removed
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[BHTwitter] Exception in T1ConversationFooterTextView updateFooterTextView: %@", e);
        }
    }
}

%end

// MARK: Change Pill text.
%hook TFNPillControl
- (id)text {
    NSString *localizedText = [[BHTBundle sharedBundle] localizedStringForKey:@"REFRESH_PILL_TEXT"];
    return localizedText ?: @"Tweeted";
}
- (void)setText:(id)arg1 {
    NSString *localizedText = [[BHTBundle sharedBundle] localizedStringForKey:@"REFRESH_PILL_TEXT"];
    %orig(localizedText ?: @"Tweeted");
}
%end

// MARK: Remove all sections from the Explore "for you" tab except the trending cells.
static BOOL BHT_isInGuideContainerHierarchy(UIViewController *viewController) {
    if (!viewController) return NO;
    
    // Check all view controllers up the hierarchy
    UIViewController *currentVC = viewController;
    while (currentVC) {
        NSString *className = NSStringFromClass([currentVC class]);
        
        // Check for GuideContainerViewController (handles both naming variants)
        if ([className containsString:@"GuideContainerViewController"]) {
            return YES;
        }
        
        // Move up the hierarchy
        if (currentVC.parentViewController) {
            currentVC = currentVC.parentViewController;
        } else if (currentVC.navigationController) {
            currentVC = currentVC.navigationController;
        } else if (currentVC.presentingViewController) {
            currentVC = currentVC.presentingViewController;
        } else {
            break;
        }
    }
    
    return NO;
}

// Hook TFNItemsDataViewController to filter sections array
%hook TFNItemsDataViewController

- (void)setSections:(NSArray *)sections {
    // Only filter if we're in the GuideContainerViewController hierarchy
    if (BHT_isInGuideContainerHierarchy(self)) {
        // Keep only entry 3 (index 2), remove everything else
        if (sections.count > 2) {
            sections = @[sections[2]]; // Extract only the 3rd entry
        }
    }
    
    %orig(sections);
}

%end

// Helper function to check if we're in the T1ConversationContainerViewController hierarchy
static BOOL BHT_isInConversationContainerHierarchy(UIViewController *viewController) {
    if (!viewController) return NO;
    
    // Check all view controllers up the hierarchy
    UIViewController *currentVC = viewController;
    while (currentVC) {
        NSString *className = NSStringFromClass([currentVC class]);
        
        // Check for T1ConversationContainerViewController
        if ([className isEqualToString:@"T1ConversationContainerViewController"]) {
            return YES;
        }
        
        // Move up the hierarchy
        if (currentVC.parentViewController) {
            currentVC = currentVC.parentViewController;
        } else if (currentVC.navigationController) {
            currentVC = currentVC.navigationController;
        } else if (currentVC.presentingViewController) {
            currentVC = currentVC.presentingViewController;
        } else {
            break;
        }
    }
    
    return NO;
}

// MARK : Remove "Discover More" section
%hook T1URTViewController

- (void)setSections:(NSArray *)sections {
    
    // Only filter if we're in the T1ConversationContainerViewController hierarchy
    BOOL inConversationHierarchy = BHT_isInConversationContainerHierarchy((UIViewController *)self);
    
    if (inConversationHierarchy) {
        // Remove entry 1 (index 1) from sections array
        if (sections.count > 1) {
            NSMutableArray *filteredSections = [NSMutableArray arrayWithArray:sections];
            [filteredSections removeObjectAtIndex:1];
            sections = [filteredSections copy];
        }
    }
    
    %orig(sections);
}

%end

// MARK: should hopefully remove reply boost upsells
%hook T1SubscriptionJourneyManager
- (_Bool)shouldShowReplyBoostUpsellWithAccount {
        return false;
}
%end

%hook T1SuperFollowControl

- (id)initWithSizeClass:(long long)arg1 {
    id result = %orig;
    if ([BHTManager restoreFollowButton] && result) {
        [self setHidden:YES];
        [self setAlpha:0.0];
    }
    return result;
}

- (void)_t1_configureButton {
    %orig;
    if ([BHTManager restoreFollowButton]) {
        [self setHidden:YES];
        [self setAlpha:0.0];
        if (self.button) {
            [self.button setHidden:YES];
            [self.button setAlpha:0.0];
        }
    }
}
%end

// MARK : fix for super follower profiles.
%hook T1ProfileActionButtonsView

// Method that creates the overflow button
- (id)_t1_overflowButtonForItems:(id)arg1 {
    if ([BHTManager restoreFollowButton]) {
        return nil; // Return nil to prevent the overflow button from appearing
    }
    return %orig;
}

// Override the method that determines which buttons to show based on width
- (void)_t1_updateArrangedButtonItemsForContentWidth:(double)arg1 {
    if ([BHTManager restoreFollowButton]) {
        %orig(10000.0);
    } else {
        %orig(arg1);
    }
}

%end

static NSBundle *BHBundle() {
    return [NSBundle bundleWithIdentifier:@"com.bandarhelal.BHTwitter"];
}

// MARK: Theme TFNBarButtonItemButtonV1
%hook TFNBarButtonItemButtonV1

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        // Trigger our setTintColor logic
        self.tintColor = [UIColor blackColor];
    }
}

- (void)setTintColor:(UIColor *)tintColor {
    BOOL isDark = BHT_isTwitterDarkThemeActive();
    UIColor *correctColor = isDark ? [UIColor whiteColor] : [UIColor blackColor];
    %orig(correctColor);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig(previousTraitCollection);
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            // Trigger our setTintColor logic
            self.tintColor = [UIColor blackColor];
        }
    }
%end
