//
//  HBTwitterCell.h
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBCell.h"

@interface HBTwitterCell : HBCell
//- (instancetype)initTwitterCellWithTitle:(NSString *)title detailTitle:(NSString *)Dtitle AccountLink:(NSString *)Aurl;
- (instancetype)initTwitterCellWithTitle:(NSString *)title detail:(NSString *)detail AccountLink:(NSString *)Aurl;
@property (nonatomic, strong) UIImageView *userImage;
@property (nonatomic, strong) UIImageView *TwitterImage;
@property (nonatomic, strong) UILabel *userName;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) NSString *AccountURL;
@end
