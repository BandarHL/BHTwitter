#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <string.h>
// Dictionary fixtures and signature-checked native getters share one adapter.
static inline id BHRDModelValue(id object, NSString *key) {
    if (!object || object == NSNull.null) return nil;
    if ([object isKindOfClass:NSDictionary.class]) { id v = object[key]; return v == NSNull.null ? nil : v; }
    SEL sel = NSSelectorFromString(key);
    if (![object respondsToSelector:sel]) return nil;
    NSMethodSignature *sig = [object methodSignatureForSelector:sel];
    if (sig.numberOfArguments != 2) return nil;
    char type = sig.methodReturnType[0];
    if (type == '@') return ((id (*)(id,SEL))objc_msgSend)(object,sel);
    if (type == 'B' || type == 'c') return @(((BOOL (*)(id,SEL))objc_msgSend)(object,sel));
    return nil;
}
static inline id BHRDUnwrapModel(id model) {
    Class cls = NSClassFromString(@"TFNDataViewItem");
    for (NSUInteger i=0; i<8 && cls && [model isKindOfClass:cls]; i++) {
        id child=BHRDModelValue(model,@"item"); if (!child || child==model) break; model=child;
    }
    return model;
}
