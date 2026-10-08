#import "BHRDPerformanceMonitor.h"
#import "BHRDPerformanceStats.h"
#import "BHRDAvatarDiagnostics.h"
#import "BHRDAcceptance.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>

static NSString *ThermalState(void) {
    switch (NSProcessInfo.processInfo.thermalState) {
        case NSProcessInfoThermalStateNominal: return @"nominal";
        case NSProcessInfoThermalStateFair: return @"fair";
        case NSProcessInfoThermalStateSerious: return @"serious";
        case NSProcessInfoThermalStateCritical: return @"critical";
    }
    return @"unknown";
}

@interface BHRDPerformanceMonitor : NSObject
@property(nonatomic, strong) BHRDPerformanceStats *stats;
@property(nonatomic, strong) CADisplayLink *displayLink;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, weak) UIScene *sourceScene;
@property(nonatomic) BOOL sceneBound;
@property(nonatomic) BOOL running;
@property(nonatomic) NSTimeInterval startTime;
@property(nonatomic) NSTimeInterval endTime;
@property(nonatomic) NSTimeInterval lastSample;
@property(nonatomic, copy) NSString *sessionID;
@property(nonatomic, copy) NSString *acceptanceSession;
@property(nonatomic, copy) NSString *stopReason;
@property(nonatomic, strong) NSDate *startedAt;
- (void)startInScene:(UIScene *)scene;
- (void)stopWithReason:(NSString *)reason;
- (NSDictionary *)summary;
@end

// CADisplayLink retains its target. A weak forwarder keeps the monitor's
// sampling resources independently releasable when a run ends.
@interface BHRDPerformanceDisplayTarget : NSObject
@property(nonatomic, weak) BHRDPerformanceMonitor *monitor;
- (void)frame:(CADisplayLink *)link;
@end

@interface BHRDPerformanceMonitor (DisplayCallback)
- (void)frame:(CADisplayLink *)link;
@end

@implementation BHRDPerformanceDisplayTarget
- (void)frame:(CADisplayLink *)link { [self.monitor frame:link]; }
@end

