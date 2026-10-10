#import <Foundation/Foundation.h>
void BHRDRecordCapability(NSString *feature,NSString *status,NSString *detail);
NSArray<NSDictionary *> *BHRDRuntimeCapabilities(void);
BOOL BHRDHookSignatureMatches(NSString *className,NSString *selectorName,char returnType,NSUInteger arguments);
