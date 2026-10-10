#import "../../HostFixtures/UIKit/UIKit.h"

// Add only the home-header APIs required by the production implementation.
// This fixture exercises view identity/geometry, not UIKit drawing or Swift.
@compatibility_alias UIResponder NSObject;
typedef struct { CGFloat top, left, bottom, right; } UIEdgeInsets;
@interface NSObject (HomeResponderFixture)
@property(nonatomic, readonly) UIResponder *nextResponder;
@end
@interface UIView (HomeFixture)
@property(nonatomic, readonly) UIResponder *nextResponder;
- (void)setFixtureNextResponder:(UIResponder *)responder;
- (BOOL)isDescendantOfView:(UIView *)view;
@end
@interface UIButton (HomeFixture)
@property(nonatomic, readonly) NSString *currentTitle;
@end
@interface UIWindow : UIView
@property(nonatomic) UIEdgeInsets safeAreaInsets;
@end
@interface UICollectionViewCell : UIView @end
@interface UIScrollView : UIView
@property(nonatomic) CGSize contentSize;
@property(nonatomic) CGPoint contentOffset;
@property(nonatomic) BOOL bounces;
- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated;
@end
@interface UIViewController : NSObject
@property(nonatomic, strong) UIView *view;
@property(nonatomic, strong) NSArray<UIViewController *> *childViewControllers;
@property(nonatomic, weak) UIResponder *nextResponder;
@end
@interface NSValue (HomeGeometry)
+ (instancetype)valueWithCGRect:(CGRect)rect;
+ (instancetype)valueWithCGSize:(CGSize)size;
- (CGRect)CGRectValue;
- (CGSize)CGSizeValue;
@end