@implementation BHRDPerformanceMonitor
- (instancetype)init {
    if ((self = [super init])) {
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(resignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [center addObserver:self selector:@selector(activityChanged:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:@selector(activityChanged:) name:UISceneDidActivateNotification object:nil];
        [center addObserver:self selector:@selector(sceneWillDeactivate:) name:UISceneWillDeactivateNotification object:nil];
        [center addObserver:self selector:@selector(sceneDisconnected:) name:UISceneDidDisconnectNotification object:nil];
        [center addObserver:self selector:@selector(memoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_displayLink invalidate];
    [_timer invalidate];
}
- (BOOL)sourceActive {
    if (!self.running || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return NO;
    return !self.sceneBound || (self.sourceScene && self.sourceScene.activationState == UISceneActivationStateForegroundActive);
}
- (void)updateVisibility {
    BOOL active = [self sourceActive];
    [self.stats setVisible:active atTime:CACurrentMediaTime()];
    self.displayLink.paused = !active;
}
- (void)sampleMemory {
    task_vm_info_data_t vmInfo = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &count);
    if (result == KERN_SUCCESS && count >= TASK_VM_INFO_REV1_COUNT && vmInfo.phys_footprint > 0) {
        [self.stats recordMemoryBytes:vmInfo.phys_footprint source:@"physical_footprint"];
    } else {
        mach_task_basic_info_data_t basic = {0};
        count = MACH_TASK_BASIC_INFO_COUNT;
        if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&basic, &count) == KERN_SUCCESS)
            [self.stats recordMemoryBytes:basic.resident_size source:@"resident_size"];
    }
    [self.stats recordThermalState:ThermalState()];
}
- (void)startInScene:(UIScene *)scene {
    if (self.running) return;
    self.stats = [BHRDPerformanceStats new];
    self.sourceScene = scene;
    self.sceneBound = scene != nil;
    self.sessionID = NSUUID.UUID.UUIDString;
    self.acceptanceSession = BHRDAcceptanceCurrentSessionIdentifier();
    self.startedAt = NSDate.date;
    self.startTime = CACurrentMediaTime();
    self.endTime = 0;
    self.lastSample = self.startTime;
    self.stopReason = @"";
    self.running = YES;
    BHRDPerformanceDisplayTarget *target = [BHRDPerformanceDisplayTarget new];
    target.monitor = self;
    self.displayLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(frame:)];
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    __weak BHRDPerformanceMonitor *weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) { [weakSelf tick]; }];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    [self updateVisibility];
    [self sampleMemory];
    BHRDAvatarLog(@"performance_started", [self summary]);
}
- (void)frame:(CADisplayLink *)link {
    if (CACurrentMediaTime()-self.startTime >= 20*60) { [self stopWithReason:@"time_limit"]; return; }
    if (![self sourceActive]) { [self updateVisibility]; return; }
    [self.stats recordFrameAtTime:link.timestamp];
}
- (void)tick {
    if (!self.running) return;
    NSTimeInterval now = CACurrentMediaTime();
    if (now-self.startTime >= 20*60) { [self stopWithReason:@"time_limit"]; return; }
    [self updateVisibility];
    if (![self sourceActive] || now-self.lastSample < 15) return;
    self.lastSample = now;
    [self sampleMemory];
    BHRDAvatarLog(@"performance_sample", [self summary]);
}
- (void)stopWithReason:(NSString *)reason {
    if (!self.running) return;
    if ([self sourceActive]) [self sampleMemory];
    self.endTime = CACurrentMediaTime();
    [self.stats setVisible:NO atTime:self.endTime];
    self.running = NO;
    self.stopReason = reason;
    [self.displayLink invalidate]; self.displayLink = nil;
    [self.timer invalidate]; self.timer = nil;
    BHRDAvatarLog(@"performance_finished", [self summary]);
}
- (NSDictionary *)summary {
    if (!self.stats) return @{@"status":@"pending", @"pendingReason":@"measurement_not_started", @"running":@NO,
        @"active":@NO, @"visibleSeconds":@0, @"frameIntervals":@0, @"memoryMB":NSNull.null,
        @"peakMemoryMB":NSNull.null, @"slowIntervalRatio":NSNull.null, @"maxIntervalMs":NSNull.null,
        @"memorySource":@"unavailable", @"thermalState":@"unavailable", @"memoryWarnings":@0,
        @"measurement":@"visible_display_callback_cadence", @"maximumSeconds":@(20*60),
        @"batteryMeasurement":@"unavailable"};
    NSTimeInterval measuredUntil = self.running ? CACurrentMediaTime() : self.endTime;
    NSMutableDictionary *result = [[self.stats summaryAtTime:measuredUntil] mutableCopy];
    result[@"running"] = @(self.running);
    result[@"sessionID"] = self.sessionID;
    result[@"acceptanceSession"] = self.acceptanceSession ?: @"";
    result[@"startedAt"] = @([self.startedAt timeIntervalSince1970]);
    result[@"elapsedSeconds"] = @(MAX(0,measuredUntil-self.startTime));
    result[@"maximumSeconds"] = @(20*60);
    result[@"stopReason"] = self.stopReason;
    result[@"batteryMeasurement"] = @"unavailable";
    return result;
}
- (void)resignActive:(NSNotification *)notification {
    [self.stats setVisible:NO atTime:CACurrentMediaTime()]; self.displayLink.paused = YES;
}
- (void)activityChanged:(NSNotification *)notification { if (self.running) [self tick]; }
- (void)sceneWillDeactivate:(NSNotification *)notification {
    if (self.sceneBound && notification.object == self.sourceScene) [self resignActive:notification];
}
- (void)sceneDisconnected:(NSNotification *)notification {
    if (self.running && self.sceneBound && notification.object == self.sourceScene) [self stopWithReason:@"source_scene_disconnected"];
}
- (void)memoryWarning:(NSNotification *)notification {
    if (!self.running) return;
    [self.stats recordMemoryWarning];
    [self sampleMemory];
    BHRDAvatarLog(@"performance_memory_warning", [self summary]);
}
@end

static BHRDPerformanceMonitor *Monitor(void) {
    static BHRDPerformanceMonitor *monitor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ monitor = [BHRDPerformanceMonitor new]; });
    return monitor;
}
static void OnMain(dispatch_block_t operation) {
    if (NSThread.isMainThread) operation();
    else dispatch_sync(dispatch_get_main_queue(), operation);
}
void BHRDPerformanceStartInScene(UIScene *scene) { OnMain(^{ [Monitor() startInScene:scene]; }); }
void BHRDPerformanceStart(void) {
    OnMain(^{
        UIScene *activeScene = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) { activeScene = scene; break; }
        }
        [Monitor() startInScene:activeScene];
    });
}
void BHRDPerformanceStop(void) { OnMain(^{ [Monitor() stopWithReason:@"user_stopped"]; }); }
NSDictionary *BHRDPerformanceCurrentSummary(void) {
    __block NSDictionary *summary;
    OnMain(^{ summary = [Monitor() summary]; });
    return summary;
}
