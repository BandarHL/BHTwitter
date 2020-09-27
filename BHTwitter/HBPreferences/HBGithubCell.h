//
//  HBGithubCell.h
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBCell.h"

@interface HBGithubCell : HBCell
- (instancetype)initGithubCellWithTitle:(NSString *)title detailTitle:(NSString *)Dtitle GithubURL:(NSString *)gURL;
@property (nonatomic, strong) UIImageView *GithubImage;
@property (nonatomic, strong) UIImageView *SafariImage;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) NSString *GithubURL;
@end
