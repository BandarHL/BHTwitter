#import <UIKit/UIKit.h>
#import "../../BHRDShareLoadedMedia.h"
@implementation UIView
- (instancetype)init { if ((self=[super init])) { _alpha=1; _subviews=[NSMutableArray array]; _layer=[CALayer layer]; } return self; }
- (void)addSubview:(UIView *)view { view.superview=self; [self.subviews addObject:view]; }
- (CGRect)convertRect:(CGRect)rect toView:(UIView *)target {
    for (UIView *view=self; view && view!=target; view=view.superview) { rect.origin.x+=view.frame.origin.x; rect.origin.y+=view.frame.origin.y; }
    return rect;
}
@end
@implementation UIControl @end
@implementation UITableViewCell @end
@implementation UITableView
- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell { return [NSIndexPath indexPathWithIndex:[self.visibleCells indexOfObject:cell]]; }
@end
@implementation UIImageView @end
@implementation UIImage
- (CGImageRef)CGImage { return (__bridge CGImageRef)self.fixtureBackingImage; }
+ (instancetype)imageWithCGImage:(CGImageRef)image { UIImage *value=[self new]; value.fixtureBackingImage=(__bridge id)image; return value; }
@end
NSData *UIImagePNGRepresentation(UIImage *image) { return image.fixtureData; }
void BHRDCaptureLoadedShareMedia(BHRDSharePost *post, UIView *card, NSArray *excluded) { (void)post; (void)card; (void)excluded; }
