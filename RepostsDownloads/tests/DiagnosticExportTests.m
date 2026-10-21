#import <Foundation/Foundation.h>
#import "../BHRDDiagnosticExport.h"
static NSUInteger checks;
static void Check(BOOL ok,NSString *message) { checks++; if(!ok) { NSLog(@"FAIL %@",message); exit(1); } }
int main(void) { @autoreleasepool {
    for (NSString *alias in @[@"user_id",@"statusID",@"tweet_id",@"id_str",@"account",@"unknown",@"nested"]) {
        NSDictionary *record=@{@"event":@"fullscreen_video_resolution",alias:@"private-identity",@"candidateResults":@[@{alias:@[@"private-identity"],@"reason":@"unsupported_current_asset",@"sourceClass":@"TAVPlayer"}],@"reason":@"unsupported_current_asset"};
        NSDictionary *safe=BHRDExportDiagnosticRecord(record);
        Check(![[safe description] containsString:@"private"],@"Unknown identity aliases disappear at every nesting level");
        Check([safe[@"reason"] isEqual:@"unsupported_current_asset"],@"Known failure enum remains useful");
    }
    NSDictionary *safe=BHRDExportDiagnosticRecord(@{@"event":@"photo_save_result",@"errorDomain":@"private-account-domain",@"errorCode":@7,@"reason":@"secret free text",@"width":@1080});
    Check([safe[@"errorDomain"] isEqual:@"redacted"] && [safe[@"reason"] isEqual:@"other"] && [safe[@"width"] isEqual:@1080],@"Unknown error domains and free text cannot cross the export boundary");
    safe=BHRDExportDiagnosticRecord(@{@"event":@"someone-private-event",@"reason":@"accepted",@"build":@"private",@"time":@1});
    Check([safe[@"event"] isEqual:@"unrecognized_event"] && !safe[@"reason"] && !safe[@"build"],@"Unknown event names and invalid build identity are not exported verbatim");
    safe=BHRDExportDiagnosticRecord(@{@"event":@"fullscreen_video_resolution",@"resourceDecisionCounts":@{@"unsupported_scheme":@2,@"private-token":@3},@"resourceProbePaths":@[@"source.currentItem.asset (AVURLAsset)",@"source.private_account.secret"]});
    Check([safe[@"resourceDecisionCounts"] isEqual:@{@"unsupported_scheme":@2}],@"Decision maps accept only fixed rejection categories");
    Check([safe[@"resourceProbePaths"] isEqual:@[@"source.currentItem.asset (AVURLAsset)"]],@"Known read paths survive; unknown free-form components do not");
    safe=BHRDExportDiagnosticRecord(@{@"event":@"ad_response_seen",@"reason":@"accepted",@"marker":@NO,@"bytes":@400});
    Check(!safe[@"reason"] && [safe[@"bytes"] isEqual:@400],@"Each event family has its own permitted fields");
    NSLog(@"PASS: %lu closed diagnostic export checks",(unsigned long)checks);
} return 0; }
