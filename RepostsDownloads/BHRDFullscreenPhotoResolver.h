#import <UIKit/UIKit.h>
@interface BHRDPhotoSnapshot : NSObject
@property(nonatomic,strong) UIImage *image;
@property(nonatomic,strong) NSURL *url;
@property(nonatomic,copy) NSString *identity;
@end
BHRDPhotoSnapshot *BHRDCurrentFullscreenPhoto(UIView *root);
