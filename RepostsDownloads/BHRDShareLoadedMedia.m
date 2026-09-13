#import "BHRDShareLoadedMedia.h"
#import "BHRDMediaResolver.h"
#import <math.h>
static NSString *ImageKey(NSURL *url) { return url.host.length ? [NSString stringWithFormat:@"%@%@", url.host.lowercaseString, url.path] : url.absoluteString; }
static NSData *Thumbnail(UIImage *image) {
    if (!image || image.size.width <= 0 || image.size.height <= 0) return nil;
    CGFloat pixelWidth = image.size.width * image.scale, pixelHeight = image.size.height * image.scale;
    CGFloat scale = MIN(1, 1600 / MAX(pixelWidth, pixelHeight));
    CGSize size = CGSizeMake(MAX(1, ceil(pixelWidth * scale)), MAX(1, ceil(pixelHeight * scale)));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat]; format.scale = 1; format.opaque = YES;
    UIImage *resized = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format] imageWithActions:^(UIGraphicsImageRendererContext *context) { [image drawInRect:CGRectMake(0, 0, size.width, size.height)]; }];
    return UIImagePNGRepresentation(resized);
}
void BHRDCaptureLoadedShareMedia(BHRDSharePost *post, UIView *card, NSArray<UIView *> *excluded) {
    if (!post || !card) return;
    NSMutableArray<UIView *> *pending = [card.subviews mutableCopy];
    NSMutableArray<NSDictionary *> *found = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    NSUInteger budget = 350;
    while (pending.count && budget--) {
        UIView *view = pending.firstObject; [pending removeObjectAtIndex:0];
        NSString *name = NSStringFromClass(view.class).lowercaseString;
        if ([excluded containsObject:view] || [name containsString:@"inlineactionsview"] || [name containsString:@"quote"]) continue;
        id model = BHRDMediaObject(view, @"viewModel"); NSString *identifier = BHRDMediaStatusIdentity(model);
        if (post.identifier.length && identifier.length && ![post.identifier isEqual:identifier] && [name containsString:@"embedded"]) continue;
        CGRect rect = [view convertRect:view.bounds toView:card];
        // 视频开始播放后封面可能隐藏，但其已加载 UIImage 仍属于当前卡片。
        if (rect.size.width >= 90 && rect.size.height >= 60) {
            UIImage *image = nil;
            for (NSString *key in @[@"image", @"previewImage", @"posterImage", @"thumbnailImage", @"cachedImage"]) {
                id value = BHRDMediaObject(view, key); if ([value isKindOfClass:UIImage.class]) { image = value; break; }
            }
            NSValue *identity = image ? [NSValue valueWithPointer:image.CGImage ?: (__bridge void *)image] : nil;
            if (image && ![seen containsObject:identity]) {
                [seen addObject:identity];
                id value = BHRDMediaObject(view, @"imageURL") ?: BHRDMediaObject(view, @"mediaURL") ?: BHRDMediaObject(view, @"URL") ?: BHRDMediaObject(BHRDMediaObject(model, @"mediaEntity"), @"mediaURL");
                NSURL *url = [value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
                NSMutableDictionary *candidate = [@{@"image": image, @"url": url ?: NSNull.null, @"x": @(rect.origin.x), @"y": @(rect.origin.y), @"rect": [NSValue valueWithCGRect:rect]} mutableCopy];
                BOOL duplicate = NO;
                for (NSUInteger index = 0; index < found.count; index++) {
                    NSDictionary *old = found[index]; CGRect oldRect = [old[@"rect"] CGRectValue];
                    BOOL sameRect = fabs(oldRect.origin.x - rect.origin.x) < 3 && fabs(oldRect.origin.y - rect.origin.y) < 3 && fabs(oldRect.size.width - rect.size.width) < 3 && fabs(oldRect.size.height - rect.size.height) < 3;
                    BOOL sameURL = !url || old[@"url"] == NSNull.null || [ImageKey(url) isEqual:ImageKey(old[@"url"])];
                    if (sameRect && sameURL) {
                        UIImage *previous = old[@"image"];
                        if (image.size.width * image.size.height > previous.size.width * previous.size.height) {
                            if (!url) candidate[@"url"] = old[@"url"]; found[index] = candidate;
                        }
                        duplicate = YES; break;
                    }
                }
                if (!duplicate) [found addObject:candidate];
            }
        }
        [pending addObjectsFromArray:view.subviews];
    }
    [found sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { NSComparisonResult y = [a[@"y"] compare:b[@"y"]]; return y == NSOrderedSame ? [a[@"x"] compare:b[@"x"]] : y; }];
    NSMutableDictionary *data = [post.imageData mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableArray *urls = [post.images mutableCopy] ?: [NSMutableArray array];
    NSString *localID = NSUUID.UUID.UUIDString;
    for (NSUInteger i = 0; i < MIN(found.count, 4); i++) {
        NSDictionary *item = found[i]; NSURL *target = nil;
        if (item[@"url"] != NSNull.null) for (NSURL *url in urls) if ([ImageKey(url) isEqual:ImageKey(item[@"url"])]) { target = url; break; }
        // 仅在数量吻合时按媒体的显示顺序配对，避免把别的图片塞进缺失项。
        if (!target && item[@"url"] == NSNull.null && found.count == post.images.count) target = post.images[i];
        if (!target && !post.images.count) {
            NSURL *known = item[@"url"] == NSNull.null ? nil : item[@"url"];
            target = [known.host.lowercaseString isEqual:@"pbs.twimg.com"] && [known.scheme isEqual:@"https"] ? known : [NSURL URLWithString:[NSString stringWithFormat:@"xsuixin-image://%@/%lu", localID, (unsigned long)i]]; [urls addObject:target];
        }
        if (target && !data[target.absoluteString]) {
            NSData *bytes = Thumbnail(item[@"image"]); if (bytes) data[target.absoluteString] = bytes;
        }
    }
    post.images = urls; post.imageData = data;
}
