#import "RuntimeExplore.h"

@implementation RuntimeExplore
+ (id)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely {
    NSScanner *scanner = [NSScanner scannerWithString:addressString];
    unsigned long long hexValue = 0;
    BOOL didParseAddress = [scanner scanHexLongLong:&hexValue];
    const void *pointerValue = (void *)hexValue;

    NSString *error = nil;

    if (didParseAddress) {
        if (safely && ![FLEXRuntimeUtility pointerIsValidObjcObject:pointerValue]) {
            error = @"The given address is unlikely to be a valid object.";
        }
    } else {
        error = @"Malformed address. Make sure it's not too long and starts with '0x'.";
    }

    if (!error) {
        id object = (__bridge id)pointerValue;
        return object;
    } else {
        return nil;
    }
}
+ (NSString *)getAddressFromDescription:(NSString *)description {
    NSMutableArray <NSString *> *split = [[NSMutableArray alloc] initWithArray:[description componentsSeparatedByString:@":"]];
    NSString *address = split.lastObject;
    return [[address stringByReplacingOccurrencesOfString:@">" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];
}
@end
