#import "BHRDRuntimeStatus.h"
#import <objc/runtime.h>
static NSMutableDictionary *Capabilities(void) {
    static NSMutableDictionary *values; static dispatch_once_t once;
    dispatch_once(&once,^{ values=[NSMutableDictionary dictionary]; }); return values;
}
void BHRDRecordCapability(NSString *feature,NSString *status,NSString *detail) {
    if (!feature.length) return;
    @synchronized(Capabilities()) { Capabilities()[feature]=@{@"feature":feature,@"status":status ?: @"未验证",@"detail":detail ?: @""}; }
}
NSArray<NSDictionary *> *BHRDRuntimeCapabilities(void) {
    @synchronized(Capabilities()) { return [[Capabilities().allValues sortedArrayUsingComparator:^NSComparisonResult(id a,id b) { return [a[@"feature"] compare:b[@"feature"]]; }] copy]; }
}
BOOL BHRDHookSignatureMatches(NSString *className,NSString *selectorName,char returnType,NSUInteger arguments) {
    Class cls=NSClassFromString(className); Method method=class_getInstanceMethod(cls,NSSelectorFromString(selectorName));
    if (!method) { BHRDRecordCapability(className,@"不可用",[@"缺少 " stringByAppendingString:selectorName]); return NO; }
    NSMethodSignature *sig=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)]; char actual=sig.methodReturnType[0];
    BOOL compatible=sig.numberOfArguments==arguments && (actual==returnType || (returnType=='B' && actual=='c'));
    if (!compatible) BHRDRecordCapability(className,@"不可用",[@"方法签名不匹配：" stringByAppendingString:selectorName]);
    return compatible;
}
