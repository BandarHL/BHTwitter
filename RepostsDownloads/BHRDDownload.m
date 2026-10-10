#import "BHRDDownload.h"
#import "BHRDTaskState.h"
@interface BHRDDownload ()
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) BHRDTaskState *state;
@property(nonatomic, strong) NSTimer *watchdog;
@property(nonatomic) NSTimeInterval stallTimeout;
@property(nonatomic) NSTimeInterval lastActivity;
@end
@implementation BHRDDownload
- (instancetype)init { return [self initWithStallTimeout:45]; }
- (instancetype)initWithStallTimeout:(NSTimeInterval)timeout {
    if ((self = [super init])) { _stallTimeout = MAX(1, timeout); _state = [BHRDTaskState new]; }
    return self;
}
- (void)downloadFileWithURL:(NSURL *)url {
    if (!url || self.session || self.state.finished) return;
    if (!BHRDTryBeginTransfer(self)) {
        [self.state finish];
        dispatch_async(dispatch_get_main_queue(), ^{ [self notifyFailure:[NSError errorWithDomain:@"BHRDBusy" code:1 userInfo:nil]]; });
        return;
    }
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.defaultSessionConfiguration;
    config.timeoutIntervalForRequest = self.stallTimeout;
    config.timeoutIntervalForResource = 1800;
    self.lastActivity = NSProcessInfo.processInfo.systemUptime;
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
    __weak BHRDDownload *weakSelf = self;
    self.state.cancelHandler = ^{ [weakSelf.session invalidateAndCancel]; };
    self.watchdog = [NSTimer timerWithTimeInterval:MIN(5, self.stallTimeout) repeats:YES block:^(__unused NSTimer *timer) {
        BHRDDownload *download = weakSelf;
        if (download && !download.state.finished && NSProcessInfo.processInfo.systemUptime - download.lastActivity >= download.stallTimeout) {
            if ([download.state finish]) {
                [download.session invalidateAndCancel];
                [download notifyFailure:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]];
            }
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:self.watchdog forMode:NSRunLoopCommonModes];
    [[self.session downloadTaskWithURL:url] resume];
}
- (void)notifyFailure:(NSError *)error {
    BHRDEndTransfer(self);
    [self.watchdog invalidate]; self.watchdog = nil;
    id<BHRDDownloadDelegate> delegate = self.delegate;
    self.delegate = nil;
    [delegate downloadDidFailureWithError:error];
}
- (void)cancel {
    if ([self.state cancel]) [self notifyFailure:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)bytes totalBytesWritten:(int64_t)total totalBytesExpectedToWrite:(int64_t)expected {
    if (self.state.finished) return;
    if (bytes > 0) self.lastActivity = NSProcessInfo.processInfo.systemUptime;
    [self.delegate downloadProgress:expected > 0 ? MIN(1.0, (float)total / expected) : -1];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:(NSURL *)location {
    if (![self.state finish]) return;
    [self.watchdog invalidate]; self.watchdog = nil;
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
    NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? response.statusCode : 0;
    NSString *mime = response.MIMEType.lowercaseString;
    if (status < 200 || status >= 300 || [mime hasPrefix:@"text/"] || [mime containsString:@"json"]) {
        [self notifyFailure:[NSError errorWithDomain:@"BHRDDownload" code:status userInfo:nil]];
        return;
    }
    BHRDEndTransfer(self);
    id<BHRDDownloadDelegate> delegate = self.delegate;
    self.delegate = nil;
    [delegate downloadDidFinish:location Filename:response.suggestedFilename ?: @"视频.mp4"];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && [self.state finish]) [self notifyFailure:error];
    [self.watchdog invalidate]; self.watchdog = nil;
    self.delegate = nil;
    [session finishTasksAndInvalidate];
    if (self.session == session) self.session = nil;
}
@end
