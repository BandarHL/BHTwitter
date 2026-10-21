#import "StreamJobFixture.h"
#import "../BHRDTaskState.h"
#include <stdlib.h>

static NSUInteger Checks;
static void Check(BOOL value, NSString *name) { Checks++; if (!value) { NSLog(@"FAIL: %@",name); exit(1); } }
static void Pump(NSTimeInterval duration) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:duration]]; }
static BOOL SlotAvailable(void) {
    NSObject *owner=[NSObject new]; BOOL available=BHRDTryBeginTransfer(owner); BHRDEndTransfer(owner); return available;
}
static BOOL NoLiveHUD(void) { for (JGProgressHUD *hud in BHRDFixtureHUDs) if (hud.visible || hud.cancel) return NO; return YES; }
static BOOL MonitorsStopped(BHRDStreamJob *job) { return ![job valueForKey:@"watchdog"] && ![job valueForKey:@"selectionWatchdog"] && ![job valueForKey:@"selectionStillCurrent"]; }
static NSUInteger EventCount(NSString *name) {
    NSUInteger count=0; for (NSDictionary *event in BHRDFixtureEvents) if ([event[@"event"] isEqual:name]) count++; return count;
}

int main(void) { @autoreleasepool {
    BHRDFixtureSessions=[NSMutableArray array]; BHRDFixtureHUDs=[NSMutableArray array]; BHRDFixtureEvents=[NSMutableArray array];
    NSURL *url=[NSURL URLWithString:@"https://video.twimg.com/amplify_video/123/pl/master.m3u8"];
    __block BOOL current=YES, checksOnMain=YES;
    __block NSUInteger selectionChecks=0, completions=0;
    __block NSError *resultError=nil;
    BOOL (^selection)(void)=^{ selectionChecks++; checksOnMain &= NSThread.isMainThread; return current; };
    BHRDStreamJob *probe=[BHRDStreamJob probeURL:url selectionStillCurrent:selection completion:^(MediaInformation *info, NSError *error) {
        Check(NSThread.isMainThread && !info,@"Invalidation completes on main without a stale quality list"); completions++; resultError=error;
    }];
    BHRDFixtureSession *engine=BHRDFixtureSessions.lastObject;
    Check(engine && !SlotAvailable() && !NoLiveHUD(),@"Running probe owns the native engine, HUD and single transfer slot");
    Pump(1.1);
    Check(selectionChecks==2 && checksOnMain,@"Live selection checks run once per second on the main run loop");
    current=NO;
    CFRunLoopAddCommonMode(CFRunLoopGetMain(),CFSTR("BHRDTrackingFixture"));
    CFRunLoopRunInMode(CFSTR("BHRDTrackingFixture"),1.1,false);
    Check(engine.cancels==1 && completions==1 && resultError.code==NSURLErrorCancelled,@"Scrolling in a common tracking mode actively cancels the native probe before it reports a result");
    Check(NoLiveHUD() && SlotAvailable() && MonitorsStopped(probe),@"Swipe immediately dismisses HUD, stops both timers and releases transfer slot");
    NSUInteger stoppedChecks=selectionChecks; [engine deliverCompletion]; [probe cancel]; Pump(1.1);
    Check(completions==1 && selectionChecks==stoppedChecks && engine.cancels==1,@"Late result and duplicate cancel cannot restart checks or deliver a quality list");
    Check(EventCount(@"stream_probe_invalidated")==1 && BHRDFixtureAlerts==0,@"Selection cancellation records one fixed diagnostic and causes no error popup");

    // Completion can win the race with the next one-second monitor tick.
    current=YES; completions=0; resultError=nil;
    probe=[BHRDStreamJob probeURL:url selectionStillCurrent:selection completion:^(__unused MediaInformation *info, NSError *error) { completions++; resultError=error; }];
    engine=BHRDFixtureSessions.lastObject; current=NO; [engine deliverCompletion]; Pump(0.05);
    Check(completions==1 && resultError.code==NSURLErrorCancelled && engine.cancels==1,@"Callback revalidates immediately when a swipe precedes the next guard tick");
    Check(SlotAvailable() && NoLiveHUD() && MonitorsStopped(probe),@"Callback-race cancellation also releases all probe resources");

    // Simulate a native start that yields the run loop before returning its session.
    current=YES; completions=0; resultError=nil;
    BHRDFixtureBeforeBinding=^{ current=NO; Pump(1.1); };
    probe=[BHRDStreamJob probeURL:url selectionStillCurrent:selection completion:^(__unused MediaInformation *info, NSError *error) { completions++; resultError=error; }];
    engine=BHRDFixtureSessions.lastObject;
    Check(completions==1 && engine.cancels==1 && resultError.code==NSURLErrorCancelled,@"A native session bound after invalidation is cancelled immediately");
    Check(![probe valueForKey:@"engineSession"] && SlotAvailable() && NoLiveHUD(),@"Late binding does not revive a cancelled job or take back its slot");
    [engine deliverCompletion]; Pump(0.05); Check(completions==1,@"Late-bound engine completion remains terminally ignored");

    // Initial stale input must not start the engine, and completion stays async.
    NSUInteger engines=BHRDFixtureSessions.count; completions=0;
    probe=[BHRDStreamJob probeURL:url selectionStillCurrent:selection completion:^(__unused MediaInformation *info, NSError *error) { completions++; resultError=error; }];
    Check(completions==0 && BHRDFixtureSessions.count==engines,@"Initially invalid selection returns its job before cancellation and never starts FFprobe");
    current=YES; Pump(0.05);
    Check(completions==1 && resultError.code==NSURLErrorCancelled && MonitorsStopped(probe),@"An initially invalid selection cannot revive before its deferred cancellation");

    // A completed quality probe no longer owns selection checks. A user's final
    // download choice persists across swipes and is only stopped by explicit cancel.
    completions=0; resultError=nil;
    probe=[BHRDStreamJob probeURL:url selectionStillCurrent:selection completion:^(MediaInformation *info, NSError *error) { Check(info!=nil,@"Current probe passes valid quality information"); completions++; resultError=error; }];
    engine=BHRDFixtureSessions.lastObject;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ [engine deliverCompletion]; }); Pump(0.1);
    Check(completions==1 && !resultError && engine.cancels==0 && MonitorsStopped(probe),@"Successful quality discovery tears down its selection monitor without cancelling the engine");
    stoppedChecks=selectionChecks;
    __block NSUInteger downloadsDone=0;
    BHRDStreamJob *download=[BHRDStreamJob downloadURL:url streamIndex:@0 completion:^{ downloadsDone++; }];
    BHRDFixtureSession *downloadEngine=BHRDFixtureSessions.lastObject;
    current=NO; Pump(1.1);
    Check(downloadsDone==0 && downloadEngine.cancels==0 && !SlotAvailable() && selectionChecks==stoppedChecks,@"Confirmed stream download continues across later swipes");
    [download cancel]; [downloadEngine deliverCompletion]; Pump(0.05);
    Check(downloadsDone==1 && downloadEngine.cancels==1 && NoLiveHUD() && SlotAvailable(),@"Confirmed download still supports manual cancellation and immediate slot reuse");

    // Existing manual cancel, timeout and competing-owner behavior stay intact.
    current=YES; completions=0;
    probe=[BHRDStreamJob probeURL:url selectionStillCurrent:selection completion:^(__unused MediaInformation *info, NSError *error) { completions++; resultError=error; }];
    engine=BHRDFixtureSessions.lastObject;
    __block NSError *busyError=nil;
    BHRDStreamJob *busy=[BHRDStreamJob probeURL:url selectionStillCurrent:selection completion:^(__unused MediaInformation *info, NSError *error) { busyError=error; }]; Pump(0.05);
    Check([busyError.domain isEqual:@"BHRDBusy"] && !SlotAvailable() && engine.cancels==0 && MonitorsStopped(busy),@"Rejected competitor clears its guard without releasing the active owner's slot");
    JGProgressHUD *hud=BHRDFixtureHUDs.lastObject; hud.cancel();
    Check(completions==1 && resultError.code==NSURLErrorCancelled && MonitorsStopped(probe) && SlotAvailable(),@"HUD cancellation still synchronously stops probe and selection monitoring");
    [engine deliverCompletion]; Pump(0.05);
    completions=0;
    probe=[BHRDStreamJob probeURL:url selectionStillCurrent:selection completion:^(__unused MediaInformation *info, NSError *error) { completions++; resultError=error; }];
    engine=BHRDFixtureSessions.lastObject;
    [probe setValue:@(NSProcessInfo.processInfo.systemUptime-46) forKey:@"lastProgress"];
    [(NSTimer *)[probe valueForKey:@"watchdog"] fire];
    Check(completions==1 && resultError.code==NSURLErrorTimedOut && engine.cancels==1 && MonitorsStopped(probe),@"Existing 45-second timeout cancels both native probe and selection monitoring");
    [engine deliverCompletion]; Pump(0.05);
    Check(completions==1 && NoLiveHUD() && SlotAvailable(),@"Late timeout callback cannot reacquire UI or transfer resources");

    completions=0;
    probe=[BHRDStreamJob probeURL:[NSURL fileURLWithPath:@"/tmp/forbidden"] selectionStillCurrent:selection completion:^(__unused MediaInformation *info, NSError *error) { completions++; resultError=error; }]; Pump(0.05);
    Check(completions==1 && [resultError.domain isEqual:@"BHRDStream"] && MonitorsStopped(probe) && SlotAvailable(),@"Source rejection retains its guard and releases probe resources");

    completions=0;
    probe=[BHRDStreamJob probeURL:url completion:^(MediaInformation *info, NSError *error) { Check(info && !error,@"Unguarded probe still delivers valid quality information"); completions++; }];
    engine=BHRDFixtureSessions.lastObject;
    Check(![probe valueForKey:@"selectionWatchdog"],@"Existing unguarded callers never install a live-selection monitor");
    [engine deliverCompletion]; Pump(0.05);
    Check(completions==1 && engine.cancels==0 && SlotAvailable() && NoLiveHUD(),@"Unguarded compatibility API still completes and releases its resources");
    completions=0;
    probe=[BHRDStreamJob probeURL:url selectionStillCurrent:^BOOL { [NSException raise:@"HostUnavailable" format:@"fixture"]; return YES; }
        completion:^(__unused MediaInformation *info, NSError *error) { completions++; resultError=error; }]; Pump(0.05);
    Check(completions==1 && resultError.code==NSURLErrorCancelled && SlotAvailable() && MonitorsStopped(probe),@"An initial host selection exception safely cancels instead of escaping into UI");
    __block BOOL throwNow=NO; completions=0;
    probe=[BHRDStreamJob probeURL:url selectionStillCurrent:^BOOL { if (throwNow) [NSException raise:@"HostUnavailable" format:@"fixture"]; return YES; }
        completion:^(__unused MediaInformation *info, NSError *error) { completions++; resultError=error; }];
    engine=BHRDFixtureSessions.lastObject; throwNow=YES; [(NSTimer *)[probe valueForKey:@"selectionWatchdog"] fire];
    Check(completions==1 && engine.cancels==1 && SlotAvailable() && MonitorsStopped(probe),@"A later native resolver exception cancels the engine and releases the transfer slot");
    [engine deliverCompletion]; Pump(0.05);
    NSLog(@"PASS: %lu production stream-job lifecycle checks (native engine/UI fixture)",(unsigned long)Checks);
} return 0; }
