//
//  HBSwitchCell.h
//  Cephei
//
//  Created by BandarHelal on 06/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBCell.h"


@interface HBSwitchCell : HBCell
- (instancetype)initSwitchCellWithImage:(UIImage *)image Title:(NSString *)title DetailTitle:(NSString *)Dtitle switchKey:(NSString *)key withBlock:(ALActionBlock)actionBlock;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UIImageView *image;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UISwitch *Switch;
@end
