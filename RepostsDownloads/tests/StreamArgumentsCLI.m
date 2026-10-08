#import <Foundation/Foundation.h>
#import "../BHRDStreamArguments.h"
int main(int argc, const char *argv[]) { @autoreleasepool {
    if (argc != 4 && !(argc==3 && [@(argv[1]) isEqual:@"--probe"])) return 2;
    NSArray *args=argc==3 ? BHRDStreamProbeArguments([NSURL URLWithString:@(argv[2])]) : BHRDStreamArguments([NSURL URLWithString:@(argv[1])], @([@(argv[2]) integerValue]), [NSURL fileURLWithPath:@(argv[3])]);
    NSData *json=[NSJSONSerialization dataWithJSONObject:args options:0 error:nil];
    [NSFileHandle.fileHandleWithStandardOutput writeData:json];
} return 0; }
