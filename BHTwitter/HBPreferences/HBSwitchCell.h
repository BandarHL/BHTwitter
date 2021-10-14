//
//  HBSwitchCell.h
//  Cephei

#import "HBCell.h"


@interface HBSwitchCell : HBCell
- (instancetype)initSwitchCellWithImage:(UIImage *)image Title:(NSString *)title DetailTitle:(NSString *)Dtitle switchKey:(NSString *)key withBlock:(ALActionBlock)actionBlock;
@property (nonatomic, strong) UISwitch *Switch;
@end
