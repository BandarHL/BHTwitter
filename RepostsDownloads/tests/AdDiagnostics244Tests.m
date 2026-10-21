#import <Foundation/Foundation.h>
#import "../BHRDAdFilter.h"
#import "../BHRDAvatarDiagnostics.h"
int main(void) { @autoreleasepool {
    NSDictionary *clean=@{@"entries":@[]};
    NSData *data=[NSJSONSerialization dataWithJSONObject:clean options:0 error:NULL];
    BOOL changed=YES;
    if (BHRDFilterAdResponse(clean,data,YES,&changed)!=clean || changed) return 1;
    NSDictionary *ad=@{@"entries":@[@{@"entryId":@"promoted-tweet-42",@"content":@{@"entryType":@"TimelineTimelineItem"}}]};
    data=[NSJSONSerialization dataWithJSONObject:ad options:0 error:NULL];
    id filtered=BHRDFilterAdResponse(ad,data,YES,&changed);
    if (!changed || [filtered[@"entries"] count]!=0 || [ad[@"entries"] count]!=1) return 1;
    if (BHRDFilterAdResponse(ad,data,NO,&changed)!=ad || changed) return 1;
    BHRDAvatarDiagnosticFlush();
    NSLog(@"PASS: 3 rollback ad logging/behavior checks");
} return 0; }
