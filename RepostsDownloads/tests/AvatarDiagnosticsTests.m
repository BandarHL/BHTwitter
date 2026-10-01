#import "../BHRDAvatarDiagnostics.h"
static NSUInteger checks;
static void Check(BOOL value,NSString *message) { checks++; if (!value) { NSLog(@"FAIL: %@",message); exit(1); } }
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
        Check(row[@"event"] && [row[@"build"] isEqual:@"2.4.4"],@"Concurrent events remain complete JSON lines with build identifiers");
        if ([row[@"event"] isEqual:@"parallel"]) count++;
    }
    Check(count==32,@"Serial writer preserves all events below queue limit");
    Check(![content containsString:@"secret"],@"Sanitized URL never writes credentials");
    NSNumber *permissions=[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL][NSFilePosixPermissions];
    Check((permissions.unsignedIntegerValue & 0777)==0600,@"Log is private to the app user");
    NSMutableData *large=[NSMutableData dataWithLength:2*1024*1024+1];
    [large writeToFile:path atomically:YES];
    BHRDAvatarLog(@"after_rotation",@{}); BHRDAvatarDiagnosticFlush();
    Check([NSFileManager.defaultManager fileExistsAtPath:[path stringByAppendingString:@".1"]],@"Oversized log rotates to one backup");
    Check([[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL] fileSize]<1024,@"New log starts small after rotation");
    __block NSString *viewed=nil;
    BHRDAvatarReadLog(^(NSString *text) { viewed=text; });
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
    while (!viewed && deadline.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    Check([viewed containsString:@"after_rotation"],@"Viewer reads current log asynchronously");
    __block NSArray<NSURL *> *exported=nil; __block NSError *exportError=nil;
    BHRDAvatarExportLogs(^(NSArray<NSURL *> *files,NSError *error) { exported=files; exportError=error; });
    deadline=[NSDate dateWithTimeIntervalSinceNow:3];
    while (!exported && deadline.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    Check(exported.count==2 && !exportError,@"Export snapshots current and rotated files");
    Check([[NSData dataWithContentsOfURL:exported.firstObject] isEqual:[NSData dataWithContentsOfFile:path]],@"Exported current log matches a consistent snapshot");
    NSURL *directory=exported.firstObject.URLByDeletingLastPathComponent;
    BHRDAvatarRemoveExport(exported); BHRDAvatarDiagnosticFlush();
    Check(![NSFileManager.defaultManager fileExistsAtPath:directory.path],@"Share completion cleans only the export snapshot");
    Check([NSFileManager.defaultManager fileExistsAtPath:path],@"Export cleanup preserves the original log");
    NSLog(@"PASS: %lu avatar diagnostic file checks",(unsigned long)checks);
} return 0; }
