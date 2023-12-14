//
//  BHCustomTabBarItem.h
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BHCustomTabBarItem : NSObject <NSCoding>
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *pageID;
- (instancetype)initWithTitle:(NSString *)title pageID:(NSString *)pageID;
@end

NS_ASSUME_NONNULL_END
