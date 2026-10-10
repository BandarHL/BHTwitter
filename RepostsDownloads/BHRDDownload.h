#import <Foundation/Foundation.h>
@protocol BHRDDownloadDelegate <NSObject>
- (void)downloadProgress:(float)progress;
- (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)fileName;
- (void)downloadDidFailureWithError:(NSError *)error;
@end
@interface BHRDDownload : NSObject <NSURLSessionDownloadDelegate>
// Retain the handler while a cell scrolls offscreen; release at task completion.
@property(nonatomic, strong) id<BHRDDownloadDelegate> delegate;
- (instancetype)initWithStallTimeout:(NSTimeInterval)timeout;
- (void)cancel;
- (void)downloadFileWithURL:(NSURL *)url;
@end
