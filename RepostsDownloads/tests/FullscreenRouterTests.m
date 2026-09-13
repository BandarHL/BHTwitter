#import <Foundation/Foundation.h>
#import "../BHRDFullscreenActionRouter.h"
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) {
    checks++;
    if (!pass) { NSLog(@"FAIL: %@", name); exit(1); }
}
static void NextEvent(void) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]]; }
int main(void) {
    @autoreleasepool {
        BHRDFullscreenActionRouter *router = [BHRDFullscreenActionRouter new];
        Check(![router activate], @"An unconfigured router never consumes the host action");
        __block BOOL enabled = YES;
        __block NSArray *currentMedia = @[@"video-A"];
        __block NSUInteger resolutions = 0, downloads = 0, errors = 0, shares = 0;
        __block NSArray *receivedMedia = nil;
        router.isEnabled = ^BOOL { return enabled; };
        router.resolveMedia = ^NSArray * { resolutions++; return currentMedia; };
        router.showDownloads = ^(NSArray *media) { downloads++; receivedMedia = media; };
        router.showUnavailable = ^{ errors++; };
        if (![router activate]) shares++;
        Check(downloads == 1 && shares == 0 && errors == 0, @"Enabled activation opens download instead of share");
        Check([receivedMedia isEqual:@[@"video-A"]], @"Download receives the active media");
        if (![router activate]) shares++;
        Check(downloads == 1 && resolutions == 1 && shares == 0, @"Multiple target-actions for one event are consumed without a duplicate menu");
        enabled = NO;
        if (![router activate]) shares++;
        Check(shares == 1 && downloads == 1, @"Turning off the setting restores sharing even in the same event turn");
        NextEvent();
        enabled = YES;
        currentMedia = @[@"video-B", @"video-C"];
        Check([router activate], @"A later activation is accepted");
        Check(downloads == 2 && [receivedMedia isEqual:currentMedia], @"Reused full-screen control resolves the current video rather than stale layout data");
        NextEvent();
        currentMedia = @[];
        if (![router activate]) shares++;
        Check(errors == 1 && downloads == 2 && shares == 1, @"Missing media shows an error and never falls through to sharing");
        Check([router activate] && errors == 1, @"Missing-media failures are deduplicated too");
        NextEvent();
        currentMedia = nil;
        Check([router activate] && errors == 2, @"Nil media is consumed safely");
        NextEvent();
        enabled = NO;
        NSUInteger previousResolutions = resolutions;
        Check(![router activate] && resolutions == previousResolutions, @"Off-screen/disabled routes do not resolve or consume media");
        enabled = YES;
        currentMedia = @[@"video-D"];
        Check([router activate] && downloads == 3, @"Re-enabling starts downloads again");
        NextEvent();
        router.resolveMedia = nil;
        Check([router activate] && errors == 3, @"Missing resolver cannot invoke the share action");
        NextEvent();
        router.retryOnUnavailable = YES;
        __block NSUInteger retryCalls = 0;
        router.resolveMedia = ^NSArray * { retryCalls++; return retryCalls < 2 ? nil : @[@"loaded-video"]; };
        Check([router activate] && [router activate] && retryCalls == 1, @"Transient-load retries coalesce repeated taps");
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
        Check(downloads == 4 && errors == 3 && retryCalls == 2, @"A transiently missing model opens downloads once it becomes available");
        NextEvent();
        router.resolveMedia = ^NSArray * { return nil; };
        [router activate]; enabled = NO;
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
        Check(errors == 3 && downloads == 4, @"Leaving fullscreen during retry suppresses late menus and errors");
        NSLog(@"PASS: %lu fullscreen routing checks", (unsigned long)checks);
    }
    return 0;
}
