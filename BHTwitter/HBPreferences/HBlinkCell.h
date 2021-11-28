//
//  HBlinkCell.h
//  Cephei

#import "HBCell.h"
@interface HBlinkCell : HBCell
- (instancetype)initLinkCellWithTitle:(NSString *)title detailTitle:(NSString *)Dtitle link:(NSString *)gURL;
@property (nonatomic, strong) UIImageView *SafariImage;
@property (nonatomic, strong) NSString *url;
@end
