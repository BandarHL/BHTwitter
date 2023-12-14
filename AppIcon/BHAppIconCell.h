//
//  AppIconCell.h
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BHAppIconCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *checkIMG;
+ (NSString *)reuseIdentifier;
@end

NS_ASSUME_NONNULL_END
