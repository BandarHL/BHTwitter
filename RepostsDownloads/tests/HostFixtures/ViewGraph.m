#import <UIKit/UIKit.h>
#import "../../BHRDShareLoadedMedia.h"
@implementation UIView
- (instancetype)init { if ((self=[super init])) { _alpha=1; _subviews=[NSMutableArray array]; _layer=[CALayer layer]; } return self; }
- (instancetype)initWithFrame:(CGRect)frame { if ((self=[self init])) { self.frame=frame; self.bounds=CGRectMake(0,0,frame.size.width,frame.size.height); } return self; }
- (void)addSubview:(UIView *)view { view.superview=self; [self.subviews addObject:view]; }
- (void)removeFromSuperview { [self.superview.subviews removeObjectIdenticalTo:self]; self.superview=nil; }
- (void)bringSubviewToFront:(UIView *)view { if ([self.subviews containsObject:view]) { [self.subviews removeObjectIdenticalTo:view]; [self.subviews addObject:view]; } }
- (void)setNeedsLayout {}
- (void)layoutSubviews {}
- (void)addGestureRecognizer:(id)recognizer { (void)recognizer; }
+ (void)performWithoutAnimation:(void (^)(void))block { block(); }
- (CGRect)convertRect:(CGRect)rect toView:(UIView *)target {
    for (UIView *view=self; view && view!=target; view=view.superview) { rect.origin.x+=view.frame.origin.x; rect.origin.y+=view.frame.origin.y; }
    return rect;
}
@end
@implementation UIControl @end
@implementation UITableViewCell @end
@implementation UITableView
- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell { NSUInteger i=[self.visibleCells indexOfObject:cell]; return i==NSNotFound ? nil : [NSIndexPath indexPathWithIndex:i]; }
- (void)reloadData {}
@end
@implementation UIImageView @end
@implementation UIImage
- (instancetype)init { if ((self=[super init])) _size=CGSizeMake(40,40); return self; }
- (CGImageRef)CGImage { return (__bridge CGImageRef)self.fixtureBackingImage; }
+ (instancetype)imageWithCGImage:(CGImageRef)image { UIImage *value=[self new]; value.fixtureBackingImage=(__bridge id)image; return value; }
+ (instancetype)imageWithData:(NSData *)data { UIImage *image=[self new]; image.fixtureData=data; return image; }
+ (instancetype)systemImageNamed:(NSString *)name { return [self imageWithData:[name dataUsingEncoding:NSUTF8StringEncoding]]; }
@end
@implementation UIColor
+ (instancetype)systemBackgroundColor { return [self new]; }
+ (instancetype)secondarySystemBackgroundColor { return [self new]; }
+ (instancetype)labelColor { return [self new]; }
+ (instancetype)secondaryLabelColor { return [self new]; }
@end
@implementation UIFont
+ (instancetype)systemFontOfSize:(CGFloat)size { (void)size; return [self new]; }
@end
@implementation UILabel @end
@implementation UIButton
+ (instancetype)buttonWithType:(NSInteger)type { (void)type; return [self new]; }
- (void)setTitle:(NSString *)title forState:(NSUInteger)state { (void)title; (void)state; }
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(NSUInteger)events { (void)target; (void)action; (void)events; }
@end
@implementation UIStackView
- (void)addArrangedSubview:(UIView *)view { [self addSubview:view]; }
@end
@implementation UITapGestureRecognizer
- (instancetype)initWithTarget:(id)target action:(SEL)action { (void)target; (void)action; return [super init]; }
@end
NSData *UIImagePNGRepresentation(UIImage *image) { return image.fixtureData; }
void BHRDCaptureLoadedShareMedia(BHRDSharePost *post, UIView *card, NSArray *excluded) { (void)post; (void)card; (void)excluded; }
