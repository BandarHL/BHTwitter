#import <UIKit/UIKit.h>

// Extra coordinate APIs needed by the production inline layout on the host.
enum { UIUserInterfaceLayoutDirectionRightToLeft = 1 };
@interface UIView (InlineActionsFixture)
- (BOOL)isDescendantOfView:(UIView *)view;
@property(nonatomic, readonly) NSInteger effectiveUserInterfaceLayoutDirection;
@end
