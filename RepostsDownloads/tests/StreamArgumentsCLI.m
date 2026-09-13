#import <Foundation/Foundation.h>
#import "../BHRDStreamArguments.h"
int main(int argc, const char *argv[]) { @autoreleasepool {
    if (argc != 4) return 2;
    NSArray *args=BHRDStreamArguments([NSURL URLWithString:@(argv[1])], @([@(argv[2]) integerValue]), [NSURL fileURLWithPath:@(argv[3])]);
    NSData *json=[NSJSONSerialization dataWithJSONObject:args options:0 error:nil];
    [NSFileHandle.fileHandleWithStandardOutput writeData:json];
} return 0; }
