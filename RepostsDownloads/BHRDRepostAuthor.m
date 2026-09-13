#import "BHRDRepostAuthor.h"
#import "BHRDMediaResolver.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static BOOL Excluded(NSString *name) {
    for (NSString *word in @[@"quote", @"socialcontext", @"repostcontext", @"retweetcontext", @"inlineactions", @"tweettext", @"statustext", @"richtext", @"attachment", @"mediagrid", @"cardpreview"]) {
        if ([name containsString:word]) return YES;
    }
    return NO;
}
UIImage *BHRDCaptureRepostAuthor(UIView *cell, UIView *excludedOverlay, NSMapTable *hiddenViews, BHRDRepostInfo *info) {
    NSMutableArray *pending = [NSMutableArray arrayWithArray:cell.subviews];
    NSMutableArray *rows = [NSMutableArray array], *avatars = [NSMutableArray array];
    NSUInteger budget = 250;
    while (pending.count && budget--) {
        UIView *view = pending.firstObject; [pending removeObjectAtIndex:0];
        if (view == excludedOverlay) continue;
        NSNumber *originalHidden = [hiddenViews objectForKey:view];
        if ((originalHidden ? originalHidden.boolValue : view.hidden) || view.alpha <= 0.01) continue;
        NSString *className = NSStringFromClass(view.class).lowercaseString;
        if (Excluded(className)) continue;
        BOOL semantic = NO, avatarContext = NO;
        for (UIView *p = view; p && p != cell; p = p.superview) {
            NSString *name = NSStringFromClass(p.class).lowercaseString;
            if ([name containsString:@"username"] || [name containsString:@"author"] || [name containsString:@"screenname"]) semantic = YES;
            if ([name containsString:@"avatar"] || [name containsString:@"profileimage"]) avatarContext = YES;
        }
        CGRect rect = [view convertRect:view.bounds toView:cell];
        // A header is above the body; exclude images from the media grid even
        // when the private classes no longer carry recognizable names.
        BOOL top = rect.origin.y >= 0 && rect.origin.y <= 110;
        NSString *text = BHRDRepostHeaderText(view);
        if (top && text.length && rect.origin.x >= 35 && (semantic || rect.origin.y <= 65)) {
            [rows addObject:@{@"text": text, @"x": @(rect.origin.x), @"y": @(rect.origin.y), @"semantic": @(semantic)}];
        }
        // The author control can expose the complete name/handle as one AX
        // label while its visible children are separately drawn or truncated.
        // Keep this explicitly scoped metadata separate from ordinary text.
        NSString *accessible = semantic ? view.accessibilityLabel : nil;
        if (top && semantic && rect.origin.x >= 35 && [accessible containsString:@"@"] && ![accessible isEqual:text]) {
            [rows addObject:@{@"text": accessible, @"x": @(rect.origin.x), @"y": @(rect.origin.y), @"semantic": @YES, @"accessibility": @YES}];
        }
        BOOL square = rect.size.width >= 24 && rect.size.width <= 90 && fabs(rect.size.width - rect.size.height) < 8;
        if (top && rect.origin.x < 85 && square) {
            id image = BHRDMediaObject(view, @"image");
            if (![image isKindOfClass:UIImage.class]) image = nil;
            if (!image && avatarContext) {
                id contents = view.layer.contents;
                if (contents && CFGetTypeID((__bridge CFTypeRef)contents) == CGImageGetTypeID()) image = [UIImage imageWithCGImage:(__bridge CGImageRef)contents];
            }
            NSURL *url = nil;
            for (NSString *key in @[@"profileImageURL", @"imageURL", @"URL", @"url"]) {
                NSURL *candidate = BHRDSafeThumbnailURL(BHRDMediaObject(view, key));
                if ([candidate.path containsString:@"/profile_images/"]) { url = candidate; break; }
            }
            if (image || url) [avatars addObject:@{@"image": image ?: NSNull.null, @"url": url ?: NSNull.null, @"y": @(rect.origin.y), @"semantic": @(avatarContext), @"area": @(rect.size.width * rect.size.height)}];
        }
        [pending addObjectsFromArray:view.subviews];
    }
    // Generic labels need an adjacent header avatar as an anchor. Otherwise a
    // short body consisting only of an @mention could look like a username.
    NSIndexSet *unanchored = [rows indexesOfObjectsPassingTest:^BOOL(NSDictionary *row, NSUInteger index, BOOL *stop) {
        (void)index; (void)stop;
        if ([row[@"semantic"] boolValue]) return NO;
        for (NSDictionary *avatar in avatars) {
            double dy = [row[@"y"] doubleValue] - [avatar[@"y"] doubleValue];
            if (dy >= -8 && dy <= 24) return NO;
        }
        return YES;
    }];
    [rows removeObjectsAtIndexes:unanchored];
#ifdef BHRD_DIAGNOSTICS
    NSLog(@"[XSuixinDiag] AUTH cell=%@ rows=%lu avatars=%lu", NSStringFromClass(cell.class), (unsigned long)rows.count, (unsigned long)avatars.count);
    for (NSDictionary *row in rows) NSLog(@"[XSuixinDiag] AUTHRow text=[%@] x=%.1f y=%.1f semantic=%d", row[@"text"], [row[@"x"] doubleValue], [row[@"y"] doubleValue], [row[@"semantic"] boolValue]);
#endif
    NSDictionary *author = BHRDSelectRepostAuthor(rows, info.authorHandle);
#ifdef BHRD_DIAGNOSTICS
    NSLog(@"[XSuixinDiag] AUTHPick name=[%@] handle=[%@]", author[@"name"], author[@"handle"]);
#endif
    if (!author) return nil; // No verified header: do not borrow a body mention's image.
    if (!info.authorHandle.length) info.authorHandle = author[@"handle"];
    if (!info.authorName.length) info.authorName = author[@"name"];
    info.author = info.authorName.length ? [NSString stringWithFormat:@"%@ · @%@", info.authorName, info.authorHandle] : [@"@" stringByAppendingString:info.authorHandle];
    [avatars sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        if ([a[@"semantic"] boolValue] != [b[@"semantic"] boolValue]) return [a[@"semantic"] boolValue] ? NSOrderedAscending : NSOrderedDescending;
        return [b[@"area"] compare:a[@"area"]];
    }];
    for (NSDictionary *avatar in avatars) {
        if (fabs([avatar[@"y"] doubleValue] - [author[@"y"] doubleValue]) > 40) continue;
        if (!info.avatar && avatar[@"url"] != NSNull.null) info.avatar = avatar[@"url"];
        if (avatar[@"image"] != NSNull.null) return avatar[@"image"];
    }
    return nil;
}
