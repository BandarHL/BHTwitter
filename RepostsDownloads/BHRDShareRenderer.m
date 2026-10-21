#import "BHRDShareRenderer.h"
#import "BHRDShareTextCleanup.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <ImageIO/ImageIO.h>
#import <math.h>

static CGColorRef Color(NSUInteger rgb, CGFloat alpha) CF_RETURNS_RETAINED {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {((rgb >> 16) & 255) / 255.0, ((rgb >> 8) & 255) / 255.0, (rgb & 255) / 255.0, alpha};
    CGColorRef color = CGColorCreate(space, components); CGColorSpaceRelease(space); return color;
}
static NSAttributedString *Styled(NSString *text, CGFloat size, BOOL bold, NSUInteger rgb, CGFloat alpha) {
    CTFontRef font = CTFontCreateUIFontForLanguage(bold ? kCTFontUIFontEmphasizedSystem : kCTFontUIFontSystem, size, NULL);
    CGFloat spacing = 4;
    CTParagraphStyleSetting settings[] = {{kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof(spacing), &spacing}};
    CTParagraphStyleRef style = CTParagraphStyleCreate(settings, 1);
    CGColorRef color = Color(rgb, alpha);
    NSAttributedString *result = [[NSAttributedString alloc] initWithString:text ?: @"" attributes:@{
        (__bridge NSString *)kCTFontAttributeName: (__bridge id)font,
        (__bridge NSString *)kCTForegroundColorAttributeName: (__bridge id)color,
        (__bridge NSString *)kCTParagraphStyleAttributeName: (__bridge id)style
    }];
    CFRelease(font); CFRelease(style); CGColorRelease(color); return result;
}
static CGFloat TextHeight(NSAttributedString *text, CGFloat width) {
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text);
    CGSize size = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRangeMake(0, text.length), NULL, CGSizeMake(width, CGFLOAT_MAX), NULL);
    CFRelease(setter); return ceil(size.height) + 3;
}
static void DrawText(CGContextRef ctx, NSAttributedString *text, CGRect rect) {
    if (!text.length || rect.size.width <= 0 || rect.size.height <= 0) return;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, rect.origin.x, rect.origin.y + rect.size.height);
    CGContextScaleCTM(ctx, 1, -1);
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text);
    CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, rect.size.width, rect.size.height), NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, text.length), path, NULL);
    CTFrameDraw(frame, ctx); CFRelease(frame); CGPathRelease(path); CFRelease(setter);
    CGContextRestoreGState(ctx);
}
static CGImageRef Decode(NSData *data) CF_RETURNS_RETAINED {
    if (!data.length) return NULL;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return NULL;
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CGFloat width = MAX(1, [properties[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue]);
    CGFloat height = MAX(1, [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue]);
    CGFloat maximum = MIN(4096, MAX(1800, 1125 * height / width));
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)@{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(maximum)
    });
    CFRelease(source); return image;
}
static NSValue *BHRDRectValue(CGRect rect) { return [NSValue value:&rect withObjCType:@encode(CGRect)]; }
static CGRect Unrect(NSValue *value) { CGRect r; [value getValue:&r]; return r; }
static void Fill(CGContextRef ctx, CGRect rect, NSUInteger rgb, CGFloat alpha, CGFloat radius) {
    CGColorRef color = Color(rgb, alpha); CGContextSetFillColorWithColor(ctx, color); CGColorRelease(color);
    CGPathRef path = CGPathCreateWithRoundedRect(rect, radius, radius, NULL); CGContextAddPath(ctx, path); CGContextFillPath(ctx); CGPathRelease(path);
}
NSData *BHRDRenderSharePNG(BHRDSharePost *post, NSInteger themeIndex, NSDictionary *options, NSDictionary<NSString *, NSData *> *images, NSError **error) {
    post = BHRDCleanSharePostForRendering(post);
    NSArray *themes = BHRDShareThemes();
    NSDictionary *theme = themes[themeIndex >= 0 && themeIndex < (NSInteger)themes.count ? themeIndex : 0];
    BOOL dark = [theme[@"dark"] boolValue]; NSUInteger ink = dark ? 0xFFFFFF : 0;
    NSMutableArray<NSDictionary *> *blocks = [NSMutableArray array];
    __block CGFloat y = 20;
    __block BOOL any = NO;
    void (^text)(NSString *, CGFloat, CGFloat, CGFloat, BOOL, CGFloat) = ^(NSString *value, CGFloat x, CGFloat width, CGFloat size, BOOL bold, CGFloat alpha) {
        NSAttributedString *styled = Styled(value, size, bold, ink, alpha);
        CGFloat h = TextHeight(styled, width);
        [blocks addObject:@{@"type": @"text", @"text": styled, @"rect": BHRDRectValue(CGRectMake(x, y, width, h))}];
        y += h;
    };
    if ([options[@"logo"] boolValue]) {
        [blocks addObject:@{@"type": @"logo", @"rect": BHRDRectValue(CGRectMake(20, y, 28, 28))}];
        [blocks addObject:@{@"type": @"text", @"text": Styled(@"X / TWITTER", 16, YES, ink, 0.8), @"rect": BHRDRectValue(CGRectMake(56, y + 3, 299, 26))}];
        y += 28; any = YES;
    }
    if ([options[@"title"] boolValue]) { if (any) y += 16; text(post.title ?: @"X 推文", 20, 335, 16, YES, 0.9); any = YES; }
    if ([options[@"author"] boolValue]) {
        if (any) y += 12;
        [blocks addObject:@{@"type": @"avatar", @"data": images[post.avatar.absoluteString ?: @""] ?: post.avatarData ?: NSData.data, @"rect": BHRDRectValue(CGRectMake(20, y, 36, 36))}];
        NSString *name = post.author ?: @"";
        NSAttributedString *nameText = Styled(name, 14, YES, ink, 0.85);
        CGFloat nameHeight = name.length ? TextHeight(nameText, 289) : 0;
        [blocks addObject:@{@"type": @"text", @"text": nameText, @"rect": BHRDRectValue(CGRectMake(66, y, 289, nameHeight))}];
        NSString *handle = post.handle.length ? [@"@" stringByAppendingString:post.handle] : @"";
        NSAttributedString *handleText = Styled(handle, 12, NO, ink, 0.6);
        CGFloat handleHeight = handle.length ? TextHeight(handleText, 289) : 0;
        [blocks addObject:@{@"type": @"text", @"text": handleText, @"rect": BHRDRectValue(CGRectMake(66, y + nameHeight + 2, 289, handleHeight))}];
        y += MAX(36, nameHeight + 2 + handleHeight);
        if (post.repostedBy.length) { y += 6; text([NSString stringWithFormat:@"由 %@ 转发", post.repostedBy], 20, 335, 11, NO, 0.6); }
        any = YES;
    }
    if ([options[@"content"] boolValue]) {
        if (any) { y += 12; [blocks addObject:@{@"type": @"line", @"rect": BHRDRectValue(CGRectMake(20, y, 335, 1))}]; y += 13; }
        NSUInteger cardIndex = blocks.count;
        CGFloat cardY = y; [blocks addObject:@{}]; y += 12;
        BOOL bilingual = (!options[@"bilingual"] || [options[@"bilingual"] boolValue]) && BHRDShareHasDistinctTranslation(post);
        if (post.body.length) {
            if (bilingual) { text(@"原文", 32, 311, 11, YES, 0.6); y += 6; }
            text(post.body, 32, 311, 14, NO, 0.92);
        } else if (!bilingual && !post.images.count) text(@"未读取到正文，可点击“编辑内容”补充。", 32, 311, 14, NO, 0.92);
        if (bilingual) {
            y += 12; text(@"译文", 32, 311, 11, YES, 0.6); y += 6;
            text(post.translatedBody, 32, 311, 14, NO, 0.92);
        }
        if (!post.quotedPost && post.quote.length) { y += 12; text(post.quote, 32, 311, 13, NO, 0.65); }
        for (NSURL *url in post.images) {
            NSData *data = images[url.absoluteString] ?: post.imageData[url.absoluteString];
            CGImageRef image = Decode(data);
            if (!image) continue;
            CGFloat h = image ? MIN(1200, 311.0 * CGImageGetHeight(image) / MAX(1, CGImageGetWidth(image))) : 96;
            if (image) CGImageRelease(image);
            y += 10;
            [blocks addObject:@{@"type": @"image", @"data": data ?: NSData.data, @"rect": BHRDRectValue(CGRectMake(32, y, 311, h))}]; y += h;
        }
        NSMutableArray *contexts = [NSMutableArray array];
        if (post.replyContextPost) [contexts addObject:@{@"post": post.replyContextPost, @"label": @"回复的原帖"}];
        BHRDSharePost *quoted = post.quotedPost;
        for (NSUInteger depth = 0; quoted && depth < 2; depth++, quoted = quoted.quotedPost)
            [contexts addObject:@{@"post": quoted, @"label": @"引用原文"}];
        if (post.replyContextPost.quotedPost) [contexts addObject:@{@"post": post.replyContextPost.quotedPost, @"label": @"原帖引用的内容"}];
        for (NSDictionary *context in contexts) {
            BHRDSharePost *quote = context[@"post"];
            y += 12;
            CGFloat quoteY = y; NSUInteger quoteIndex = blocks.count; [blocks addObject:@{}]; y += 12;
            text(context[@"label"], 44, 287, 11, YES, 0.6); y += 8;
            if ([options[@"author"] boolValue]) {
                [blocks addObject:@{@"type": @"avatar", @"data": images[quote.avatar.absoluteString ?: @""] ?: quote.avatarData ?: NSData.data, @"rect": BHRDRectValue(CGRectMake(44, y, 28, 28))}];
                NSString *name = quote.author ?: @"";
                NSAttributedString *author = Styled(name, 13, YES, ink, 0.85);
                CGFloat authorHeight = name.length ? TextHeight(author, 251) : 0;
                [blocks addObject:@{@"type": @"text", @"text": author, @"rect": BHRDRectValue(CGRectMake(80, y, 251, authorHeight))}];
                CGFloat totalHeight = authorHeight;
                if (quote.handle.length) {
                    NSAttributedString *handle = Styled([@"@" stringByAppendingString:quote.handle], 11, NO, ink, 0.6);
                    CGFloat handleHeight = TextHeight(handle, 251);
                    [blocks addObject:@{@"type": @"text", @"text": handle, @"rect": BHRDRectValue(CGRectMake(80, y + authorHeight + 2, 251, handleHeight))}]; totalHeight += handleHeight + 2;
                }
                y += MAX(28, totalHeight) + 10;
            }
            BOOL quoteBilingual = (!options[@"bilingual"] || [options[@"bilingual"] boolValue]) && BHRDShareHasDistinctTranslation(quote);
            if (quote.body.length) text(quote.body, 44, 287, 13, NO, 0.85);
            if (quoteBilingual) { y += 8; text(@"译文", 44, 287, 11, YES, 0.6); y += 4; text(quote.translatedBody, 44, 287, 13, NO, 0.85); }
            for (NSURL *url in quote.images) {
                NSData *data = images[url.absoluteString] ?: quote.imageData[url.absoluteString]; CGImageRef image = Decode(data);
                if (!image) continue;
                CGFloat h = image ? MIN(1200, 287.0 * CGImageGetHeight(image) / MAX(1, CGImageGetWidth(image))) : 96;
                if (image) CGImageRelease(image); y += 8;
                [blocks addObject:@{@"type": @"image", @"data": data ?: NSData.data, @"rect": BHRDRectValue(CGRectMake(44, y, 287, h))}]; y += h;
            }
            if ([options[@"link"] boolValue] && quote.link.length) { y += 8; text(quote.link, 44, 287, 10, NO, 0.6); }
            y += 12;
            blocks[quoteIndex] = @{@"type": @"quoteCard", @"rect": BHRDRectValue(CGRectMake(32, quoteY, 311, y - quoteY))};
        }
        y += 12;
        blocks[cardIndex] = @{@"type": @"card", @"rect": BHRDRectValue(CGRectMake(20, cardY, 335, y - cardY))}; any = YES;
    }
    if ([options[@"link"] boolValue]) {
        if (any) { y += 16; [blocks addObject:@{@"type": @"line", @"rect": BHRDRectValue(CGRectMake(20, y, 335, 1))}]; y += 13; }
        text(post.link.length ? post.link : @"原文链接未读取，可在编辑内容中补充", 20, 335, 11, NO, 0.6); any = YES;
    }
    if (!any) text(@"暂无显示内容", 20, 335, 14, NO, 0.7);
    CGFloat height = ceil(y + 20);
    if (height > 24000) {
        if (error) *error = [NSError errorWithDomain:@"XSuixinShare" code:1 userInfo:@{NSLocalizedDescriptionKey: @"内容过长，请缩短正文后再导出。"}];
        return nil;
    }
    CGFloat scale = MIN(3, MIN(16000 / height, sqrt(24000000 / (375 * height))));
    size_t pixelWidth = ceil(375 * scale), pixelHeight = ceil(height * scale);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, pixelWidth, pixelHeight, 8, 0, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (!ctx) { if (error) *error = [NSError errorWithDomain:@"XSuixinShare" code:2 userInfo:@{NSLocalizedDescriptionKey: @"生成图片失败，请缩短内容后重试。"}]; return nil; }
    CGContextTranslateCTM(ctx, 0, pixelHeight); CGContextScaleCTM(ctx, scale, -scale);
    Fill(ctx, CGRectMake(0, 0, 375, height), [theme[@"background"] unsignedIntegerValue], 1, 0);
    for (NSDictionary *block in blocks) {
        CGRect rect = Unrect(block[@"rect"]); NSString *type = block[@"type"];
        if ([type isEqual:@"text"]) DrawText(ctx, block[@"text"], rect);
        else if ([type isEqual:@"card"]) Fill(ctx, rect, [theme[@"card"] unsignedIntegerValue], 1, 8);
        else if ([type isEqual:@"quoteCard"]) Fill(ctx, rect, ink, 0.05, 8);
        else if ([type isEqual:@"line"]) Fill(ctx, rect, ink, 0.1, 0);
        else if ([type isEqual:@"logo"]) {
            DrawText(ctx, Styled(@"𝕏", 27, YES, ink, 1), CGRectMake(rect.origin.x, rect.origin.y - 3, 32, 36));
        } else {
            BOOL avatar = [type isEqual:@"avatar"];
            Fill(ctx, rect, ink, 0.06, avatar ? 18 : 6);
            CGImageRef image = Decode(block[@"data"]);
            if (image) {
                CGContextSaveGState(ctx);
                CGPathRef clip = CGPathCreateWithRoundedRect(rect, avatar ? 18 : 6, avatar ? 18 : 6, NULL);
                CGContextAddPath(ctx, clip); CGContextClip(ctx); CGPathRelease(clip);
                CGFloat ratio = avatar ? MAX(rect.size.width / CGImageGetWidth(image), rect.size.height / CGImageGetHeight(image)) : MIN(rect.size.width / CGImageGetWidth(image), rect.size.height / CGImageGetHeight(image));
                CGFloat w = CGImageGetWidth(image) * ratio, h = CGImageGetHeight(image) * ratio;
                CGRect target = CGRectMake(CGRectGetMidX(rect) - w / 2, CGRectGetMidY(rect) - h / 2, w, h);
                CGContextTranslateCTM(ctx, target.origin.x, target.origin.y + target.size.height); CGContextScaleCTM(ctx, 1, -1);
                CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), image); CGContextRestoreGState(ctx); CGImageRelease(image);
            }
        }
    }
    CGImageRef output = CGBitmapContextCreateImage(ctx); CGContextRelease(ctx);
    NSMutableData *png = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)png, CFSTR("public.png"), 1, NULL);
    BOOL success = NO;
    if (destination && output) { CGImageDestinationAddImage(destination, output, NULL); success = CGImageDestinationFinalize(destination); }
    if (output) CGImageRelease(output); if (destination) CFRelease(destination);
    return success ? png : nil;
}
