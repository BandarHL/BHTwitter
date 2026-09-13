#import "BHRDConversationScope.h"
#import <objc/runtime.h>
#import <objc/message.h>

static id Read(id object, NSString *key) {
    // These are public object getters on the host. Missing properties are
    // normal on cells/models; KVC would throw on every layout probe.
    SEL selector = NSSelectorFromString(key);
    if (![object respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}
static char DetailClassKey;
static BOOL DetailClass(id object) {
    Class actualClass = [object class];
    NSNumber *cached = objc_getAssociatedObject(actualClass, &DetailClassKey);
    if (cached) return cached.boolValue;
    for (Class cls = [object class]; cls; cls = class_getSuperclass(cls)) {
        NSString *name = NSStringFromClass(cls);
        if ([name containsString:@"TweetDetails"] ||
            [name containsString:@"TweetDetail"] ||
            [name containsString:@"ConversationFocalStatus"] ||
            [name containsString:@"ConversationViewController"] ||
            [name containsString:@"ConversationContainerView"] ||
            [name containsString:@"ConversationTimeline"]) {
            objc_setAssociatedObject(actualClass, &DetailClassKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return YES;
        }
    }
    objc_setAssociatedObject(actualClass, &DetailClassKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return NO;
}
BOOL BHRDIsConversationContext(id object) {
    if (!object || object == NSNull.null) return NO;
    NSMutableArray *pending = [NSMutableArray arrayWithObject:object];
    NSHashTable *seen = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (NSUInteger index = 0; index < pending.count && index < 64; index++) {
        id current = pending[index];
        if ([seen containsObject:current]) continue;
        [seen addObject:current];
        if (DetailClass(current)) return YES;
        id location = Read(current, @"adDisplayLocation");
        if ([@[@"TWEET_DETAILS", @"TWEET_DETAIL", @"CONVERSATION"] containsObject:location ?: NSNull.null]) return YES;
        // Do not walk a navigation stack or presenting controller: an inactive
        // detail page must not disable filtering on the active home timeline.
        for (NSString *key in @[@"parentViewController", @"nextResponder"]) {
            id next = Read(current, key);
            if (next && next != NSNull.null && ![seen containsObject:next]) [pending addObject:next];
        }
    }
    return NO;
}
