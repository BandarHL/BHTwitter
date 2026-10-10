#import <UIKit/UIKit.h>
NSString * const UIPasteboardOptionLocalOnly=@"localOnly";
NSString * const UIPasteboardOptionExpirationDate=@"expirationDate";
@implementation UIPasteboard
+ (instancetype)generalPasteboard { static UIPasteboard *board; static dispatch_once_t once; dispatch_once(&once,^{ board=[self new]; }); return board; }
- (void)setItems:(NSArray *)items options:(NSDictionary *)options { self.fixtureItems=items; self.fixtureOptions=options; }
@end
