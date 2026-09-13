// Minimal view graph for exercising production author enrichment on macOS.
// It models coordinates/identity only; it does not emulate iOS rendering or hooks.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
@interface UIView : NSObject
@property(nonatomic) CGRect frame;
@property(nonatomic) CGRect bounds;
@property(nonatomic) BOOL hidden;
@property(nonatomic) CGFloat alpha;
@property(nonatomic,weak) UIView *superview;
@property(nonatomic,strong) NSMutableArray<UIView *> *subviews;
@property(nonatomic,strong) CALayer *layer;
@property(nonatomic,copy) NSString *accessibilityLabel;
- (void)addSubview:(UIView *)view;
- (CGRect)convertRect:(CGRect)rect toView:(UIView *)view;
@end
@interface UIControl : UIView @end
@interface UITableViewCell : UIView @end
@interface UITableView : UIView
@property(nonatomic,strong) UIView *tableHeaderView;
@property(nonatomic,strong) NSArray *visibleCells;
@property(nonatomic,weak) id delegate;
- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell;
@end
@interface UIImage : NSObject
@property(nonatomic,copy) NSData *fixtureData;
+ (instancetype)imageWithCGImage:(CGImageRef)image;
@end
NSData *UIImagePNGRepresentation(UIImage *image);
