//
//  HBButtonCell.h
//  Cephei
//
//  Created by BandarHelal on 06/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBCell.h"

//typedef void (^HBPValueChanged)(id sender);

@interface HBButtonCell : HBCell
- (instancetype)initButtonCellWithTitle:(NSString *)title actionBlock:(HBPValueChanged)actionBlock image:(UIImage *)img DetailTitle:(NSString *)Dtitle;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UIImageView *image;
@property (nonatomic, strong) UILabel *detailLabel;
@end
