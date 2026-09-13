#import <UIKit/UIKit.h>
#import "BHRDSharePost.h"
@interface BHRDShareImageController : UIViewController
- (instancetype)initWithPost:(BHRDSharePost *)post;
@end
void BHRDOpenShareImageEditor(UIView *button, id preferredModel);
