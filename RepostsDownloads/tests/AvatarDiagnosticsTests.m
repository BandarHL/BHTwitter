#import "../BHRDAvatarDiagnostics.h"
#import "../BHRDBuildInfo.h"
#import <UIKit/UIKit.h>
static NSUInteger checks;
static void Check(BOOL value,NSString *message) { checks++; if (!value) { NSLog(@"FAIL: %@",message); exit(1); } }
static void Wait(BOOL (^finished)(void)) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
    while (!finished() && deadline.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    Check(finished(),@"Asynchronous management callback completes on the UI run loop");
}
static NSArray *Records(NSString *path) {
    NSString *content=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    NSMutableArray *result=[NSMutableArray array];
    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
        id record=[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        if ([record isKindOfClass:NSDictionary.class]) [result addObject:record];
    }
    return result;
}
@interface AvatarUserProbe : NSObject
@property(nonatomic) NSUInteger getterReads;
@end
@implementation AvatarUserProbe
- (NSString *)profileImageURL { self.getterReads++; return @"https://pbs.twimg.com/profile_images/test.jpg"; }
@end
int main(void) { @autoreleasepool {
    BHRDAvatarDiagnosticFlush();
    NSString *path=BHRDAvatarDiagnosticPath();
    Check([NSFileManager.defaultManager fileExistsAtPath:path],@"Constructor writes a file without system logging");
    NSString *safe=BHRDAvatarDiagnosticURL([NSURL URLWithString:@"https://user:secret@pbs.twimg.com/profile_images/a.jpg?token=secret#fragment"]);
    Check([safe isEqual:@"https://pbs.twimg.com/profile_images/a.jpg"],@"URL credentials, query and fragment are omitted");
    dispatch_apply(32,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^(size_t i) {
        BHRDAvatarLog(@"parallel",@{@"index":@(i),@"url":safe});
    });
    BHRDAvatarDiagnosticFlush();
    NSString *content=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    NSUInteger count=0;
    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
        if (!line.length) continue;
        NSDictionary *row=[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        Check(row[@"event"] && [row[@"build"] isEqual:BHRD_BUILD_VERSION] && [row[@"revision"] isEqual:BHRD_BUILD_REVISION] && [row[@"commit"] isEqual:BHRD_BUILD_COMMIT],@"Concurrent events remain complete JSON lines with exact build identifiers");
        if ([row[@"event"] isEqual:@"parallel"]) count++;
    }
    Check(count==32,@"Serial writer preserves all events below queue limit");
    Check(![content containsString:@"secret"],@"Sanitized URL never writes credentials");
    NSNumber *permissions=[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL][NSFilePosixPermissions];
    Check((permissions.unsignedIntegerValue & 0777)==0600,@"Log is private to the app user");
    AvatarUserProbe *probe=[AvatarUserProbe new];
    NSUInteger before=Records(path).count;
    BHRDAvatarInspectModel(probe,@"detail-probe"); BHRDAvatarInspectView([UIImageView new],@"detail-probe"); BHRDAvatarDiagnosticFlush();
    Check(BHRDAvatarDetailedCollectionRemaining()==0 && probe.getterReads==0 && Records(path).count==before,@"Default basic collection never reflects model getters or native views");
    BHRDAvatarSetDetailedCollection(YES);
    Check(BHRDAvatarDetailedCollectionRemaining()>590 && BHRDAvatarDetailedCollectionRemaining()<=600,@"Explicit detailed collection is limited to ten minutes");
    BHRDAvatarInspectModel(probe,@"detail-probe"); BHRDAvatarInspectView([UIImageView new],@"detail-probe"); BHRDAvatarDiagnosticFlush();
    Check(probe.getterReads>0 && [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] containsString:@"model_shape"],@"Opt-in detailed inspection writes model shape and safely reads known getters");
    BHRDAvatarDiagnosticTestExpireDetailedCollection(); before=probe.getterReads;
    BHRDAvatarInspectModel(probe,@"expired-probe"); BHRDAvatarDiagnosticFlush();
    Check(BHRDAvatarDetailedCollectionRemaining()==0 && probe.getterReads==before,@"Expired collection stops reflection without requiring another UI action");
    BHRDAvatarSetDetailedCollection(NO); BHRDAvatarDiagnosticFlush();
    BHRDAvatarDiagnosticTestSuspendWriter(YES);
    for (NSUInteger i=0;i<200;i++) BHRDAvatarLog(@"overflow_probe",@{@"index":@(i)});
    BHRDAvatarDiagnosticTestSuspendWriter(NO); BHRDAvatarDiagnosticFlush();
    NSUInteger accepted=0; for (NSDictionary *row in Records(path)) if ([row[@"event"] isEqual:@"overflow_probe"]) accepted++;
    Check(accepted==128,@"Bounded writer accepts exactly its capacity while paused instead of unbounded memory growth");
    BHRDAvatarLog(@"oversized_probe",@{@"large":[@"x" stringByPaddingToLength:40000 withString:@"x" startingAtIndex:0]}); BHRDAvatarDiagnosticFlush();
    NSMutableData *large=[NSMutableData dataWithLength:2*1024*1024+1];
    [large writeToFile:path atomically:YES];
    BHRDAvatarLog(@"after_rotation",@{}); BHRDAvatarDiagnosticFlush();
    Check([NSFileManager.defaultManager fileExistsAtPath:[path stringByAppendingString:@".1"]],@"Oversized log rotates to one backup");
    Check([[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL] fileSize]<1024,@"New log starts small after rotation");
    BHRDAvatarLog(@"private_probe",@{@"row":@"private-row-123",@"post":@"private-post-456",@"authorID":@"private-user-789",@"handle":@"private_handle",@"url":@"https://pbs.twimg.com/profile_images/private_avatar.jpg",@"nested":@{@"postIdentifier":@"nested-private-post",@"displayName":@"Private Author",@"imageURL":@"private-image",@"valid":@YES},@"items":@[@{@"ownerHandle":@"nested-private-handle",@"http":@200}],@"source":@"https://pbs.twimg.com/private_path",@"loaded":@YES});
    BHRDAvatarDiagnosticFlush();
    __block NSString *viewed=nil;
    BHRDAvatarReadLog(^(NSString *text) { viewed=text; });
    Wait(^BOOL { return viewed!=nil; });
    Check([viewed containsString:@"after_rotation"],@"Viewer reads current log asynchronously");
    Check([viewed containsString:@"丢弃 72 条"] && [viewed containsString:@"写入失败 1 次"] && [viewed containsString:@"avatar-diag.log.1"] && [viewed containsString:BHRD_BUILD_REVISION],@"Viewer displays drop and failure counts, both files and exact build revision");
    __block NSArray<NSURL *> *exported=nil; __block NSError *exportError=nil;
    BHRDAvatarExportLogs(^(NSArray<NSURL *> *files,NSError *error) { exported=files; exportError=error; });
    Wait(^BOOL { return exported!=nil; });
    Check(exported.count==3 && !exportError,@"Export snapshots current, previous and diagnostic summary files");
    NSArray *redacted=Records(exported.firstObject.path); NSDictionary *private=nil;
    for (NSDictionary *row in redacted) if ([row[@"event"] isEqual:@"private_probe"]) private=row;
    Check(private && !private[@"row"] && !private[@"post"] && !private[@"authorID"] && !private[@"handle"] && !private[@"url"],@"Export removes browsing identifiers and avatar addresses");
    Check([private[@"nested"] isEqual:@{@"valid":@YES}] && [private[@"items"] isEqual:@[@{@"http":@200}]] && [private[@"loaded"] boolValue],@"Redaction is recursive and preserves diagnostic outcomes");
    NSString *exportText=[NSString stringWithContentsOfURL:exported.firstObject encoding:NSUTF8StringEncoding error:NULL];
    Check(![exportText containsString:@"private-"] && ![exportText containsString:@"private_handle"] && ![exportText containsString:@"private_avatar"] && ![exportText containsString:@"https://"],@"Neither nested identifiers nor URL strings under unknown keys survive export");
    NSDictionary *summary=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:exported.lastObject] options:0 error:NULL];
    Check([summary[@"droppedRecords"] unsignedIntegerValue]==72 && [summary[@"writeFailures"] unsignedIntegerValue]==1 && [summary[@"redacted"] boolValue] && [summary[@"retentionDays"] isEqual:@7],@"Export summary makes discarded records, write failures and retention explicit");
    Check([[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] containsString:@"private_handle"],@"Redacted export does not silently destroy local diagnostic data");
    NSURL *directory=exported.firstObject.URLByDeletingLastPathComponent;
    BHRDAvatarRemoveExport(exported); BHRDAvatarDiagnosticFlush();
    Check(![NSFileManager.defaultManager fileExistsAtPath:directory.path],@"Share completion cleans only the export snapshot");
    Check([NSFileManager.defaultManager fileExistsAtPath:path],@"Export cleanup preserves the original log");
    NSString *previous=[path stringByAppendingString:@".1"];
    [NSFileManager.defaultManager setAttributes:@{NSFileModificationDate:[NSDate dateWithTimeIntervalSinceNow:-8*24*60*60]} ofItemAtPath:previous error:NULL];
    NSMutableDictionary *expired=[@{@"event":@"expired_record",@"time":@([NSDate.date timeIntervalSince1970]-8*24*60*60)} mutableCopy];
    NSData *oldJSON=[NSJSONSerialization dataWithJSONObject:expired options:0 error:NULL];
    NSFileHandle *append=[NSFileHandle fileHandleForWritingAtPath:path]; [append seekToEndOfFile]; [append writeData:oldJSON]; [append writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]]; [append closeFile];
    viewed=nil; BHRDAvatarReadLog(^(NSString *text) { viewed=text; }); Wait(^BOOL { return viewed!=nil; });
    Check(![NSFileManager.defaultManager fileExistsAtPath:previous],@"Expired previous file is removed after seven days");
    Check(![[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] containsString:@"expired_record"] && [viewed containsString:@"private_probe"],@"Age pruning removes expired records inside active files while retaining recent data");
    __block BOOL cleared=NO; __block NSError *clearError=nil;
    BHRDAvatarSetDetailedCollection(YES);
    BHRDAvatarClearLogs(^(NSError *error) { clearError=error; cleared=YES; }); Wait(^BOOL { return cleared; });
    Check(!clearError && BHRDAvatarDetailedCollectionRemaining()==0 && Records(path).count==1 && ![NSFileManager.defaultManager fileExistsAtPath:previous],@"Clear serializes with writes, removes both files, resets counters and stops detailed collection");
    Check([Records(path).firstObject[@"event"] isEqual:@"logs_cleared"],@"Clear leaves only a non-identifying audit event");
    viewed=nil; BHRDAvatarReadLog(^(NSString *text) { viewed=text; }); Wait(^BOOL { return viewed!=nil; });
    Check([viewed containsString:@"丢弃 0 条"] && [viewed containsString:@"写入失败 0 次"] && ![viewed containsString:@"private_handle"],@"Clear removes prior browsing identifiers and resets displayed statistics");
    NSLog(@"PASS: %lu avatar diagnostic file checks",(unsigned long)checks);
} return 0; }
