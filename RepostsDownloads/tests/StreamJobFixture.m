#import "StreamJobFixture.h"
#import "../BHRDDownloadStore.h"

NSMutableArray<BHRDFixtureSession *> *BHRDFixtureSessions;
NSMutableArray<JGProgressHUD *> *BHRDFixtureHUDs;
NSMutableArray<NSDictionary *> *BHRDFixtureEvents;
void (^BHRDFixtureBeforeBinding)(void);
NSUInteger BHRDFixtureAlerts;

@implementation JGProgressHUD
@end
JGProgressHUD *BHRDShowDownloadProgress(__unused NSString *title, void (^cancel)(void)) {
    JGProgressHUD *hud=[JGProgressHUD new]; hud.visible=YES; hud.cancel=cancel;
    [BHRDFixtureHUDs addObject:hud]; return hud;
}
void BHRDUpdateDownloadProgress(__unused JGProgressHUD *hud, __unused NSString *detail) {}
void BHRDDismissDownloadProgress(JGProgressHUD *hud) { hud.visible=NO; hud.cancel=nil; }
void BHRDShowError(__unused NSString *message) { BHRDFixtureAlerts++; }
@implementation BHRDManager
+ (BOOL)DirectSave { return NO; }
+ (void)save:(__unused NSURL *)url {}
+ (void)showSaveVC:(__unused NSURL *)url {}
@end
NSString *BHRDAcceptanceCurrentSessionIdentifier(void) { return @"fixture-session"; }
void BHRDAvatarLog(NSString *event, NSDictionary *fields) { [BHRDFixtureEvents addObject:@{@"event":event,@"fields":fields}]; }
NSURL *BHRDNewDownloadURL(__unused BOOL partial) { return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]]; }
NSURL *BHRDCompleteDownload(NSURL *partial) { return partial; }
void BHRDDiscardDownload(__unused NSURL *url) {}

@implementation ReturnCode { int _value; }
- (instancetype)init:(int)value { if ((self=[super init])) _value=value; return self; }
+ (BOOL)isSuccess:(ReturnCode *)code { return code && code.getValue==0; }
+ (BOOL)isCancel:(ReturnCode *)code { return code && code.getValue==255; }
- (int)getValue { return _value; }
- (BOOL)isValueSuccess { return _value==0; }
- (BOOL)isValueError { return _value!=0 && _value!=255; }
- (BOOL)isValueCancel { return _value==255; }
@end
@interface BHRDFixtureStream : NSObject
@end
@implementation BHRDFixtureStream
- (NSString *)getType { return @"video"; }
- (NSNumber *)getIndex { return @0; }
- (NSNumber *)getWidth { return @1280; }
- (NSNumber *)getHeight { return @720; }
@end
@interface BHRDFixtureInformation : NSObject
@end
@implementation BHRDFixtureInformation
- (NSArray *)getStreams { return @[[BHRDFixtureStream new]]; }
@end
@implementation BHRDFixtureSession
- (long)getSessionId { return self.identifier; }
- (SessionState)getState { return self.state; }
- (long)getDuration { return 0; }
- (NSDate *)getStartTime { return [NSDate date]; }
- (ReturnCode *)getReturnCode { return [[ReturnCode alloc] init:0]; }
- (MediaInformation *)getMediaInformation { return (id)[BHRDFixtureInformation new]; }
- (void)deliverCompletion {
    void (^callback)(id)=self.completion; self.completion=nil; self.state=SessionStateCompleted;
    if (callback) callback(self);
}
@end

// FFmpegKit has many overloads; this fixture implements exactly the production
// entry points used by StreamJob, with the real headers checking their types.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation FFprobeKit
+ (MediaInformationSession *)getMediaInformationFromCommandArgumentsAsync:(__unused NSArray *)arguments
    withCompleteCallback:(MediaInformationSessionCompleteCallback)completion withLogCallback:(__unused LogCallback)log
    onDispatchQueue:(__unused dispatch_queue_t)queue withTimeout:(__unused int)timeout {
    BHRDFixtureSession *session=[BHRDFixtureSession new]; session.identifier=BHRDFixtureSessions.count+1;
    session.state=SessionStateRunning; session.completion=(id)completion; [BHRDFixtureSessions addObject:session];
    if (BHRDFixtureBeforeBinding) { void (^before)(void)=BHRDFixtureBeforeBinding; BHRDFixtureBeforeBinding=nil; before(); }
    return (id)session;
}
@end
@implementation FFmpegKit
+ (FFmpegSession *)executeWithArgumentsAsync:(__unused NSArray *)arguments
    withCompleteCallback:(FFmpegSessionCompleteCallback)completion withLogCallback:(__unused LogCallback)log
    withStatisticsCallback:(__unused StatisticsCallback)statistics {
    BHRDFixtureSession *session=[BHRDFixtureSession new]; session.identifier=BHRDFixtureSessions.count+1;
    session.state=SessionStateRunning; session.completion=(id)completion; [BHRDFixtureSessions addObject:session]; return (id)session;
}
+ (void)cancel:(long)identifier {
    for (BHRDFixtureSession *session in BHRDFixtureSessions) if (session.identifier==identifier) session.cancels++;
}
@end
#pragma clang diagnostic pop
