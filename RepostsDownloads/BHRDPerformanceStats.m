#import "BHRDPerformanceStats.h"
#import <math.h>

@implementation BHRDPerformanceStats {
    BOOL _visible;
    BOOL _hasFrame;
    NSTimeInterval _visibleSince;
    NSTimeInterval _visibleSeconds;
    NSTimeInterval _lastFrame;
    NSUInteger _intervals;
    NSUInteger _slowIntervals;
    NSTimeInterval _maxInterval;
    uint64_t _memoryBytes;
    uint64_t _peakMemoryBytes;
    NSString *_memorySource;
    NSString *_thermalState;
    NSUInteger _memoryWarnings;
}
- (void)setVisible:(BOOL)visible atTime:(NSTimeInterval)time {
    if (!isfinite(time) || time < _visibleSince || visible == _visible) return;
    if (_visible) _visibleSeconds += MAX(0, time - _visibleSince);
    _visible = visible;
    _visibleSince = time;
    _hasFrame = NO;
}
- (void)recordFrameAtTime:(NSTimeInterval)time {
    if (!_visible || !isfinite(time) || time < _visibleSince) return;
    if (!_hasFrame) { _lastFrame = time; _hasFrame = YES; return; }
    NSTimeInterval delta = time - _lastFrame;
    if (delta <= 0) return;
    _lastFrame = time;
    _intervals++;
    if (delta > .05) _slowIntervals++;
    _maxInterval = MAX(_maxInterval, delta);
}
- (void)recordMemoryBytes:(uint64_t)bytes source:(NSString *)source {
    if (!bytes || !source.length) return;
    // Do not compare resident bytes and physical-footprint bytes in one peak.
    if (_memorySource && ![_memorySource isEqualToString:source]) _peakMemoryBytes = 0;
    _memorySource = [source copy];
    _memoryBytes = bytes;
    _peakMemoryBytes = MAX(_peakMemoryBytes, bytes);
}
- (void)recordThermalState:(NSString *)state { if (state.length) _thermalState = [state copy]; }
- (void)recordMemoryWarning { _memoryWarnings++; }
- (NSDictionary *)summaryAtTime:(NSTimeInterval)time {
    NSTimeInterval seconds = _visibleSeconds;
    if (_visible && isfinite(time)) seconds += MAX(0, time - _visibleSince);
    BOOL observed = seconds >= 30 && _intervals >= 120;
    NSString *reason = observed ? @"" : (!_intervals ? @"no_frame_samples" : (seconds < 30 ? @"insufficient_visible_time" : @"insufficient_frame_samples"));
    return @{@"status":observed ? @"observed" : @"pending", @"pendingReason":reason,
        @"active":@(_visible), @"visibleSeconds":@(seconds), @"frameIntervals":@(_intervals),
        @"slowIntervals":@(_slowIntervals), @"slowIntervalThresholdMs":@50,
        @"slowIntervalRatio":_intervals ? @((double)_slowIntervals/_intervals) : (id)NSNull.null,
        @"maxIntervalMs":_intervals ? @(_maxInterval*1000) : (id)NSNull.null,
        @"memoryMB":_memoryBytes ? @((double)_memoryBytes/(1024*1024)) : (id)NSNull.null,
        @"peakMemoryMB":_peakMemoryBytes ? @((double)_peakMemoryBytes/(1024*1024)) : (id)NSNull.null,
        @"memorySource":_memorySource ?: @"unavailable", @"thermalState":_thermalState ?: @"unavailable",
        @"memoryWarnings":@(_memoryWarnings), @"measurement":@"visible_display_callback_cadence"};
}
@end
