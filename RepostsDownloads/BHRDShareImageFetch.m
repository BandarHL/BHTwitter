#import "BHRDShareImageFetch.h"
#import "BHRDShareMediaQuality.h"

const NSUInteger BHRDShareImageByteLimit = 12 * 1024 * 1024;
const NSUInteger BHRDShareImageAggregateByteLimit = 24 * 1024 * 1024;
BOOL BHRDShareImageURLAllowed(NSURL *url) {
    return [url.scheme.lowercaseString isEqual:@"https"] &&
        [@[@"pbs.twimg.com", @"abs.twimg.com"] containsObject:url.host.lowercaseString] &&
        !url.user.length && !url.password.length && (!url.port || url.port.integerValue == 443);
}
@interface BHRDShareImageBudget ()
@property(nonatomic) NSUInteger usedBytes;
@property(nonatomic) NSUInteger limit;
- (BOOL)reserve:(NSUInteger)bytes;
- (void)releaseBytes:(NSUInteger)bytes;
@end
@implementation BHRDShareImageBudget
- (instancetype)initWithLimit:(NSUInteger)limit { if ((self = [super init])) _limit = limit; return self; }
- (BOOL)reserve:(NSUInteger)bytes {
    @synchronized(self) {
        if (bytes > self.limit - self.usedBytes) return NO;
        self.usedBytes += bytes; return YES;
    }
}
- (void)releaseBytes:(NSUInteger)bytes { @synchronized(self) { self.usedBytes -= MIN(bytes, self.usedBytes); } }
@end

@interface BHRDShareImageFetch ()
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSMutableData *data;
@property(nonatomic, strong) BHRDShareImageBudget *budget;
@property(nonatomic, copy) void (^completion)(NSData *, NSError *);
@property(nonatomic, copy) BOOL (^allowedURL)(NSURL *);
@property(nonatomic) BOOL finished;
@property(nonatomic) NSUInteger redirects;
@end
@implementation BHRDShareImageFetch
+ (instancetype)fetchURL:(NSURL *)url budget:(BHRDShareImageBudget *)budget completion:(void (^)(NSData *, NSError *))completion {
    return [self fetchURL:url budget:budget allowedURL:^BOOL(NSURL *candidate) { return BHRDShareImageURLAllowed(candidate); } completion:completion];
}
// Policy injection is private; fixture HTTP servers exercise the same delegate
// path while production callers always use the HTTPS CDN policy above.
+ (instancetype)fetchURL:(NSURL *)url budget:(BHRDShareImageBudget *)budget allowedURL:(BOOL (^)(NSURL *))allowedURL completion:(void (^)(NSData *, NSError *))completion {
    BHRDShareImageFetch *fetch = [self new]; fetch.budget = budget; fetch.allowedURL = allowedURL;
    fetch.completion = completion; fetch.data = [NSMutableData data];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (fetch.finished) return;
        if (!budget || !allowedURL || !allowedURL(url)) { [fetch fail:NSURLErrorUnsupportedURL]; return; }
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.timeoutIntervalForRequest = 12; config.timeoutIntervalForResource = 30;
        config.URLCache = nil; config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        config.HTTPCookieStorage = nil; config.HTTPShouldSetCookies = NO; config.URLCredentialStorage = nil;
        fetch.session = [NSURLSession sessionWithConfiguration:config delegate:fetch delegateQueue:NSOperationQueue.mainQueue];
        [[fetch.session dataTaskWithURL:url] resume];
    });
    return fetch;
}
- (void)fail:(NSInteger)code { [self finish:[NSError errorWithDomain:NSURLErrorDomain code:code userInfo:nil]]; }
- (void)finish:(NSError *)error {
    if (self.finished) return;
    self.finished = YES;
    if (error) [self.budget releaseBytes:self.data.length];
    // Transfer the buffer without another full-size copy. It is never mutated
    // after completion, and queued delegates all observe finished first.
    NSData *data = error ? nil : self.data; self.data = nil;
    void (^completion)(NSData *, NSError *) = self.completion; self.completion = nil;
    [self.session invalidateAndCancel]; self.session = nil;
    if (completion) completion(data, error);
}
- (void)cancel {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self cancel]; }); return; }
    [self fail:NSURLErrorCancelled];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completion {
    BOOL valid = !self.finished && ++self.redirects <= 4 && self.allowedURL(request.URL);
    completion(valid ? request : nil);
    if (!valid) [self fail:NSURLErrorBadServerResponse];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completion {
    NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
    NSString *contentType = [[[http valueForHTTPHeaderField:@"Content-Type"] componentsSeparatedByString:@";"].firstObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].lowercaseString;
    BOOL valid = !self.finished && http && http.statusCode == 200 && self.allowedURL(response.URL) &&
        [contentType hasPrefix:@"image/"] &&
        (response.expectedContentLength == NSURLResponseUnknownLength ||
         (response.expectedContentLength >= 0 && (uint64_t)response.expectedContentLength <= BHRDShareImageByteLimit));
    completion(valid ? NSURLSessionResponseAllow : NSURLSessionResponseCancel);
    if (!valid) [self fail:NSURLErrorBadServerResponse];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if (self.finished) return;
    if (data.length > BHRDShareImageByteLimit - self.data.length || ![self.budget reserve:data.length]) {
        [self fail:NSURLErrorDataLengthExceedsMaximum]; return;
    }
    [self.data appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (self.finished) return;
    if (!error && BHRDShareImagePixelSize(self.data).width <= 0) {
        [self fail:NSURLErrorCannotDecodeContentData]; return;
    }
    [self finish:error];
}
@end
