#import <UIKit/UIKit.h>
#import "../../BHRDShareLoadedMedia.h"
#import <objc/message.h>
@implementation UIView
- (instancetype)init { if ((self=[super init])) { _alpha=1; _userInteractionEnabled=YES; _subviews=[NSMutableArray array]; _layer=[CALayer layer]; } return self; }
- (instancetype)initWithFrame:(CGRect)frame { if ((self=[self init])) { self.frame=frame; self.bounds=CGRectMake(0,0,frame.size.width,frame.size.height); } return self; }
- (void)addSubview:(UIView *)view { view.superview=self; [self.subviews addObject:view]; }
- (void)removeFromSuperview { [self.superview.subviews removeObjectIdenticalTo:self]; self.superview=nil; }
- (void)bringSubviewToFront:(UIView *)view { if ([self.subviews containsObject:view]) { [self.subviews removeObjectIdenticalTo:view]; [self.subviews addObject:view]; } }
- (void)setNeedsLayout {}
- (void)layoutSubviews {}
- (void)addGestureRecognizer:(id)recognizer { (void)recognizer; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha<=0.01 || !self.userInteractionEnabled || !CGRectContainsPoint(self.bounds,point)) return nil;
    for (UIView *child in self.subviews.reverseObjectEnumerator) {
        UIView *hit=[child hitTest:CGPointMake(point.x-child.frame.origin.x,point.y-child.frame.origin.y) withEvent:event];
        if (hit) return hit;
    }
    return self;
}
- (BOOL)accessibilityActivate { return NO; }
+ (void)performWithoutAnimation:(void (^)(void))block { block(); }
- (CGRect)convertRect:(CGRect)rect toView:(UIView *)target {
    for (UIView *view=self; view && view!=target; view=view.superview) { rect.origin.x+=view.frame.origin.x; rect.origin.y+=view.frame.origin.y; }
    return rect;
}
@end
@interface FixtureControlAction : NSObject
@property(nonatomic,weak) id target;
@property(nonatomic) SEL selector;
@property(nonatomic) NSUInteger events;
@end
@implementation FixtureControlAction @end
@interface UIControl ()
@property(nonatomic,strong) NSMutableArray *fixtureActions;
@end
@implementation UIControl
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(NSUInteger)events {
    if (!self.fixtureActions) self.fixtureActions=[NSMutableArray array];
    FixtureControlAction *item=[FixtureControlAction new]; item.target=target; item.selector=action; item.events=events; [self.fixtureActions addObject:item];
}
- (void)sendActionsForControlEvents:(NSUInteger)events {
    for (FixtureControlAction *item in self.fixtureActions.copy) if ((item.events & events) && item.target) {
        NSMethodSignature *sig=[item.target methodSignatureForSelector:item.selector];
        if (sig.numberOfArguments==2) ((void(*)(id,SEL))objc_msgSend)(item.target,item.selector);
        else if (sig.numberOfArguments==3) ((void(*)(id,SEL,id))objc_msgSend)(item.target,item.selector,self);
    }
}
@end
@implementation UITableViewCell @end
@implementation UITableView
- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell { NSUInteger i=[self.visibleCells indexOfObject:cell]; return i==NSNotFound ? nil : [NSIndexPath indexPathWithIndex:i]; }
- (void)reloadData { self.fixtureReloadCount++; }
- (void)selectRowAtIndexPath:(NSIndexPath *)path animated:(BOOL)animated scrollPosition:(NSInteger)position { self.indexPathForSelectedRow=path; }
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
@end
@implementation UIStackView
- (void)addArrangedSubview:(UIView *)view { [self addSubview:view]; }
@end
@implementation UITapGestureRecognizer
- (instancetype)initWithTarget:(id)target action:(SEL)action { (void)target; (void)action; return [super init]; }
@end
NSData *UIImagePNGRepresentation(UIImage *image) { return image.fixtureData; }
void BHRDCaptureLoadedShareMedia(BHRDSharePost *post, UIView *card, NSArray *excluded) { (void)post; (void)card; (void)excluded; }
