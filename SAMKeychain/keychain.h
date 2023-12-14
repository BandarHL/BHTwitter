//
//  keychain.h
//  BHTwitter
//
//  Created by BandarHelal on 25/09/2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface keychain : NSObject
+ (instancetype)shared;
- (void)saveDictionary:(NSDictionary *)dicData;
- (NSDictionary *)getData;
- (void)deleteService;
@end

NS_ASSUME_NONNULL_END
