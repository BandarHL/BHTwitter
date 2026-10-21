#import <Foundation/Foundation.h>
NSArray<NSString *> *BHRDStreamArguments(NSURL *url, NSNumber *index, NSURL *output);
NSArray<NSString *> *BHRDStreamProbeArguments(NSURL *url);
// Only a fixed error category is retained; never return FFmpeg raw URLs/text.
NSString *BHRDStreamDiagnosticCategory(NSString *message);
