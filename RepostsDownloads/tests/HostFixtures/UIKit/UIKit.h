// Minimal view graph for exercising production author enrichment on macOS.
// It models coordinates/identity only; it does not emulate iOS rendering or hooks.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
@class UIColor, UIFont;
enum { UIViewAutoresizingFlexibleWidth=2, UIViewAutoresizingFlexibleHeight=16, UIViewAutoresizingFlexibleLeftMargin=1,
    UITableViewCellSelectionStyleNone=0, UIViewContentModeScaleAspectFill=2, UIViewContentModeScaleAspectFit=1,
    UILayoutConstraintAxisHorizontal=0, UIStackViewDistributionFillEqually=1, UIButtonTypeSystem=1,
    UIControlStateNormal=0, UIControlEventTouchUpInside=64, NSLineBreakByTruncatingTail=4 };
typedef NSInteger UITableViewCellSelectionStyle;
@interface UIView : NSObject
- (instancetype)initWithFrame:(CGRect)frame;
@property(nonatomic) CGRect frame;
@property(nonatomic) CGRect bounds;
@property(nonatomic) BOOL hidden;
@property(nonatomic) BOOL clipsToBounds;
@property(nonatomic) CGFloat alpha;
@property(nonatomic,weak) UIView *superview;
@property(nonatomic,weak) UIView *window;
@property(nonatomic,strong) NSMutableArray<UIView *> *subviews;
@property(nonatomic,strong) CALayer *layer;
@property(nonatomic,copy) NSString *accessibilityLabel;
@property(nonatomic,strong) UIColor *backgroundColor;
@property(nonatomic) NSUInteger autoresizingMask;
@property(nonatomic) BOOL isAccessibilityElement;
@property(nonatomic) BOOL userInteractionEnabled;
@property(nonatomic) NSInteger contentMode;
- (void)removeFromSuperview;
- (void)bringSubviewToFront:(UIView *)view;
- (void)setNeedsLayout;
- (void)layoutSubviews;
- (void)addGestureRecognizer:(id)recognizer;
+ (void)performWithoutAnimation:(void (^)(void))block;
- (void)addSubview:(UIView *)view;
- (CGRect)convertRect:(CGRect)rect toView:(UIView *)view;
@end
@interface UIControl : UIView @end
@interface UITableViewCell : UIView
@property(nonatomic) UITableViewCellSelectionStyle selectionStyle;
@end
@interface UITableView : UIView
@property(nonatomic,strong) UIView *tableHeaderView;
@property(nonatomic,strong) NSArray *visibleCells;
@property(nonatomic,weak) id delegate;
@property(nonatomic) BOOL hasUncommittedUpdates;
@property(nonatomic) BOOL dragging;
@property(nonatomic) BOOL decelerating;
- (void)reloadData;
- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell;
@end
@interface UIImageView : UIView
@property(nonatomic,strong) id image;
@end
@interface UIImage : NSObject
@property(nonatomic,readonly) CGImageRef CGImage;
@property(nonatomic,strong) id fixtureBackingImage;
@property(nonatomic) CGSize size;
@property(nonatomic,copy) NSData *fixtureData;
+ (instancetype)imageWithCGImage:(CGImageRef)image;
+ (instancetype)imageWithData:(NSData *)data;
+ (instancetype)systemImageNamed:(NSString *)name;
@end
@interface UIColor : NSObject
+ (instancetype)systemBackgroundColor;
+ (instancetype)secondarySystemBackgroundColor;
+ (instancetype)labelColor;
+ (instancetype)secondaryLabelColor;
@end
@interface UIFont : NSObject
+ (instancetype)systemFontOfSize:(CGFloat)size;
@end
@interface UILabel : UIView
@property(nonatomic,copy) NSString *text;
@property(nonatomic,strong) UIFont *font;
@property(nonatomic,strong) UIColor *textColor;
@property(nonatomic) NSInteger lineBreakMode;
@property(nonatomic) NSInteger numberOfLines;
@end
@interface UIButton : UIControl
+ (instancetype)buttonWithType:(NSInteger)type;
- (void)setTitle:(NSString *)title forState:(NSUInteger)state;
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(NSUInteger)events;
@end
@interface UIStackView : UIView
@property(nonatomic) NSInteger axis;
@property(nonatomic) NSInteger distribution;
@property(nonatomic) CGFloat spacing;
- (void)addArrangedSubview:(UIView *)view;
@end
@interface UITapGestureRecognizer : NSObject
- (instancetype)initWithTarget:(id)target action:(SEL)action;
@end
NSData *UIImagePNGRepresentation(UIImage *image);

FOUNDATION_EXPORT NSString * const UIPasteboardOptionLocalOnly;
FOUNDATION_EXPORT NSString * const UIPasteboardOptionExpirationDate;
@interface UIPasteboard : NSObject
+ (instancetype)generalPasteboard;
@property(nonatomic,copy) NSArray *fixtureItems;
@property(nonatomic,copy) NSDictionary *fixtureOptions;
- (void)setItems:(NSArray *)items options:(NSDictionary *)options;
@end
