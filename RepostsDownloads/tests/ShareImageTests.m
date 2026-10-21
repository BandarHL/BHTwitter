#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import "../BHRDSharePost.h"
#import "../BHRDShareRenderer.h"
#import "../BHRDRepostAuthor.h"
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) { checks++; if (!pass) { NSLog(@"FAIL: %@", name); exit(1); } }
@interface ShareModel : NSObject
@property(nonatomic, copy) NSString *statusID;
@property(nonatomic, strong) NSAttributedString *fullText;
@end
@implementation ShareModel @end
static CGImageRef Image(NSData *data) CF_RETURNS_RETAINED {
    if (!data.length) return NULL;
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!src) return NULL;
    CGImageRef image = CGImageSourceCreateImageAtIndex(src, 0, NULL); CFRelease(src); return image;
}
static NSData *FixtureImage(void) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, 600, 360, 8, 2400, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast); CGColorSpaceRelease(space);
    CGContextSetRGBFillColor(ctx, .16, .46, .65, 1); CGContextFillRect(ctx, CGRectMake(0, 0, 600, 360));
    CGContextSetRGBFillColor(ctx, .3, .65, .47, 1); CGContextFillEllipseInRect(ctx, CGRectMake(-60, -190, 540, 480));
    CGContextSetRGBFillColor(ctx, .99, .81, .34, 1); CGContextFillEllipseInRect(ctx, CGRectMake(430, 230, 90, 90));
    CGImageRef img = CGBitmapContextCreateImage(ctx); CGContextRelease(ctx);
    NSMutableData *png = [NSMutableData data]; CGImageDestinationRef dst = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)png, CFSTR("public.png"), 1, NULL);
    CGImageDestinationAddImage(dst, img, NULL); CGImageDestinationFinalize(dst); CFRelease(dst); CGImageRelease(img); return png;
}
static BOOL CornerMatches(CGImageRef image, NSUInteger rgb) {
    CGImageRef corner = CGImageCreateWithImageInRect(image, CGRectMake(0, 0, 1, 1));
    unsigned char pixel[4] = {0}; CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast); CGColorSpaceRelease(space);
    CGContextDrawImage(ctx, CGRectMake(0, 0, 1, 1), corner); CGContextRelease(ctx); CGImageRelease(corner);
    return abs(pixel[0] - (int)((rgb >> 16) & 255)) <= 1 && abs(pixel[1] - (int)((rgb >> 8) & 255)) <= 1 && abs(pixel[2] - (int)(rgb & 255)) <= 1;
}
// Inspect the exported pixels as well as the parsed strings. A successful PNG
// with an avatar and an empty author column was the reported failure.
static NSUInteger AuthorInkPixels(NSData *png) {
    CGImageRef image = Image(png);
    if (!image) return 0;
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    unsigned char *pixels = calloc(width * height, 4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), image);
    NSUInteger ink = 0;
    // The left 17% contains the avatar; only count the adjacent text column.
    for (size_t y = 0; y < height; y++) for (size_t x = (size_t)ceil(width * 0.17); x < width; x++) {
        unsigned char *pixel = pixels + (y * width + x) * 4;
        if (pixel[0] > 70 && pixel[1] > 70 && pixel[2] > 70) ink++;
    }
    CGContextRelease(ctx); CGImageRelease(image); free(pixels);
    return ink;
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *out = [NSString stringWithUTF8String:argv[1]];
        [[NSFileManager defaultManager] createDirectoryAtPath:out withIntermediateDirectories:YES attributes:nil error:nil];
        NSDictionary *user = @{@"legacy": @{@"name": @"分享示例作者", @"screen_name": @"example", @"profile_image_url_https": @"https://pbs.twimg.com/profile_images/sample.png"}};
        NSDictionary *tweet = @{@"rest_id": @"123456789", @"core": @{@"user_results": @{@"result": user}}, @"legacy": @{@"id_str": @"123456789", @"full_text": @"这是较短的 API 预览", @"extended_entities": @{@"media": @[@{@"media_url_https": @"https://pbs.twimg.com/media/sample.png"}] }}, @"note_tweet": @{@"note_tweet_results": @{@"result": @{@"text": @"把值得分享的内容，变成一张好看的图片。\n\n支持六种背景配色，也可以自由显示或隐藏站点标识、标题、作者、正文和链接。\n\n中文、English、表情 🌿✨ 与多段长文都能保留。"}}}};
        NSDictionary *payload = @{@"data": @{@"tweet_results": @{@"result": tweet}}};
        NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]; BHRDCacheSharePosts(payload, json);
        ShareModel *model = [ShareModel new]; model.statusID = @"123456789";
        BHRDSharePost *post = BHRDSharePostFromSource(model);
        Check([post.body hasPrefix:@"把值得分享"], @"Prefer complete long-post text over truncated API preview");
        Check([post.author isEqual:@"分享示例作者"] && [post.handle isEqual:@"example"], @"Legacy recursion does not erase author metadata");
        Check([post.link isEqual:@"https://x.com/i/status/123456789"], @"Build the source tweet link from its real ID");
        Check(post.images.count == 1 && post.avatar != nil, @"Preserve media and author avatar URLs");
        post.title = @"让分享更有温度";
        BHRDSharePost *fresh = BHRDSharePostFromSource(model);
        Check(![fresh.title isEqual:post.title], @"Editing a share card cannot mutate the cached original tweet");
        ShareModel *uncached = [ShareModel new]; uncached.fullText = [[NSAttributedString alloc] initWithString:@"原生模型的正文"];
        Check([BHRDSharePostFromSource(uncached).body isEqual:@"原生模型的正文"], @"Native attributed text works without a network response");
        NSString *suite = [@"XSuixinShareTests." stringByAppendingString:NSUUID.UUID.UUIDString]; NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        NSDictionary *options = BHRDShareOptions(defaults); Check(options.count == 6, @"Display choices include the bilingual option");
        for (NSString *key in BHRDShareOptionKeys()) Check([options[key] boolValue], @"Display sections default to visible");
        [defaults setBool:NO forKey:@"bhrd_share_author"]; Check(![BHRDShareOptions(defaults)[@"author"] boolValue], @"Display choice persists independently"); [defaults removePersistentDomainForName:suite];
        NSData *photo = FixtureImage(); NSDictionary *images = @{post.images.firstObject.absoluteString: photo, post.avatar.absoluteString: photo};
        NSMutableDictionary *authorOnly = [options mutableCopy];
        for (NSString *key in authorOnly.allKeys) authorOnly[key] = @([key isEqual:@"author"]);
        BHRDSharePost *header = [BHRDSharePost new]; header.avatarData = photo;
        Check(AuthorInkPixels(BHRDRenderSharePNG(header, 3, authorOnly, @{}, nil)) == 0, @"Avatar-only control has no ink in the author column");
        header.author = @"贝塔酱";
        NSUInteger nameInk = AuthorInkPixels(BHRDRenderSharePNG(header, 3, authorOnly, @{}, nil));
        Check(nameInk > 300, @"Chinese display name paints visible pixels beside the avatar on pure black");
        header.author = @""; header.handle = @"Walden779";
        NSUInteger handleInk = AuthorInkPixels(BHRDRenderSharePNG(header, 3, authorOnly, @{}, nil));
        Check(handleInk > 300, @"English username paints visible pixels even without a display name");
        header.author = @"贝塔酱";
        NSData *headerPNG = BHRDRenderSharePNG(header, 3, authorOnly, @{}, nil);
        Check(AuthorInkPixels(headerPNG) > MAX(nameInk, handleInk), @"Both display name and username survive the actual PNG export");
        [headerPNG writeToFile:[out stringByAppendingPathComponent:@"author-black.png"] atomically:YES];
        NSDictionary *nativeHeader = BHRDSelectRepostAuthor(@[@{
            @"text": @"魔都日常。 \u2066\u202A@narutomohamed93\u202C\u2069。 已验证, 按钮, 双击以查看个人资料。双击并按住以屏蔽用户或举报垃圾信息。",
            @"x": @65, @"y": @12, @"semantic": @YES, @"accessibility": @YES
        }], nil);
        BHRDSharePost *nativePost = [BHRDSharePost new]; nativePost.avatarData = photo;
        BHRDApplyShareTextRows(nativePost, @[@{@"role": @"author", @"text": nativeHeader[@"name"] ?: @""},
                                               @{@"role": @"handle", @"text": nativeHeader[@"handle"] ?: @""}]);
        Check([nativePost.author isEqual:@"魔都日常"] && [nativePost.handle isEqual:@"narutomohamed93"], @"Recorded X author text reaches the sharing model without manual editing");
        NSData *nativePNG = BHRDRenderSharePNG(nativePost, 3, authorOnly, @{}, nil);
        Check(AuthorInkPixels(nativePNG) > MAX(nameInk, handleInk), @"Recorded X author text paints both lines in the exported image");
        [nativePNG writeToFile:[out stringByAppendingPathComponent:@"native-author-black.png"] atomically:YES];
        NSUInteger fullHeight = 0;
        for (NSUInteger theme = 0; theme < BHRDShareThemes().count; theme++) {
            NSError *error = nil; NSData *png = BHRDRenderSharePNG(post, theme, options, images, &error); CGImageRef image = Image(png);
            Check(image && !error && CGImageGetWidth(image) == 1125, @"Every theme produces an exportable 3x PNG");
            Check(CornerMatches(image, [BHRDShareThemes()[theme][@"background"] unsignedIntegerValue]), @"Exported background matches the fluxdo palette exactly");
            fullHeight = CGImageGetHeight(image); CGImageRelease(image);
            [png writeToFile:[out stringByAppendingPathComponent:[NSString stringWithFormat:@"theme-%lu.png", (unsigned long)theme]] atomically:YES];
        }
        NSMutableDictionary *hidden = [options mutableCopy]; hidden[@"content"] = @NO;
        CGImageRef less = Image(BHRDRenderSharePNG(post, 0, hidden, images, nil)); Check(CGImageGetHeight(less) < fullHeight, @"Hiding body also removes media and collapses its space"); CGImageRelease(less);
        for (NSString *key in hidden.allKeys) hidden[key] = @NO;
        CGImageRef empty = Image(BHRDRenderSharePNG(post, 0, hidden, images, nil)); Check(empty && CGImageGetHeight(empty) < 300, @"All-off choices render a compact empty state"); CGImageRelease(empty);
        BHRDSharePost *longPost = [post copy]; longPost.body = [@"长文不会只截取屏幕可见部分。\n" stringByPaddingToLength:4000 withString:@"连续正文段落与换行。\n" startingAtIndex:0];
        CGImageRef longImage = Image(BHRDRenderSharePNG(longPost, 0, options, images, nil)); Check(longImage && CGImageGetHeight(longImage) > fullHeight * 2 && CGImageGetHeight(longImage) <= 16001, @"Long text exports beyond the preview viewport within memory limits"); CGImageRelease(longImage);
        BHRDSharePost *quoted = [BHRDSharePost new]; quoted.identifier = @"quoted-456";
        quoted.author = @"原文作者"; quoted.handle = @"original_author";
        quoted.body = @"这是被引用的原文。\n原文作者、正文、配图和链接都应完整保留，与上方主推文分开显示。";
        quoted.link = @"https://x.com/i/status/quoted-456"; quoted.avatarData = photo; quoted.images = post.images;
        BHRDSharePost *withQuote = [post copy]; withQuote.quotedPost = quoted; withQuote.avatarData = photo;
        NSData *quotePNG = BHRDRenderSharePNG(withQuote, 0, options, images, nil); CGImageRef quoteImage = Image(quotePNG);
        Check(quoteImage && CGImageGetHeight(quoteImage) > fullHeight + 200, @"Quoted original author/body/media are rendered as an additional full section");
        CGImageRelease(quoteImage);
        [quotePNG writeToFile:[out stringByAppendingPathComponent:@"quoted-original.png"] atomically:YES];
        BHRDSharePost *immediate = [post copy];
        immediate.imageData = @{post.images.firstObject.absoluteString: photo}; immediate.avatarData = photo;
        NSData *localPNG = BHRDRenderSharePNG(immediate, 0, options, @{}, nil);
        NSData *remotePNG = BHRDRenderSharePNG(post, 0, options, images, nil);
        Check([localPNG isEqual:remotePNG], @"Embedded, already-loaded media renders identically without a network response");
        Check(BHRDShareEmbeddedImages(immediate).count == 2, @"Seed the preview with media and avatar data before loading URLs");
        BHRDSharePost *bilingual = [immediate copy]; bilingual.author = @""; bilingual.handle = @"";
        bilingual.title = @"双语分享示例";
        bilingual.body = @"Original text stays complete. The existing Chinese translation is rendered below, rather than replacing this paragraph.";
        bilingual.bodyIsOriginal = YES;
        BHRDApplyShareTextRows(bilingual, @[@{@"role": @"translation", @"text": @"保留完整外语原文，下方同时显示已经展开的中文译文。"}]);
        Check([bilingual.body hasPrefix:@"Original text"] && [bilingual.translatedBody hasPrefix:@"保留完整"], @"A shorter Chinese translation is retained separately from the foreign original");
        NSData *bothPNG = BHRDRenderSharePNG(bilingual, 4, options, @{}, nil);
        NSMutableDictionary *originalOnly = [options mutableCopy]; originalOnly[@"bilingual"] = @NO;
        CGImageRef both = Image(bothPNG);
        CGImageRef originalImage = Image(BHRDRenderSharePNG(bilingual, 4, originalOnly, @{}, nil));
        Check(both && originalImage && CGImageGetHeight(both) > CGImageGetHeight(originalImage), @"Bilingual mode exports both text sections");
        CGImageRelease(both); CGImageRelease(originalImage);
        [bothPNG writeToFile:[out stringByAppendingPathComponent:@"bilingual-local-media.png"] atomically:YES];
        bilingual.translatedBody = [bilingual.body stringByAppendingString:@" "];
        Check(!BHRDShareHasDistinctTranslation(bilingual), @"Identical text is not repeated as a translation");
        BHRDSharePost *withShortLinks = [post copy];
        withShortLinks.body = [post.body stringByAppendingString:@" https://t.co/iRHfiFxFR7"];
        NSData *cleanRender = BHRDRenderSharePNG(withShortLinks, 0, options, images, nil);
        Check([cleanRender isEqual:BHRDRenderSharePNG(post, 0, options, images, nil)], @"Actual PNG export removes the short URL before measuring and rendering");
        Check([withShortLinks.body hasSuffix:@"https://t.co/iRHfiFxFR7"], @"Rendering keeps source body untouched");
        BHRDSharePost *replyPreview = [post copy]; replyPreview.title = @"回复与原帖"; replyPreview.body = @"这是当前回复，原帖显示在下方。"; replyPreview.translatedBody = @"";
        replyPreview.replyToIdentifier = post.identifier; replyPreview.identifier = @"reply-preview";
        BHRDAttachShareReplyContext(replyPreview, post);
        NSData *replyPNG = BHRDRenderSharePNG(replyPreview, 1, options, images, nil);
        Check(replyPNG.length > 0, @"Reply plus original renders a real PNG");
        [replyPNG writeToFile:[out stringByAppendingPathComponent:@"reply-with-original.png"] atomically:YES];
        NSLog(@"PASS: %lu sharing data/render checks", (unsigned long)checks);
    }
    return 0;
}
