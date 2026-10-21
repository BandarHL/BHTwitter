#import <Foundation/Foundation.h>

FOUNDATION_EXPORT const NSUInteger BHRDShareImageByteLimit;
FOUNDATION_EXPORT const NSUInteger BHRDShareImageAggregateByteLimit;
BOOL BHRDShareImageURLAllowed(NSURL *url);

// A generation retains successful bytes, so the budget covers both in-flight
// buffers and the images accepted by that generation, across both workers.
@interface BHRDShareImageBudget : NSObject
@property(nonatomic, readonly) NSUInteger usedBytes;
- (instancetype)initWithLimit:(NSUInteger)limit;
@end

@interface BHRDShareImageFetch : NSObject <NSURLSessionDataDelegate>
+ (instancetype)fetchURL:(NSURL *)url budget:(BHRDShareImageBudget *)budget
             completion:(void (^)(NSData *data, NSError *error))completion;
- (void)cancel;
@end
