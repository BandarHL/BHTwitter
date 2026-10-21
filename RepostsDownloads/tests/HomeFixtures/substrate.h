#import <objc/runtime.h>
static inline void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getInstanceMethod(cls, selector);
    *original = method_getImplementation(method);
    if (!class_addMethod(cls, selector, replacement, method_getTypeEncoding(method))) method_setImplementation(method, replacement);
}
