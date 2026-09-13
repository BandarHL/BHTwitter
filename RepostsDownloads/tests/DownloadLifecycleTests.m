#import <Foundation/Foundation.h>
#import "../BHRDDownload.h"
#import "../BHRDTaskState.h"
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) {
    checks++;
    if (!pass) { NSLog(@"FAIL: %@", name); exit(1); }
}
static void Pump(NSTimeInterval duration) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:duration]]; }
@interface Recorder : NSObject <BHRDDownloadDelegate>
@property(nonatomic) NSUInteger successes;
@property(nonatomic) NSUInteger failures;
@property(nonatomic, strong) NSError *error;
@property(nonatomic, strong) NSData *data;
@end
@implementation Recorder
- (void)downloadProgress:(float)progress {}
- (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)name { self.successes++; self.data = [NSData dataWithContentsOfURL:filePath]; }
- (void)downloadDidFailureWithError:(NSError *)error { self.failures++; self.error = error; }
@end
static void Wait(Recorder *recorder) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:8];
    while (!recorder.successes && !recorder.failures && deadline.timeIntervalSinceNow > 0) Pump(0.02);
    Check(recorder.successes + recorder.failures == 1, @"A download reaches exactly one terminal callback");
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *base = [NSString stringWithUTF8String:argv[1]];
        __block NSUInteger cancellations = 0;
        BHRDTaskState *late = [BHRDTaskState new];
        Check([late cancel], @"Cancellation can win before the native session is assigned");
        late.cancelHandler = ^{ cancellations++; };
        Check(cancellations == 1, @"Late native session registration is cancelled immediately");
        Check(![late finish] && ![late cancel], @"Late completion and duplicate cancellation are ignored");
        BHRDTaskState *success = [BHRDTaskState new];
        success.cancelHandler = ^{ cancellations++; };
        Check([success finish] && ![success cancel] && cancellations == 1, @"Finishing releases cancellation without cancelling a completed task");
        BHRDTaskState *race = [BHRDTaskState new];
        __block NSUInteger winners = 0;
        dispatch_apply(40, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t i) {
            BOOL won = i % 2 ? [race cancel] : [race finish];
            if (won) @synchronized(race) { winners++; }
        });
        Check(winners == 1, @"Concurrent completion/cancellation has exactly one winner");

        Recorder *normal = [Recorder new]; BHRDDownload *a = [BHRDDownload new]; a.delegate = normal;
        [a downloadFileWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/ok"]]]; Wait(normal);
        Check(normal.successes == 1 && [normal.data isEqual:[@"test-video" dataUsingEncoding:NSUTF8StringEncoding]], @"Normal download preserves the temporary file through its callback");
        [a cancel]; Pump(0.1);
        Check(normal.failures == 0 && a.delegate == nil, @"Late cancel does not convert successful download into failure");

        Recorder *cancelled = [Recorder new]; BHRDDownload *b = [BHRDDownload new]; b.delegate = cancelled;
        [b downloadFileWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/slow"]]]; Pump(0.2);
        Recorder *busy = [Recorder new]; BHRDDownload *duplicate = [BHRDDownload new]; duplicate.delegate = busy;
        [duplicate downloadFileWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/ok"]]]; Wait(busy);
        Check(busy.failures == 1 && [busy.error.domain isEqual:@"BHRDBusy"], @"A second live HTTP transfer is rejected without replacing the first");
        Check(cancelled.failures == 0 && cancelled.successes == 0, @"Rejecting another owner does not cancel the active transfer");
        [b cancel];
        Check(cancelled.failures == 1 && cancelled.error.code == NSURLErrorCancelled, @"Manual cancel notifies synchronously so the progress UI can close immediately");
        [b cancel];
        Recorder *restart = [Recorder new]; BHRDDownload *c = [BHRDDownload new]; c.delegate = restart;
        [c downloadFileWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/ok"]]]; Wait(restart); Pump(0.2);
        Check(cancelled.successes == 0 && cancelled.failures == 1 && b.delegate == nil, @"Cancelled task cannot deliver a late save or retain its UI handler");
        Check(restart.successes == 1 && restart.failures == 0, @"A new download works immediately after cancellation");

        Recorder *stalled = [Recorder new]; BHRDDownload *d = [[BHRDDownload alloc] initWithStallTimeout:1]; d.delegate = stalled;
        [d downloadFileWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/stall"]]]; Wait(stalled);
        Check(stalled.failures == 1 && stalled.error.code == NSURLErrorTimedOut && stalled.successes == 0, @"No-progress server is stopped with a timeout");
        Pump(0.2); Check(stalled.failures == 1 && d.delegate == nil, @"Timeout cancellation cannot send a second terminal callback");

        Recorder *bad = [Recorder new]; BHRDDownload *e = [BHRDDownload new]; e.delegate = bad;
        [e downloadFileWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/bad"]]]; Wait(bad);
        Check(bad.failures == 1 && bad.successes == 0, @"HTTP error cannot be saved as a video");
        NSLog(@"PASS: %lu task-state and real HTTP lifecycle checks", (unsigned long)checks);
    }
    return 0;
}
