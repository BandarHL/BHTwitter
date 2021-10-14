//
//  HBTwitterCell.h
//  Cephei

#import "HBCell.h"

@interface HBTwitterCell : HBCell
- (instancetype)initTwitterCellWithTitle:(NSString *)title detail:(NSString *)detail AccountLink:(NSString *)Aurl;
@property (nonatomic, strong) UIImageView *TwitterImage;
@property (nonatomic, strong) NSString *AccountURL;
@end
