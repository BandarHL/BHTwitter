#import <Foundation/Foundation.h>
#import "FLEXRuntimeUtility.h"
#import "FLEXUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface RuntimeExplore : NSObject
+ (id)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely;
+ (NSString *)getAddressFromDescription:(NSString *)description;
@end

NS_ASSUME_NONNULL_END
