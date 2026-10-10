#import "BHRDShareMediaQuality.h"
#import <ImageIO/ImageIO.h>
NSURL *BHRDHighQualityShareURL(NSURL *url) {
    if (![url.scheme.lowercaseString isEqual:@"https"] || ![url.host.lowercaseString isEqual:@"pbs.twimg.com"]) return nil;
    if (![url.path containsString:@"/media/"] && ![url.path containsString:@"_thumb/"]) return nil;
    NSURLComponents *parts = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSString *suffix in @[@":small", @":thumb", @":medium", @":large", @":orig"]) if ([parts.path hasSuffix:suffix]) { parts.path = [parts.path substringToIndex:parts.path.length - suffix.length]; break; }
    NSMutableArray *query = [NSMutableArray array];
    for (NSURLQueryItem *item in parts.queryItems) if (![item.name isEqual:@"name"]) [query addObject:item];
    [query addObject:[NSURLQueryItem queryItemWithName:@"name" value:@"large"]]; parts.queryItems = query;
    return parts.URL;
}
CGSize BHRDShareImagePixelSize(NSData *data) {
    if (!data.length || data.length > 12 * 1024 * 1024) return CGSizeZero;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return CGSizeZero;
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    BOOL complete = CGImageSourceGetStatus(source) == kCGImageStatusComplete; CFRelease(source);
    if (!complete) return CGSizeZero;
    CGFloat width = [properties[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue], height = [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue];
    NSInteger orientation = [properties[(__bridge NSString *)kCGImagePropertyOrientation] integerValue];
    return orientation >= 5 && orientation <= 8 ? CGSizeMake(height, width) : CGSizeMake(width, height);
}
BOOL BHRDShareImageNeedsUpgrade(NSData *data) { return BHRDShareImagePixelSize(data).width < 1000; }
BOOL BHRDShareImageIsBetter(NSData *candidate, NSData *current) {
    CGSize a = BHRDShareImagePixelSize(candidate), b = BHRDShareImagePixelSize(current);
    return a.width > 0 && a.height > 0 && a.width >= b.width && a.height >= b.height && (a.width > b.width || a.height > b.height);
}
static NSCache *QualityCache(void) {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 48; cache.totalCostLimit = 32 * 1024 * 1024; });
    return cache;
}
NSData *BHRDCachedQualityImage(NSURL *url) { return url.absoluteString ? [QualityCache() objectForKey:url.absoluteString] : nil; }
void BHRDCacheQualityImage(NSURL *url, NSData *data) {
    if (url.absoluteString && BHRDShareImagePixelSize(data).width > 0) [QualityCache() setObject:data forKey:url.absoluteString cost:data.length];
}
