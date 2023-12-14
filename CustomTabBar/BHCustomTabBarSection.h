//
//  BHCustomTabBarSection.h
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import <Foundation/Foundation.h>
#import "BHCustomTabBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface BHCustomTabBarSection : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSMutableArray<BHCustomTabBarItem *> *items;
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<BHCustomTabBarItem *> *)items;
- (void)saveItemsForKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
