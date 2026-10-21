#import <Foundation/Foundation.h>
@class MediaInformation;
@interface BHRDStreamJob : NSObject
+ (instancetype)probeURL:(NSURL *)url completion:(void (^)(MediaInformation *info, NSError *error))completion;
// Probe guards run on the main thread until the quality list is available. A
// confirmed download intentionally has no selection guard and may keep running.
+ (instancetype)probeURL:(NSURL *)url selectionStillCurrent:(BOOL (^)(void))selectionStillCurrent
              completion:(void (^)(MediaInformation *info, NSError *error))completion;
+ (instancetype)downloadURL:(NSURL *)url streamIndex:(NSNumber *)index completion:(void (^)(void))completion;
- (void)cancel;
@end
