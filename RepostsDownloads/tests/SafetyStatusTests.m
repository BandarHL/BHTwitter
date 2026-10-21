#import <Foundation/Foundation.h>
#import "../BHRDSafety.h"
#import "../BHRDPreferences.h"
#import "../BHRDRuntimeStatus.h"
@interface StatusProbe : NSObject
- (BOOL)flag;
- (id)object;
@end
@implementation StatusProbe
- (BOOL)flag { return YES; }
- (id)object { return @YES; }
@end
static NSUInteger checks;
static void Check(BOOL ok,NSString *message) { checks++; if (!ok) { NSLog(@"FAIL: %@",message); exit(1); } }
int main(int argc,const char **argv) { @autoreleasepool {
    BOOL cold=argc>1 && strcmp(argv[1],"cold")==0;
    Check(BHRDFeatureHooksEnabledAtLaunch()==!cold,@"Boot flag determines hook installation before features start");
    Check(BHRDIsPaused()==cold,@"Pause flag is visible"); NSError *error=nil;
    Check(BHRDSetPaused(YES,&error) && !error && !BHRDTweakEnabled(),@"Pause persists and disables feature gates");
    Check([NSFileManager.defaultManager fileExistsAtPath:BHRDSafetyFlagPath()],@"Offline recovery marker exists");
    Check(!BHRDPreference(BHRDHideRepostsKey) && !BHRDPreference(BHRDDownloadKey),@"Paused hooks do not transform or start downloads");
    Check(BHRDPreference(BHRDCopyLocalOnlyKey),@"Privacy policy remains readable while paused");
    Check(BHRDSetPaused(NO,&error) && !BHRDIsPaused(),@"Resume removes pause marker");
    Check(BHRDTweakEnabled()==!cold,@"Safe boot cannot claim unloaded feature hooks resumed without restart");
    Check(BHRDHookSignatureMatches(@"StatusProbe",@"flag",'B',2),@"Exact bool hook signature accepted");
    Check(!BHRDHookSignatureMatches(@"StatusProbe",@"object",'B',2),@"Object/bool ABI mismatch rejected");
    Check(!BHRDHookSignatureMatches(@"MissingXClass",@"flag",'B',2),@"Missing X runtime class reported");
    BHRDRecordCapability(@"navigation",@"observed",@"native selection");
    Check(BHRDRuntimeCapabilities().count>=3,@"Status snapshot contains failure and observation records");
    NSLog(@"PASS: %lu safety/capability checks (%@ boot)",(unsigned long)checks,cold ? @"safe" : @"normal");
} return 0; }
