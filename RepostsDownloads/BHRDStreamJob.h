#import <Foundation/Foundation.h>
@class MediaInformation;
@interface BHRDStreamJob : NSObject
+ (instancetype)probeURL:(NSURL *)url completion:(void (^)(MediaInformation *info, NSError *error))completion;
+ (instancetype)downloadURL:(NSURL *)url streamIndex:(NSNumber *)index completion:(void (^)(void))completion;
- (void)cancel;
@end
