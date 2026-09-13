#import "BHRDLayoutGeometry.h"
CGRect BHRDInlineActionFrame(CGRect columns, CGRect original, NSUInteger count, NSUInteger index) {
    if (!count || index >= count || columns.size.width <= 0 || original.size.width <= 0 || original.size.height <= 0) return original;
    CGFloat margin = MIN(12, columns.size.width * 0.05);
    CGFloat slot = (columns.size.width - 2 * margin) / count;
    if (original.size.width > slot) return original;
    // Width, height and Y are owned by X's layout, including detail-view controls
    // whose natural height extends beyond the action container's bounds.
    original.origin.x = columns.origin.x + margin + slot * (index + 0.5) - original.size.width / 2;
    return original;
}
CGRect BHRDFloatingDownloadFrame(CGRect bounds, double top, double left, double bottom, double right) {
    CGFloat width = MIN(104, MAX(0, bounds.size.width - left - right - 24));
    CGFloat height = MIN(44, MAX(0, bounds.size.height - top - bottom - 24));
    CGFloat x = bounds.origin.x + bounds.size.width - right - 16 - width;
    CGFloat y = bounds.origin.y + bounds.size.height * 0.65 - height / 2;
    x = MAX(bounds.origin.x + left + 12, x);
    y = MAX(bounds.origin.y + top + 12, MIN(y, CGRectGetMaxY(bounds) - bottom - 12 - height));
    return CGRectMake(x, y, width, height);
}
CGRect BHRDAlignedInlineActionFrame(CGRect columns, CGRect original, NSArray<NSNumber *> *minimumWidths, NSUInteger index) {
    NSUInteger count = minimumWidths.count;
    if (!count || index >= count || original.size.width <= 0 || original.size.height <= 0) return original;
    CGFloat margin = MIN(12, columns.size.width * 0.05);
    CGFloat available = columns.size.width - 2 * margin;
    CGFloat largest = 0, required = 0;
    for (NSNumber *width in minimumWidths) { required += width.doubleValue; largest = MAX(largest, width.doubleValue); }
    if (available <= 0 || required > available) return original;
    if (largest * count <= available) return BHRDInlineActionFrame(columns, original, count, index);
    // Where equal columns cannot hold the native content, all rows use the same
    // per-column minimum widths instead. Neither labels nor hit regions overlap.
    CGFloat extra = (available - required) / count;
    CGFloat left = columns.origin.x + margin;
    for (NSUInteger i = 0; i < index; i++) left += minimumWidths[i].doubleValue + extra;
    original.origin.x = left + (minimumWidths[index].doubleValue + extra - original.size.width) / 2;
    return original;
}
BOOL BHRDAddedActionGroupStart(CGRect bounds, CGRect nativeExtent, NSArray<NSNumber *> *widths, BOOL leading, CGFloat *start) {
    if (!widths.count || bounds.size.width <= 0) return NO;
    CGFloat total = 12 * (widths.count - 1);
    for (NSNumber *width in widths) { if (width.doubleValue <= 0) return NO; total += width.doubleValue; }
    CGFloat margin = MIN(8, bounds.size.width * 0.02);
    CGFloat x = leading ? CGRectGetMinX(bounds) + margin : CGRectGetMaxX(bounds) - margin - total;
    if (x < CGRectGetMinX(bounds) + margin || x + total > CGRectGetMaxX(bounds) - margin) return NO;
    if (leading ? x + total + 12 > CGRectGetMinX(nativeExtent) : x < CGRectGetMaxX(nativeExtent) + 12) return NO;
    if (start) *start = x;
    return YES;
}
CGRect BHRDMatchedInlineGlyphFrame(CGRect bounds, CGFloat centerY, CGSize nativeSize) {
    CGSize size = CGSizeMake(MAX(16, MIN(28, nativeSize.width)), MAX(16, MIN(28, nativeSize.height)));
    return CGRectMake(CGRectGetMidX(bounds) - size.width / 2, centerY - size.height / 2, size.width, size.height);
}

NSInteger BHRDInlineActionOrder(NSString *name) {
    if ([name isEqual:@"BHRDDownloadButton"]) return 80;
    if ([name isEqual:@"BHRDShareImageButton"]) return 90;
    NSArray *suffixes = @[@"ReplyButton", @"RetweetButton", @"RepostButton", @"FavoriteButton", @"LikeButton", @"AnalyticsButton", @"ViewCountButton", @"BookmarkButton", @"ShareButton"];
    NSArray *orders = @[@10, @20, @20, @30, @30, @40, @40, @50, @60];
    for (NSUInteger i = 0; i < suffixes.count; i++) if ([name hasSuffix:suffixes[i]]) return [orders[i] integerValue];
    return 70;
}
