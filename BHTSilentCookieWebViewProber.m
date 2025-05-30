#import "BHTSilentCookieWebViewProber.h"
#import <UIKit/UIKit.h> // For UIWindow access

// Define a simple, lightweight URL from x.com that might trigger cookie setting.
// The Help Center URL you mentioned is a good candidate, or a general static page.
#define PROBE_URL @"https://help.x.com/en"

@interface BHTSilentCookieWebViewProber ()
@property (nonatomic, strong, nullable) WKWebView *webView;
@property (nonatomic, copy, nullable) void (^currentCompletionHandler)(BOOL success);
@property (nonatomic, assign) BOOL isProbing;
@end

@implementation BHTSilentCookieWebViewProber

+ (instancetype)sharedInstance {
    static BHTSilentCookieWebViewProber *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)probeForCookiesWithCompletion:(void (^)(BOOL success))completionHandler {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isProbing) {
            NSLog(@"TweetSourceTweak: Silent probe already in progress.");
            if (completionHandler) {
                completionHandler(NO); // Indicate failure because another probe is active
            }
            return;
        }

        NSLog(@"TweetSourceTweak: Starting silent webview probe for cookies.");
        self.isProbing = YES;
        self.currentCompletionHandler = completionHandler;

        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
        
        self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
        self.webView.navigationDelegate = self;
        
        // The webView must be in the view hierarchy to perform loading.
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (!keyWindow) {
            keyWindow = [[UIApplication sharedApplication].windows firstObject]; // Fallback
        }
        
        if (keyWindow) {
            [keyWindow addSubview:self.webView];
        } else {
            NSLog(@"TweetSourceTweak: Could not find keyWindow to add silent webview.");
            [self completeProbeWithSuccess:NO];
            return;
        }

        NSURL *url = [NSURL URLWithString:PROBE_URL];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
    });
}

- (void)completeProbeWithSuccess:(BOOL)success {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"TweetSourceTweak: Silent webview probe finished (success: %@).", success ? @"YES" : @"NO");
        if (self.webView) {
            [self.webView stopLoading];
            [self.webView removeFromSuperview];
            self.webView.navigationDelegate = nil;
            self.webView = nil;
        }
        
        if (self.currentCompletionHandler) {
            self.currentCompletionHandler(success);
            self.currentCompletionHandler = nil;
        }
        self.isProbing = NO;
    });
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"TweetSourceTweak: Silent webview didFinishNavigation.");
    [self completeProbeWithSuccess:YES];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"TweetSourceTweak: Silent webview didFailNavigation with error: %@", error);
    [self completeProbeWithSuccess:NO];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"TweetSourceTweak: Silent webview didFailProvisionalNavigation with error: %@", error);
    [self completeProbeWithSuccess:NO];
}

// This might be called if the web content process terminates
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"TweetSourceTweak: Silent webview webContentProcessDidTerminate.");
    [self completeProbeWithSuccess:NO];
}

@end 