#import <UIKit/UIKit.h>
#import <objc/runtime.h>
static char ResponderKey, TitleKey;
@implementation NSObject (HomeResponderFixture)
- (UIResponder *)nextResponder { return nil; }
@end
@implementation UIView (HomeFixture)
- (UIResponder *)nextResponder { return objc_getAssociatedObject(self, &ResponderKey) ?: self.superview; }
- (void)setFixtureNextResponder:(UIResponder *)responder { objc_setAssociatedObject(self, &ResponderKey, responder, OBJC_ASSOCIATION_ASSIGN); }
- (BOOL)isDescendantOfView:(UIView *)view { for (UIView *item=self; item; item=item.superview) if (item==view) return YES; return NO; }
@end
@implementation UIButton (HomeFixture)
- (NSString *)currentTitle { return objc_getAssociatedObject(self, &TitleKey); }
// The shared fixture's setTitle is intentionally minimal; install this behavior
// once so titles can be checked by the unmodified production reader.
+ (void)load {
    Method method=class_getInstanceMethod(self,@selector(setTitle:forState:));
    method_setImplementation(method,imp_implementationWithBlock(^(UIButton *button,NSString *title,NSUInteger state) {
        (void)state; objc_setAssociatedObject(button,&TitleKey,title,OBJC_ASSOCIATION_COPY_NONATOMIC);
    }));
}
@end
@implementation UIWindow @end
@implementation UICollectionViewCell @end
@implementation UIScrollView
- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated { (void)animated; self.contentOffset=offset; }
@end
@implementation UIViewController
- (instancetype)init { if ((self=[super init])) _childViewControllers=@[]; return self; }
@end
@implementation NSValue (HomeGeometry)
+ (instancetype)valueWithCGRect:(CGRect)rect { return [self valueWithBytes:&rect objCType:@encode(CGRect)]; }
+ (instancetype)valueWithCGSize:(CGSize)size { return [self valueWithBytes:&size objCType:@encode(CGSize)]; }
- (CGRect)CGRectValue { CGRect rect=CGRectZero; [self getValue:&rect size:sizeof(rect)]; return rect; }
- (CGSize)CGSizeValue { CGSize size=CGSizeZero; [self getValue:&size size:sizeof(size)]; return size; }
@end
