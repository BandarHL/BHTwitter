//
//  BHTBundle.h
//  BHTwitter
//
//  Created by BandarHelal on 07/08/2022.
//

#import <Foundation/Foundation.h>

@interface BHTBundle : NSObject
+ (instancetype)sharedBundle;
- (NSString *)localizedStringForKey:(NSString *)key;
- (NSURL *)pathForFile:(NSString *)fileName;
- (NSString *)BHTwitterVersion;
@end
