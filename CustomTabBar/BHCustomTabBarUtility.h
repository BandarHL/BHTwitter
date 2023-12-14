//
//  BHCustomTabBarUtility.h
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import <Foundation/Foundation.h>
#import "BHCustomTabBarSection.h"

NS_ASSUME_NONNULL_BEGIN

@interface BHCustomTabBarUtility : NSObject
+ (NSArray<NSString *> *)getAllowedTabBars;
+ (NSArray<NSString *> *)getHiddenTabBars;
@end

NS_ASSUME_NONNULL_END
