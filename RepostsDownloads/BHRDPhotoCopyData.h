#import <Foundation/Foundation.h>
NSURL *BHRDOriginalPhotoURL(id value);
FOUNDATION_EXPORT const NSUInteger BHRDPhotoPixelLimit;
NSString *BHRDPhotoPasteboardType(NSData *data);
// Read metadata without decoding pixels; dimensions reflect EXIF orientation.
NSDictionary<NSString *, NSNumber *> *BHRDPhotoPixelDimensions(NSData *data);
BOOL BHRDPhotoCopyMayComplete(NSString *requested, NSString *current, NSUInteger requestGeneration, NSUInteger generation, BOOL visible, BOOL blocked);
@interface BHRDPhotoFetch : NSObject <NSURLSessionDataDelegate>
+ (instancetype)fetchURL:(NSURL *)url completion:(void (^)(NSData *, NSError *))completion;
- (void)cancel;
@end
