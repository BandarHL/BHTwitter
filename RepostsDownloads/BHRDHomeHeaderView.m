#import "BHRDHomeHeaderView.h"
#import "BHRDHomeHeader.h"
#import "BHRDHomePaging.h"
#import "BHRDPreferences.h"
#import <objc/runtime.h>

static char BHRDHomePendingKey, BHRDHomeScanTimeKey;
static BOOL InsideCell(UIView *view) {
    for (UIView *parent = view; parent; parent = parent.superview) {
        if ([parent isKindOfClass:UITableViewCell.class]) return YES;
        if ([parent isKindOfClass:UICollectionViewCell.class] && parent.bounds.size.height > 100) return YES;
    }
    return NO;
}
static void Apply(UIWindow *window) {
    if (!BHRDPreference(BHRDHideHomeAddKey)) {
        BHRDUpdateHomePaging(window, nil);
        return;
    }
    NSMutableArray<NSDictionary *> *labels = [NSMutableArray array];
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithArray:window.subviews];
    NSUInteger budget = 1800, examined=0, cellExcluded=0, visibilityExcluded=0, regionExcluded=0;
    CGFloat topLimit = MIN(300, window.bounds.size.height * 0.45);
    while (pending.count && budget--) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        examined++;
        if (view.hidden || view.alpha <= 0.01) { visibilityExcluded++; continue; }
        if (InsideCell(view)) { cellExcluded++; continue; }
        CGRect rect = [view convertRect:view.bounds toView:window];
        // Ignore the content feed, dialogs below the header, and off-screen tabs.
        if (CGRectGetMinY(rect) > topLimit || CGRectGetMaxY(rect) < 0) { regionExcluded++; continue; }
        NSString *text = BHRDHomeHeaderViewText(view);
        BHRDHomeTabRole role = BHRDHomeHeaderRole(text);
        // Newer hosts expose the image-only Add button through accessibility,
        // while the two primary tabs still supply their visible UILabels.
        if ((role != BHRDHomeTabNone || BHRDHomeHeaderIsAddCandidate(view)) && CGRectGetMidY(rect) > window.safeAreaInsets.top && CGRectGetMidY(rect) < topLimit) {
            [labels addObject:@{@"text": text, @"y": @(CGRectGetMidY(rect)), @"view": view}];
        }
        [pending addObjectsFromArray:view.subviews];
    }
    BHRDHomeRecordStatus(window,@"home_header_scan",@{@"examinedViewCount":@(examined),@"cellExcludedCount":@(cellExcluded),@"visibilityExcludedCount":@(visibilityExcluded),@"regionExcludedCount":@(regionExcluded),@"candidateCount":@(labels.count),@"scanTruncated":@(pending.count>0)});
    if (pending.count) return; // Partial scans cannot authorize hiding controls.
    BHRDUpdateHomePaging(window, labels);
}
void BHRDScheduleHomeHeaderUpdate(UIWindow *window) {
    if (!window || [objc_getAssociatedObject(window, &BHRDHomePendingKey) boolValue]) return;
    NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
    if (now - [objc_getAssociatedObject(window, &BHRDHomeScanTimeKey) doubleValue] < 0.25) return;
    objc_setAssociatedObject(window, &BHRDHomePendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIWindow *weakWindow = window;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *current = weakWindow;
        if (!current) return;
        objc_setAssociatedObject(current, &BHRDHomeScanTimeKey, @(NSDate.timeIntervalSinceReferenceDate), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        Apply(current);
        objc_setAssociatedObject(current, &BHRDHomePendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}
