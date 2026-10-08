#import "BHRDSafety.h"
#import "BHRDAvatarDiagnostics.h"
#import "BHRDAcceptance.h"
#import <stdatomic.h>
static atomic_bool Paused;
static BOOL LaunchEnabled;
NSString *BHRDSafetyFlagPath(void) {
#if BHRD_SAFETY_TEST
    NSString *base=NSProcessInfo.processInfo.environment[@"BHRD_SAFETY_TEST_DIR"];
#else
    NSString *base=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/XSuixinSafety"];
#endif
    return [base stringByAppendingPathComponent:@"disabled"];
}
static void Initialize(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{
        BOOL paused=[NSFileManager.defaultManager fileExistsAtPath:BHRDSafetyFlagPath()];
        atomic_store(&Paused,paused); LaunchEnabled=!paused;
    });
}
BOOL BHRDIsPaused(void) { Initialize(); return atomic_load(&Paused); }
BOOL BHRDFeatureHooksEnabledAtLaunch(void) { Initialize(); return LaunchEnabled; }
BOOL BHRDTweakEnabled(void) { Initialize(); return LaunchEnabled && !atomic_load(&Paused); }
static BOOL ReportChange(BOOL paused,BOOL success,NSError *error) {
#if BHRD_AVATAR_DIAGNOSTICS
    BHRDAvatarLog(@"safety_pause_changed",@{@"paused":@(paused),@"success":@(success),@"hooksEnabledAtLaunch":@(LaunchEnabled),
        @"acceptanceSession":BHRDAcceptanceCurrentSessionIdentifier(),@"errorDomain":error.domain ?: @"",@"errorCode":@(error.code)});
#else
    (void)paused; (void)error;
#endif
    return success;
}
BOOL BHRDSetPaused(BOOL paused,NSError **error) {
    Initialize(); NSFileManager *fm=NSFileManager.defaultManager; NSString *path=BHRDSafetyFlagPath();
    NSError *failure=nil;
    if (paused) {
        if (![fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&failure]) {
            if (error) *error=failure; return ReportChange(paused,NO,failure);
        }
        if (![fm createFileAtPath:path contents:[@"X Suixin paused\n" dataUsingEncoding:NSUTF8StringEncoding] attributes:@{NSFilePosixPermissions:@0600}]) {
            failure=[NSError errorWithDomain:@"XSuixinSafety" code:1 userInfo:@{NSLocalizedDescriptionKey:@"无法保存暂停状态，请检查存储空间"}];
            if (error) *error=failure; return ReportChange(paused,NO,failure);
        }
    } else if ([fm fileExistsAtPath:path] && ![fm removeItemAtPath:path error:&failure]) {
        if (error) *error=failure; return ReportChange(paused,NO,failure);
    }
    atomic_store(&Paused,paused); return ReportChange(paused,YES,nil);
}
