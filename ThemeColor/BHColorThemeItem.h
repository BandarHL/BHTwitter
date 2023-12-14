//
//  BHColorThemeItem.h
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BHColorThemeItem : NSObject
@property(nonatomic, assign) NSInteger colorID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) UIColor *color;
- (instancetype)initWithColorID:(NSInteger)colorID name:(NSString *)name color:(UIColor *)color;
@end

NS_ASSUME_NONNULL_END
