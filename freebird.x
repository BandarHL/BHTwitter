#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>
#import "TWHeaders.h"
#import "BHTManager.h"
#import "BHTBundle/BHTBundle.h"

// Define any externally referenced functions from Tweak.x that we need in freebird.x
// For example, BHTCurrentAccentColor(), BH_EnumerateSubviewsRecursively, etc.

// Forward declaration for T1ImmersiveFullScreenViewController's category
@class T1ImmersiveFullScreenViewController;

// Map to store timestamp labels for each player instance
static NSMapTable<T1ImmersiveFullScreenViewController *, UILabel *> *playerToTimestampMap = nil;

// Theme state tracking
static BOOL BHT_isInThemeChangeOperation = NO; // Added declaration

// Forward declaration for local static function

// Forward declaration for T1ColorSettings for _t1_applyPrimaryColorOption

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

// Minimal interface to satisfy compiler for TweetSourceHelper class methods
@implementation TweetSourceHelper

// Simple implementation for methods declared in TWHeaders.h
+ (void)logDebugInfo:(NSString *)message {
    if (message) {
        NSLog(@"[BHTwitter SourceLabel] %@", message);
    }
}

+ (void)pruneSourceCachesIfNeeded {
    // Simple implementation to make it no-op
    return;
}

+ (void)initializeCookiesWithRetry {
    // Just check cached or fetch cookies directly
    if (!cookieCache || cookieCache.count == 0) {
        NSDictionary *cookies = [self fetchCookies];
        if (cookies && cookies.count > 0) {
            [self cacheCookies:cookies];
        }
    }
}

+ (void)retryFetchCookies {
    // Simple retry - just try once
    NSDictionary *cookies = [self fetchCookies];
    if (cookies && cookies.count > 0) {
        [self cacheCookies:cookies];
    }
}

+ (void)handleClearCacheNotification:(NSNotification *)notification {
    // Clear all dictionaries
    if (tweetSources) [tweetSources removeAllObjects];
    if (viewToTweetID) [viewToTweetID removeAllObjects];
    if (viewInstances) [viewInstances removeAllObjects];
    if (fetchPending) [fetchPending removeAllObjects];
    if (fetchRetries) [fetchRetries removeAllObjects];
    if (updateRetries) [updateRetries removeAllObjects];
    if (updateCompleted) [updateCompleted removeAllObjects];
    if (cookieCache) [cookieCache removeAllObjects];
    lastCookieRefresh = nil;
    
    // Clear persistent storage
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"TweetSourceTweak_CookieCache"];
    [defaults removeObjectForKey:@"TweetSourceTweak_LastCookieRefresh"];
    [defaults synchronize];
}

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

