#import <Foundation/Foundation.h>
#import "../BHRDPerformanceStats.h"
#import <math.h>

static NSUInteger checks;
static void Check(BOOL condition, NSString *message) {
    checks++;
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}
static BOOL Near(double a, double b) { return fabs(a-b)<.00001; }
int main(void) {
    @autoreleasepool {
        BHRDPerformanceStats *stats = [BHRDPerformanceStats new];
        NSDictionary *summary = [stats summaryAtTime:10];
        Check([summary[@"status"] isEqual:@"pending"], @"No data stays pending");
        Check([summary[@"pendingReason"] isEqual:@"no_frame_samples"], @"Pending identifies absent samples");
        Check(summary[@"slowIntervalRatio"] == NSNull.null && summary[@"maxIntervalMs"] == NSNull.null, @"No data has no fabricated zero interval metrics");
        Check(summary[@"memoryMB"] == NSNull.null, @"Missing memory is unavailable");
        [stats recordFrameAtTime:10];
        Check([[stats summaryAtTime:10][@"frameIntervals"] unsignedIntegerValue] == 0, @"Background frames ignored");
        [stats setVisible:YES atTime:10];
        [stats recordFrameAtTime:9];
        [stats recordFrameAtTime:10];
        [stats recordFrameAtTime:10+1.0/60];
        [stats recordFrameAtTime:10+2.0/60];
        [stats recordFrameAtTime:10.2];
        [stats recordFrameAtTime:10.2];
        [stats recordFrameAtTime:10.1];
        [stats recordFrameAtTime:NAN];
        summary = [stats summaryAtTime:12];
        Check([summary[@"frameIntervals"] unsignedIntegerValue] == 3, @"Valid intervals counted; duplicate and backward callbacks ignored");
        Check([summary[@"slowIntervals"] unsignedIntegerValue] == 1, @"50ms interval threshold measures delayed callbacks");
        Check(Near([summary[@"slowIntervalRatio"] doubleValue], 1.0/3), @"Slow interval ratio computed from observed callbacks");
        Check(Near([summary[@"maxIntervalMs"] doubleValue], 1000.0/6), @"Maximum cadence delay reported");
        Check(Near([summary[@"visibleSeconds"] doubleValue], 2), @"Visible duration uses foreground elapsed time");
        Check([summary[@"status"] isEqual:@"pending"], @"Short run cannot be marked observed");
        [stats setVisible:NO atTime:12];
        [stats recordFrameAtTime:100];
        summary = [stats summaryAtTime:100];
        Check(Near([summary[@"visibleSeconds"] doubleValue], 2), @"Background time excluded from visible duration");
        Check([summary[@"active"] isEqual:@NO], @"Background state reflected");
        [stats setVisible:YES atTime:100];
        [stats recordFrameAtTime:100];
        [stats recordFrameAtTime:100+1.0/60];
        summary = [stats summaryAtTime:101];
        Check([summary[@"frameIntervals"] unsignedIntegerValue] == 4, @"Foreground re-entry starts new callback baseline");
        Check([summary[@"slowIntervals"] unsignedIntegerValue] == 1, @"Suspension gap is not a slow callback");
        Check(Near([summary[@"maxIntervalMs"] doubleValue], 1000.0/6), @"Suspension gap is excluded from maximum delay");
        [stats recordMemoryBytes:128*1024*1024 source:@"physical_footprint"];
        [stats recordMemoryBytes:96*1024*1024 source:@"physical_footprint"];
        [stats recordMemoryBytes:0 source:@"physical_footprint"];
        [stats recordThermalState:@"serious"];
        [stats recordMemoryWarning];
        summary = [stats summaryAtTime:101];
        Check(Near([summary[@"memoryMB"] doubleValue], 96), @"Memory is current sampled process footprint");
        Check(Near([summary[@"peakMemoryMB"] doubleValue], 128), @"Peak sampled footprint preserved");
        Check([summary[@"thermalState"] isEqual:@"serious"], @"Thermal state does not become pass/fail");
        Check([summary[@"memoryWarnings"] unsignedIntegerValue] == 1, @"System memory warnings are counted");
        [stats recordMemoryBytes:90*1024*1024 source:@"resident_size"];
        summary = [stats summaryAtTime:101];
        Check(Near([summary[@"peakMemoryMB"] doubleValue], 90) && [summary[@"memorySource"] isEqual:@"resident_size"], @"Resident and footprint peaks never mixed");
        [stats setVisible:NO atTime:102];
        [stats setVisible:YES atTime:101];
        Check([[stats summaryAtTime:105][@"active"] isEqual:@NO], @"Backward visibility transition ignored");
        BHRDPerformanceStats *longStats = [BHRDPerformanceStats new];
        [longStats setVisible:YES atTime:0];
        [longStats recordFrameAtTime:0];
        for (NSUInteger index=1;index<=1800;index++) [longStats recordFrameAtTime:index/60.0];
        summary = [longStats summaryAtTime:30];
        Check([summary[@"status"] isEqual:@"observed"], @"Enough visible data is marked observed, not passed");
        Check(!summary[@"success"] && !summary[@"fps"] && !summary[@"batteryUsage"], @"No unmeasured success, rendered FPS, or battery metric");
        Check([summary[@"slowIntervals"] unsignedIntegerValue] == 0, @"Smooth callback cadence has no delayed intervals");
        BHRDPerformanceStats *insufficientFrames = [BHRDPerformanceStats new];
        [insufficientFrames setVisible:YES atTime:0];
        [insufficientFrames recordFrameAtTime:0];
        [insufficientFrames recordFrameAtTime:31];
        summary = [insufficientFrames summaryAtTime:31];
        Check([summary[@"pendingReason"] isEqual:@"insufficient_frame_samples"], @"Long run with few callbacks is still pending");
        Check(Near([summary[@"maxIntervalMs"] doubleValue],31000), @"Active long stall remains visible in data");
        NSData *json = [NSJSONSerialization dataWithJSONObject:summary options:0 error:nil];
        Check(json.length > 0, @"Summary is directly exportable JSON without private identities");
        printf("PASS: %lu performance sampling checks\n", (unsigned long)checks);
    }
    return 0;
}
