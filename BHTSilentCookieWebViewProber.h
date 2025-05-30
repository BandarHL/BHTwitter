#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h> // Required for WKWebView

NS_ASSUME_NONNULL_BEGIN

@interface BHTSilentCookieWebViewProber : NSObject <WKNavigationDelegate>

+ (instancetype)sharedInstance;

/**
 * Attempts to silently load a web page to encourage cookie population in NSHTTPCookieStorage.
 * This operation is asynchronous.
 *
 * @param completionHandler Called on the main queue when the probing attempt is complete.
 *                          'success' is YES if the webview finished loading, NO on error or if already probing.
 *                          It does NOT guarantee cookies were actually populated, the caller must re-check.
 */
- (void)probeForCookiesWithCompletion:(void (^)(BOOL success))completionHandler;

@end

NS_ASSUME_NONNULL_END 