// MARK: - Hide Grok Analyze Button (TTAStatusAuthorView)

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
    // ... (implementation as before)
    if (!playerToTimestampMap || !activePlayerVC || !activePlayerVC.isViewLoaded) {
        NSLog(@"[BHTwitter Timestamp] BHT_findAndPrepareTimestampLabelForVC: Pre-condition failed (map: %@, vc: %@, viewLoaded: %d)", playerToTimestampMap, activePlayerVC, activePlayerVC.isViewLoaded);
        return NO;
    }

    UILabel *timestampLabel = [playerToTimestampMap objectForKey:activePlayerVC];

    BOOL needsFreshFind = (!timestampLabel || !timestampLabel.superview || ![timestampLabel.superview isDescendantOfView:activePlayerVC.view]);
    if (timestampLabel && timestampLabel.superview && 
        (![timestampLabel.text containsString:@":"] || ![timestampLabel.text containsString:@"/"])) {
        needsFreshFind = YES;
        NSLog(@"[BHTwitter Timestamp] VC %@: Label %@ found with non-timestamp text: \"%@\". Forcing re-find.", activePlayerVC, timestampLabel, timestampLabel.text);
        [playerToTimestampMap removeObjectForKey:activePlayerVC];
        timestampLabel = nil;
    }
    
    if (needsFreshFind) {
        NSLog(@"[BHTwitter Timestamp] VC %@: Needs fresh find for label.", activePlayerVC);
        __block UILabel *foundCandidate = nil;
        UIView *searchView = activePlayerVC.view;

        BH_EnumerateSubviewsRecursively(searchView, ^(UIView *currentView) {
            if (foundCandidate) return;
            if ([currentView isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)currentView;
                UIView *v = label.superview;
                BOOL inImmersiveCardViewContext = NO;
                while(v && v != searchView.window && v != searchView) {
                    NSString *className = NSStringFromClass([v class]);
                    if ([className isEqualToString:@"T1TwitterSwift.ImmersiveCardView"] || [className hasSuffix:@".ImmersiveCardView"]) {
                        inImmersiveCardViewContext = YES;
                break;
            }
                    v = v.superview;
                }

                if (inImmersiveCardViewContext && label.text && [label.text containsString:@":"] && [label.text containsString:@"/"]) {
                    NSLog(@"[BHTwitter Timestamp] VC %@: Candidate label found: Text='%@', Superview=%@", activePlayerVC, label.text, NSStringFromClass(label.superview.class));
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
            NSLog(@"[BHTwitter Timestamp] VC %@: Associated label %@ in map.", activePlayerVC, timestampLabel);
        } else {
            if ([playerToTimestampMap objectForKey:activePlayerVC]) {
                 NSLog(@"[BHTwitter Timestamp] VC %@: No label found, removing existing map entry.", activePlayerVC);
                [playerToTimestampMap removeObjectForKey:activePlayerVC];
            }
            return NO;
        }
    }

    if (timestampLabel && ![objc_getAssociatedObject(timestampLabel, "BHT_StyledTimestamp") boolValue]) {
        NSLog(@"[BHTwitter Timestamp] VC %@: Styling label %@.", activePlayerVC, timestampLabel);
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
    NSLog(@"[BHTwitter Timestamp] VC %@: showHideNavigationButtons: %d (original: %d)", activePlayerVC, showButtons, originalShowButtons);

    // The rest of the method remains unchanged
    if (![BHTManager restoreVideoTimestamp]) {
        if (playerToTimestampMap) {
            UILabel *labelToManage = [playerToTimestampMap objectForKey:activePlayerVC];
            if (labelToManage) {
                labelToManage.hidden = YES;
                NSLog(@"[BHTwitter Timestamp] VC %@: Hiding label (feature disabled).", activePlayerVC);
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
        NSLog(@"[BHTwitter Timestamp] VC %@: ERROR - Does not respond to selector BHT_findAndPrepareTimestampLabelForVC:", activePlayerVC);
    }

    if (labelReady) {
        UILabel *timestampLabel = [playerToTimestampMap objectForKey:activePlayerVC];
        if (timestampLabel) { 
            // Let the timestamp follow the controls visibility, but ensure it matches
            BOOL isVisible = showButtons;
            NSLog(@"[BHTwitter Timestamp] VC %@: Controls visibility changed to %d", activePlayerVC, isVisible);
            
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
    // No longer needed since we use other methods
// static dispatch_once_t onceToken[2];
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
                }
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
static char kRefreshingKey;
static char kPlayedPullSoundKey;
static char kNeedsPopSoundKey;
static char kPopSoundTimerKey;

// Always enable sound effects
+ (_Bool)_areSoundEffectsEnabled {
    return YES;
}

// Track refresh animation completion to ensure pop sound plays after content is loaded
- (void)_updateContentInset:(id)arg1 animated:(_Bool)arg2 {
    %orig;
    
    // This method is called when animation completes - check if we should play pop sound
    if (objc_getAssociatedObject(self, &kNeedsPopSoundKey)) {
        // Get the timer if it exists
        NSTimer *popTimer = objc_getAssociatedObject(self, &kPopSoundTimerKey);
        if (popTimer) {
            [popTimer invalidate]; // Cancel any pending timer
        }
        
        // Reset state
        objc_setAssociatedObject(self, &kNeedsPopSoundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kPopSoundTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Play the pop sound with slight delay to ensure animation is visible
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            PlayRefreshSound(1);
        });
    }
}

// Play sounds when loading state changes - this catches all refreshes
- (void)setLoading:(_Bool)loading {
    // Get previous state before changing
    NSNumber *wasRefreshing = objc_getAssociatedObject(self, &kRefreshingKey);
    BOOL wasRefreshingBool = wasRefreshing ? [wasRefreshing boolValue] : NO;
    
    // Set new state
    objc_setAssociatedObject(self, &kRefreshingKey, @(loading), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    %orig;
    
    // Going from not loading to loading (start of refresh)
    if (!wasRefreshingBool && loading) {
        NSNumber *didPlayPull = objc_getAssociatedObject(self, &kPlayedPullSoundKey);
        if (!didPlayPull || ![didPlayPull boolValue]) {
            // This is for auto-refresh cases where _setStatus isn't called
            PlayRefreshSound(0);
        }
        
        // Reset status for next refresh
        objc_setAssociatedObject(self, &kPlayedPullSoundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Going from loading to not loading (end of refresh)
    else if (wasRefreshingBool && !loading) {
        // Mark that we need to play pop sound after animation completes
        objc_setAssociatedObject(self, &kNeedsPopSoundKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Set a fallback timer in case _updateContentInset doesn't get called
        NSTimer *popTimer = [NSTimer scheduledTimerWithTimeInterval:0.7 
                                                          repeats:NO 
                                                            block:^(NSTimer *timer) {
            // Only play if not already played
            if (objc_getAssociatedObject(self, &kNeedsPopSoundKey)) {
                objc_setAssociatedObject(self, &kNeedsPopSoundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(self, &kPopSoundTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                PlayRefreshSound(1);
            }
        }];
        
        objc_setAssociatedObject(self, &kPopSoundTimerKey, popTimer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// Detect manual pull-to-refresh and play pull sound
- (void)_setStatus:(unsigned long long)status fromScrolling:(_Bool)fromScrolling {
    %orig;
    
    if (status == 1 && fromScrolling) {
        // Status changed to "triggered" via pull - play the pull sound
        PlayRefreshSound(0);
        objc_setAssociatedObject(self, &kPlayedPullSoundKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// Handle initial load refresh when app launches
- (void)startPullToRefreshAnimationInScrollView:(id)scrollView {
    %orig;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // For the initial app launch refresh, use slightly different timing
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            PlayRefreshSound(0); // Pull sound
            
            // Play pop with longer delay for initial refresh
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                PlayRefreshSound(1); // Pop sound
            });
        });
    });
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
void BHT_UpdateAllTabBarIcons(void) {
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

void BHT_applyThemeToWindow(UIWindow *window) {
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
void BHT_ensureThemingEngineSynchronized(BOOL forceSynchronize) {
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
void BHT_ensureTheming(void) {
    BHT_ensureThemingEngineSynchronized(YES);
}

// Comprehensive UI refresh - used when we need to force a UI update
void BHT_forceRefreshAllWindowAppearances(void) {
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

// MARK: Theme TFNBarButtonItemButtonV2
%hook TFNBarButtonItemButtonV2
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
        
        // Prepare API request parameters - with simplified prompt
        NSString *apiKey = @"";
        NSString *apiUrl = @"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";
        
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

// --- Initialisation ---


// Helper class to communicate with Gemini AI API was already declared in TWHeaders.h

// Required interface declarations are already in TWHeaders.h

// Do not redeclare T1StatusBodyTextView as it is already in TWHeaders.h
// Just declare T1CoreStatusViewModel with its status property
@interface T1CoreStatusViewModel : NSObject
@property (nonatomic, readonly) id status; // Using 'id' to match property in TWHeaders.h
@end

// The TFNTwitterStatus is already defined in TWHeaders.h
// Navigation bar and other method declarations are in TWHeaders.h

%hook _UINavigationBarContentView

static char kTranslateButtonKey;

// Removed createTextFinderWithTextRef and processView as they are not used by this feature.

%new
- (void)BHT_addTranslateButtonIfNeeded {
    // More specific check to ensure we're only in tweet detail/conversation view
    UIViewController *parentVC = nil;
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
    }
    if (responder) {
        parentVC = (UIViewController *)responder;
    }
    
    // Check if this is a conversation/tweet view by examining both title and controller class
    BOOL isTweetView = NO;
    UILabel *titleLabel = nil;
    
    // Check title
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(UILabel)]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text isEqualToString:@"Post"] || [label.text isEqualToString:@"Tweet"]) {
                titleLabel = label;
                break;
            }
        }
    }
    
    // Only proceed if we have a title AND we're in a conversation view controller
    if (titleLabel && parentVC) {
        NSString *vcClassName = NSStringFromClass([parentVC class]);
        if ([vcClassName containsString:@"Conversation"] || 
            [vcClassName containsString:@"Tweet"] || 
            [vcClassName containsString:@"Status"] || 
            [vcClassName containsString:@"Detail"]) {
            isTweetView = YES;
            NSLog(@"[BHTwitter Translate] Found legitimate tweet view: %@", vcClassName);
        }
    }
    
    // Only proceed if this is a valid tweet view
    if (isTweetView) {
        // Check if button already exists
        UIButton *existingButton = objc_getAssociatedObject(self, &kTranslateButtonKey);
        
        // If button doesn't exist, create it
        if (!existingButton) {
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
