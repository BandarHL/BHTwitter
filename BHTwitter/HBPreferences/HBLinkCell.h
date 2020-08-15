//
//  HBLinkCell.h
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBCell.h"

@interface HBLinkCell : HBCell
- (instancetype)initLinkCellWithImage:(UIImage *)img Title:(NSString *)title DetailTitle:(NSString *)Dtitle Link:(NSString *)url;
@property (nonatomic, strong) UIImageView *SafariImage;
@property (nonatomic, strong) UIImageView *image;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIButton *openURLbutton;
@end
