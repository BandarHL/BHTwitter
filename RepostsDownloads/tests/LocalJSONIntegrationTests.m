#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../BHRDLocalJSON.h"
#import "../BHRDAvatarDiagnostics.h"
#import "../BHRDAcceptance.h"
#import "../BHRDAdFilter.h"

static NSUInteger HostReads, LocalReads, Checks;
static id (*Original)(id,SEL,NSData *,NSJSONReadingOptions,NSError **);
static void Check(BOOL value, NSString *message) {
    Checks++; if (!value) { NSLog(@"FAIL: %@", message); exit(1); }
}
// Exercise production persistence and export with the host-wide parser hook
// installed, the combination that isolated logger tests previously omitted.
static id Hook(id cls, SEL selector, NSData *data, NSJSONReadingOptions options, NSError **error) {
    id object=Original(cls,selector,data,options,error);
    if (BHRDReadingLocalJSON()) { LocalReads++; return object; }
    HostReads++;
    return BHRDFilterAdResponse(object,data,YES,NULL);
}
int main(void) { @autoreleasepool {
    Method method=class_getClassMethod(NSJSONSerialization.class,@selector(JSONObjectWithData:options:error:));
    Original=(void *)method_setImplementation(method,(IMP)Hook);
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"entries":@[]} options:0 error:NULL];
    Check([BHRDReadLocalJSON(data,0,NULL) isKindOfClass:NSDictionary.class],@"Local parsing returns normal Foundation data");
    Check(LocalReads==1 && HostReads==0 && !BHRDReadingLocalJSON(),@"Local scope skips host filtering and is restored");
    NSThread.currentThread.threadDictionary[@"com.caun.xsuixin.local-json"]=@YES;
    BHRDReadLocalJSON(data,0,NULL);
    Check(BHRDReadingLocalJSON(),@"Nested local parsing preserves the outer scope");
    [NSThread.currentThread.threadDictionary removeObjectForKey:@"com.caun.xsuixin.local-json"];
    BHRDReadLocalJSON([@"invalid" dataUsingEncoding:NSUTF8StringEncoding],0,NULL);
    Check(!BHRDReadingLocalJSON(),@"Invalid JSON restores the parsing scope");
    @try { BHRDReadLocalJSON(nil,0,NULL); } @catch (__unused NSException *exception) {}
    Check(!BHRDReadingLocalJSON(),@"Exceptions restore the parsing scope");
    [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    Check(HostReads==1,@"Actual host JSON still enters advertisement filtering");
    for (NSUInteger i=0;i<50;i++) Check(BHRDAcceptanceSnapshot()!=nil,@"Acceptance snapshots work under the host hook");
    BHRDAcceptanceBeginSession(); BHRDAcceptanceFlush(); BHRDAvatarDiagnosticFlush();
    NSUInteger before=HostReads;
    __block NSArray *files; __block NSError *failure; __block BOOL finished=NO;
    BHRDAvatarExportLogs(^(NSArray *result,NSError *error) { files=result; failure=error; finished=YES; });
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    while (!finished && deadline.timeIntervalSinceNow>0)
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    BHRDAvatarDiagnosticFlush();
    Check(finished && !failure && files.count>=2,@"Production log export completes with the JSON hook active");
    Check(HostReads==before && LocalReads>50,@"Snapshot, retention and export do not log their own JSON as host responses");
    NSDictionary *summary=BHRDReadLocalJSON([NSData dataWithContentsOfURL:files.lastObject],0,NULL);
    Check([summary[@"droppedRecords"] unsignedIntegerValue]==0 && [summary[@"pendingRecords"] unsignedIntegerValue]==0,@"Export creates no recursive backlog or dropped records");
    BHRDAvatarRemoveExport(files); BHRDAvatarDiagnosticFlush();
    method_setImplementation(method,(IMP)Original);
    NSLog(@"PASS: %lu local JSON integration checks",(unsigned long)Checks);
} return 0; }
