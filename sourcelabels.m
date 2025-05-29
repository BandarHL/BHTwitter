#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/objc-runtime.h>
#import <objc/objc-runtime.h>   
#import <dlfcn.h>
#import <math.h>
#import "BHTManager.h"
#import "sourcelabels.h"
#import "TWHeaders.h"
// MARK: Restore Source Labels - This is still pretty experimental and may break. This restores Tweet Source Labels by using an Legacy API. by: @nyaathea

NSMutableDictionary *tweetSources      = nil;
NSMutableDictionary *viewToTweetID     = nil;
NSMutableDictionary *fetchTimeouts     = nil;
NSMutableDictionary *viewInstances     = nil;
NSMutableDictionary *fetchRetries      = nil;
NSMutableDictionary *updateRetries     = nil;
NSMutableDictionary *updateCompleted   = nil;
NSMutableDictionary *fetchPending      = nil;
NSMutableDictionary *cookieCache       = nil;
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

+ (void)updateFooterTextViewsForTweetID:(NSString *)tweetID {
    // TODO: Implement this method to update UI elements with the source label
    NSLog(@"[BHTwitter SourceLabel] Stub: updateFooterTextViewsForTweetID: %@", tweetID);
    // Example: You might post a notification that a view controller in Tweak.x can observe
    // [[NSNotificationCenter defaultCenter] postNotificationName:@"BHTSourceLabelReadyForTweetNotification"
    //                                                     object:nil
    //                                                   userInfo:@{@"tweetID": tweetID}];
}

@end // End of TweetSourceHelper implementation

// Logos code from here onwards should be moved to Tweak.x
// %hook TFNTwitterStatus 
// ... rest of the file which is mostly Logos code ...
