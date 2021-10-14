//
//  HBViewControllerCell.h
//  Cephei

#import "HBCell.h"

@interface HBViewControllerCell : HBCell
- (instancetype)initCellWithTitle:(NSString *)title detail:(NSString *)detail action:(UIViewController* (^_Nonnull)(void))action;
@end
