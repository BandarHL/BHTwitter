#import <UIKit/UIKit.h>
NSString * const UIPasteboardOptionLocalOnly=@"localOnly";
NSString * const UIPasteboardOptionExpirationDate=@"expirationDate";
@implementation UIPasteboard
+ (instancetype)generalPasteboard { static UIPasteboard *board; static dispatch_once_t once; dispatch_once(&once,^{ board=[self new]; }); return board; }
- (void)setItems:(NSArray *)items options:(NSDictionary *)options {
    if ([self.fixtureFailure isEqual:@"throw_write"]) [NSException raise:@"Fixture" format:@"write rejected"];
    if ([self.fixtureFailure isEqual:@"reject"]) return;
    self.changeCount++; self.fixtureItems=[self.fixtureFailure isEqual:@"clear"] ? @[] : items; self.fixtureOptions=options;
}
- (BOOL)containsPasteboardTypes:(NSArray *)types {
    for (NSDictionary *item in self.fixtureItems) for (NSString *type in types) if (item[type]) return YES;
    return NO;
}
- (BOOL)hasImages { return ![self.fixtureFailure isEqual:@"no_image"] && [self containsPasteboardTypes:@[@"public.png",@"public.jpeg",@"com.compuserve.gif"]]; }
- (NSString *)string { return self.fixtureItems.firstObject[@"public.utf8-plain-text"]; }
- (NSData *)dataForPasteboardType:(NSString *)type {
    if ([self.fixtureFailure isEqual:@"throw_read"]) [NSException raise:@"Fixture" format:@"read rejected"];
    if ([self.fixtureFailure isEqual:@"replace"]) return [@"other image" dataUsingEncoding:NSUTF8StringEncoding];
    if ([self.fixtureFailure isEqual:@"race"]) self.changeCount++;
    return self.fixtureItems.firstObject[type];
}
@end
