#import <Foundation/Foundation.h>
extern NSString * const BHRDPhotoSaveErrorDomain;
typedef NS_ENUM(NSInteger, BHRDPhotoSaveError) {
    BHRDPhotoSaveInvalidData=1, BHRDPhotoSaveMissingUsage, BHRDPhotoSaveDenied,
    BHRDPhotoSaveCancelled, BHRDPhotoSaveFailed
};
// Pass supported originals unchanged; convert other still images to an
// orientation-correct PNG. Unsupported animations require a displayed fallback.
NSData *BHRDPhotoLibraryPayload(NSData *data);
@interface BHRDPhotoSaveJob : NSObject
@property(nonatomic,readonly) BOOL committed;
@property(nonatomic,readonly) BOOL finished;
+ (instancetype)saveData:(NSData *)data hostInfo:(NSDictionary *)info
           stillCurrent:(BOOL (^)(void))stillCurrent
             completion:(void (^)(BOOL success, NSError *error))completion;
- (void)cancel;
@end
