#import <Foundation/Foundation.h>
#import "../BHRDShareImageFetch.h"
#import "../BHRDShareMediaQuality.h"
@interface BHRDShareImageFetch (FixturePolicy)
+ (instancetype)fetchURL:(NSURL *)url budget:(BHRDShareImageBudget *)budget allowedURL:(BOOL (^)(NSURL *))allowedURL completion:(void (^)(NSData *, NSError *))completion;
@end
static NSUInteger checks;
static void Check(BOOL value, NSString *message) { checks++; if (!value) { NSLog(@"FAIL: %@", message); exit(1); } }
static void Pump(NSTimeInterval seconds) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]]; }
static void Await(BOOL (^done)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:8];
    while (!done() && deadline.timeIntervalSinceNow > 0) Pump(0.005);
    Check(done(), @"Network fixture completed within deadline");
}
int main(int argc, const char **argv) { @autoreleasepool {
    Check(argc == 2, @"Fixture HTTP origin supplied");
    NSURL *base = [NSURL URLWithString:[NSString stringWithUTF8String:argv[1]]];
    BOOL (^allowed)(NSURL *) = ^BOOL(NSURL *url) { return [url.scheme isEqual:base.scheme] && [url.host isEqual:base.host] && [url.port isEqual:base.port]; };
    Check(BHRDShareImageURLAllowed([NSURL URLWithString:@"https://pbs.twimg.com/media/a.jpg"]), @"Image CDN allowed");
    Check(BHRDShareImageURLAllowed([NSURL URLWithString:@"https://abs.twimg.com/sticky/default.png"]), @"Static avatar CDN allowed");
    for (NSString *url in @[@"http://pbs.twimg.com/a", @"https://pbs.twimg.com.evil.example/a", @"https://example.com/a", @"file:///tmp/a.png", @"https://pbs.twimg.com:444/a", @"https://u:p@pbs.twimg.com/a"]) {
        Check(!BHRDShareImageURLAllowed([NSURL URLWithString:url]), @"Reject non-HTTPS, unknown origin, credentials and nonstandard port");
    }
    __block NSUInteger callbackCount = 0;
    BHRDShareImageBudget *budget = [[BHRDShareImageBudget alloc] initWithLimit:BHRDShareImageAggregateByteLimit];
    __block NSError *error = nil; __block NSData *received = nil;
    [BHRDShareImageFetch fetchURL:base budget:budget completion:^(NSData *data, NSError *err) { callbackCount++; received = data; error = err; }];
    Await(^BOOL { return callbackCount > 0; });
    Check(error.code == NSURLErrorUnsupportedURL && !received, @"Production factory rejects untrusted initial origin before networking");
    NSArray *paths = @[@"/image", @"/unknown", @"/redirect", @"/error-image", @"/wrong-mime", @"/declared-large", @"/chunked-large", @"/pixels", @"/redirect-forbidden", @"/redirect-loop"];
    for (NSUInteger index = 0; index < paths.count; index++) {
        callbackCount = 0; error = nil; received = nil;
        budget = [[BHRDShareImageBudget alloc] initWithLimit:BHRDShareImageAggregateByteLimit];
        [BHRDShareImageFetch fetchURL:[base URLByAppendingPathComponent:paths[index]] budget:budget allowedURL:allowed completion:^(NSData *data, NSError *err) {
            Check(NSThread.isMainThread, @"Streaming completion is serialized on main"); callbackCount++; received = data; error = err;
        }];
        Await(^BOOL { return callbackCount > 0; });
        BOOL valid = index < 3;
        Check(valid ? received.length && !error && BHRDShareImagePixelSize(received).width == 1 : !received && error != nil,
              [NSString stringWithFormat:@"HTTP/metadata fixture %@ enforces acceptance policy", paths[index]]);
        Check(budget.usedBytes == (valid ? received.length : 0), @"Rejected buffers release reservations; accepted bytes stay budgeted");
        if ([paths[index] isEqual:@"/chunked-large"]) Check(error.code == NSURLErrorDataLengthExceedsMaximum, @"Unknown-length oversized chunks cancel at byte limit before decoding");
        Pump(0.02); Check(callbackCount == 1, @"Failure and late task completion report exactly once");
    }
    // Two parallel 7 MiB images share one 12 MiB reservation ledger.
    budget = [[BHRDShareImageBudget alloc] initWithLimit:12 * 1024 * 1024];
    callbackCount = 0; __block NSUInteger acceptedBytes = 0, budgetFailures = 0;
    for (NSUInteger worker = 0; worker < 2; worker++) {
        [BHRDShareImageFetch fetchURL:[base URLByAppendingPathComponent:@"/padded"] budget:budget allowedURL:allowed completion:^(NSData *data, NSError *err) {
            callbackCount++; acceptedBytes += data.length;
            if (err.code == NSURLErrorDataLengthExceedsMaximum) budgetFailures++;
        }];
    }
    __block NSUInteger maximumBytes = 0;
    Await(^BOOL { maximumBytes = MAX(maximumBytes, budget.usedBytes); return callbackCount == 2; });
    Check(maximumBytes <= 12 * 1024 * 1024, @"Aggregate reservation stays bounded during simultaneous receives");
    Check(acceptedBytes <= 12 * 1024 * 1024 && budgetFailures >= 1, @"Concurrent workers cannot bypass shared aggregate budget");
    Check(budget.usedBytes == acceptedBytes, @"Aggregate retains only accepted image bytes");
    callbackCount = 0; received = nil; error = nil;
    budget = [[BHRDShareImageBudget alloc] initWithLimit:BHRDShareImageAggregateByteLimit];
    BHRDShareImageFetch *cancelled = [BHRDShareImageFetch fetchURL:[base URLByAppendingPathComponent:@"/slow"] budget:budget allowedURL:allowed completion:^(NSData *data, NSError *err) { callbackCount++; received = data; error = err; }];
    Pump(0.04); [cancelled cancel]; [cancelled cancel]; Pump(0.4);
    Check(callbackCount == 1 && !received && error.code == NSURLErrorCancelled && budget.usedBytes == 0, @"Close cancels pending receive and late body cannot publish or consume budget");
    NSLog(@"PASS: %lu share image origin, response, streaming, pixel and cancellation checks", (unsigned long)checks);
} return 0; }
