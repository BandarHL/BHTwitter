#pragma once
#import <Foundation/Foundation.h>

// Records display callback cadence, not GPU-rendered FPS or battery consumption.
// All timestamps use a single monotonic clock. Visibility transitions reset the
// frame baseline so background/suspended time never becomes a slow interval.
@interface BHRDPerformanceStats : NSObject
- (void)setVisible:(BOOL)visible atTime:(NSTimeInterval)time;
- (void)recordFrameAtTime:(NSTimeInterval)time;
- (void)recordMemoryBytes:(uint64_t)bytes source:(NSString *)source;
- (void)recordThermalState:(NSString *)state;
- (void)recordMemoryWarning;
- (NSDictionary *)summaryAtTime:(NSTimeInterval)time;
@end
