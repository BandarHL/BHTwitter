#import <Foundation/Foundation.h>
NSURL *BHRDOriginalPhotoURL(id value);
NSString *BHRDPhotoPasteboardType(NSData *data);
BOOL BHRDPhotoCopyMayComplete(NSString *requested, NSString *current, NSUInteger requestGeneration, NSUInteger generation, BOOL visible, BOOL blocked);
@interface BHRDPhotoFetch : NSObject <NSURLSessionDataDelegate>
+ (instancetype)fetchURL:(NSURL *)url completion:(void (^)(NSData *, NSError *))completion;
- (void)cancel;
@end
