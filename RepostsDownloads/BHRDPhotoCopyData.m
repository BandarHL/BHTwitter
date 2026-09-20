#import "BHRDPhotoCopyData.h"
#import <ImageIO/ImageIO.h>
static const NSUInteger PhotoLimit=32*1024*1024;
NSURL *BHRDOriginalPhotoURL(id value) {
    NSURL *url=[value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
    if (![url.scheme.lowercaseString isEqual:@"https"] || ![url.host.lowercaseString isEqual:@"pbs.twimg.com"]) return nil;
    NSURLComponents *parts=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if ([parts.path hasPrefix:@"/media/"]) {
        NSRange colon=[parts.path rangeOfString:@":" options:NSBackwardsSearch];
        if (colon.location!=NSNotFound) parts.path=[parts.path substringToIndex:colon.location];
        NSString *ext=parts.path.pathExtension.lowercaseString;
        NSMutableArray *query=[NSMutableArray array]; BOOL format=NO;
        for (NSURLQueryItem *item in parts.queryItems) {
            if ([item.name isEqual:@"name"]) continue;
            if ([item.name isEqual:@"format"]) { if (![@[@"jpg",@"jpeg",@"png",@"webp",@"gif"] containsObject:item.value.lowercaseString]) return nil; format=YES; }
            [query addObject:item];
        }
        if (ext.length) {
            if (![@[@"jpg",@"jpeg",@"png",@"webp",@"gif"] containsObject:ext]) return nil;
            parts.path=parts.path.stringByDeletingPathExtension;
            if (!format) [query addObject:[NSURLQueryItem queryItemWithName:@"format" value:ext]];
        }
        [query addObject:[NSURLQueryItem queryItemWithName:@"name" value:@"orig"]]; parts.queryItems=query;
    } else if ([parts.path hasPrefix:@"/profile_images/"]) {
        NSRegularExpression *suffix=[NSRegularExpression regularExpressionWithPattern:@"_(?:normal|200x200|mini|bigger|x[0-9]+)(?=\\.[^.]+$)" options:0 error:nil];
        parts.path=[suffix stringByReplacingMatchesInString:parts.path options:0 range:NSMakeRange(0,parts.path.length) withTemplate:@""];
        if ([parts.path.pathExtension.lowercaseString isEqual:@"svg"]) return nil;
    } else return nil;
    return parts.URL;
}
NSString *BHRDPhotoPasteboardType(NSData *data) {
    if (!data.length || data.length>PhotoLimit) return nil;
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL);
    if (!source) return nil;
    NSString *type=(__bridge NSString *)CGImageSourceGetType(source);
    NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
    double width=[properties[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue],height=[properties[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue];
    BOOL valid=CGImageSourceGetStatus(source)==kCGImageStatusComplete && width>0 && height>0 && width*height<=80000000;
    NSString *result=valid ? [type copy] : nil; CFRelease(source); return result;
}
BOOL BHRDPhotoCopyMayComplete(NSString *requested, NSString *current, NSUInteger requestGeneration, NSUInteger generation, BOOL visible, BOOL blocked) {
    return visible && !blocked && requestGeneration==generation && requested.length && [requested isEqual:current];
}
@interface BHRDPhotoFetch ()
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,strong) NSMutableData *data;
@property(nonatomic,copy) void (^completion)(NSData *,NSError *);
@property(nonatomic) BOOL finished;
@end
@implementation BHRDPhotoFetch
+ (instancetype)fetchURL:(NSURL *)url completion:(void (^)(NSData *,NSError *))completion {
    BHRDPhotoFetch *fetch=[self new]; fetch.completion=completion; fetch.data=[NSMutableData data];
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForRequest=15; config.timeoutIntervalForResource=30;
    fetch.session=[NSURLSession sessionWithConfiguration:config delegate:fetch delegateQueue:NSOperationQueue.mainQueue];
    [[fetch.session dataTaskWithURL:url] resume]; return fetch;
}
- (void)finish:(NSError *)error {
    if (self.finished) return; self.finished=YES;
    void (^completion)(NSData *,NSError *)=self.completion; self.completion=nil;
    NSData *data=error ? nil : [self.data copy]; self.data=nil;
    [self.session invalidateAndCancel]; self.session=nil;
    if (completion) completion(data,error);
}
- (void)cancel { [self finish:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]]; }
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completion {
    if (BHRDOriginalPhotoURL(request.URL)) completion(request);
    else { completion(nil); [self finish:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]]; }
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completion {
    BOOL valid=[response isKindOfClass:NSHTTPURLResponse.class] && [(NSHTTPURLResponse *)response statusCode]==200 && [response.MIMEType.lowercaseString hasPrefix:@"image/"] && response.expectedContentLength<=(int64_t)PhotoLimit;
    completion(valid ? NSURLSessionResponseAllow : NSURLSessionResponseCancel);
    if (!valid) [self finish:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if (self.finished) return;
    if (data.length>PhotoLimit-self.data.length) { [self finish:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorDataLengthExceedsMaximum userInfo:nil]]; return; }
    [self.data appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!error && !BHRDPhotoPasteboardType(self.data)) error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:nil];
    [self finish:error];
}
@end
