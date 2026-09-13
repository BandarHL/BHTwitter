#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import "../BHRDShareMediaQuality.h"
#import "../BHRDAdFilter.h"
#import "../BHRDPreferences.h"
static int count;
static void Check(BOOL value) { count++; if (!value) { NSLog(@"检查失败：%d",count); exit(1); } }
static NSData *PNG(size_t width, size_t height) {
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL,width,height,8,width*4,color,(CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.png"),1,NULL);
    CGImageDestinationAddImage(dest,image,NULL); CGImageDestinationFinalize(dest);
    CFRelease(dest); CGImageRelease(image); CGContextRelease(ctx); CGColorSpaceRelease(color); return data;
}
int main(void) { @autoreleasepool {
    NSURL *url = [NSURL URLWithString:@"https://pbs.twimg.com/media/a?format=jpg&name=small"];
    NSURL *hq = BHRDHighQualityShareURL(url);
    Check([hq.absoluteString isEqual:@"https://pbs.twimg.com/media/a?format=jpg&name=large"]);
    Check(BHRDHighQualityShareURL([NSURL URLWithString:@"https://pbs.twimg.com.evil.com/media/a"]) == nil);
    Check(BHRDHighQualityShareURL([NSURL URLWithString:@"https://pbs.twimg.com/profile_images/a"]) == nil);
    Check(BHRDHighQualityShareURL([NSURL URLWithString:@"bhrd-local://a"]) == nil);
    Check([BHRDHighQualityShareURL([NSURL URLWithString:@"https://pbs.twimg.com/ext_tw_video_thumb/a/img/b.jpg:small"]).absoluteString hasSuffix:@"b.jpg?name=large"]);
    NSData *small=PNG(320,180), *large=PNG(1600,900), *tall=PNG(320,1200);
    Check(BHRDShareImagePixelSize(large).width == 1600);
    Check(BHRDShareImageNeedsUpgrade(small)); Check(!BHRDShareImageNeedsUpgrade(large));
    Check(BHRDShareImageIsBetter(large,small)); Check(!BHRDShareImageIsBetter(small,large));
    Check(!BHRDShareImageIsBetter(tall,large)); Check(!BHRDShareImageIsBetter(large,large));
    Check(!BHRDShareImageIsBetter([@"bad" dataUsingEncoding:NSUTF8StringEncoding],large));
    Check(BHRDShareImageIsBetter(large,nil));
    BHRDCacheQualityImage(hq,large); Check([BHRDCachedQualityImage(hq) isEqual:large]);
    NSDictionary *ad=@{@"isPromoted":@YES}, *organic=@{@"text":@"ad_ promoted_id 广告", @"isPromoted":@NO};
    Check(BHRDIsPromotedModel(ad)); Check(!BHRDIsPromotedModel(organic));
    Check(BHRDIsPromotedModel(@{@"status":ad}));
    Check(BHRDIsPromotedModel(@{@"scribeItem":@{@"promoted_id":@"123"}}));
    Check(!BHRDIsPromotedModel(@{@"scribeItem":@{@"promoted_id":@""}}));
    Check(!BHRDIsPromotedModel(@{@"scribeItem":@{@"promoted_id":NSNull.null}}));
    Check(!BHRDIsPromotedModel(@{@"quotedStatus":ad}));
    Check(!BHRDIsPromotedModel(NSNull.null));
    NSArray *sections=@[@[organic,ad],@[],@"unknown"];
    NSArray *filtered=BHRDSectionsByRemovingAds(sections);
    Check([filtered isEqual:@[@[organic],@[],@"unknown"]]);
    Check([sections[0] count]==2); Check(BHRDSectionsByRemovingAds(filtered)==filtered);
    NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:@"BHRDQualityAdsTests"];
    [defaults removePersistentDomainForName:@"BHRDQualityAdsTests"];
    Check(BHRDReadPreference(defaults,BHRDHideAdsKey));
    [defaults setBool:NO forKey:BHRDHideRepostsKey]; Check(BHRDReadPreference(defaults,BHRDHideAdsKey));
    [defaults setBool:NO forKey:BHRDHideAdsKey]; Check(!BHRDReadPreference(defaults,BHRDHideAdsKey));
    [defaults removePersistentDomainForName:@"BHRDQualityAdsTests"];
    NSLog(@"高清图片与广告过滤：%d 项通过",count);
} return 0; }
