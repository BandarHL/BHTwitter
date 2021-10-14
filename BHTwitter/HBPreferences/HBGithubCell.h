//
//  HBGithubCell.h
//  Cephei

#import "HBCell.h"

@interface HBGithubCell : HBCell
- (instancetype)initGithubCellWithTitle:(NSString *)title detailTitle:(NSString *)Dtitle GithubURL:(NSString *)gURL;
@property (nonatomic, strong) UIImageView *GithubImage;
@property (nonatomic, strong) UIImageView *SafariImage;
@property (nonatomic, strong) NSString *GithubURL;
@end
