#import "BHRDInlineLayout.h"
#import "BHRDLayoutGeometry.h"
#import "BHRDPreferences.h"
#import <objc/runtime.h>
static BOOL IsAction(UIView *view) {
    for (Class cls = view.class; cls; cls = class_getSuperclass(cls)) {
        NSString *name = NSStringFromClass(cls);
        if ([name isEqualToString:@"BHRDDownloadButton"] || [name isEqualToString:@"BHRDShareImageButton"] || ([name containsString:@"StatusInline"] && [name hasSuffix:@"Button"])) return YES;
    }
    return NO;
}
static BOOL applying;
static UIView *SharedContainer(NSArray<UIView *> *buttons, UIView *actions) {
    if (buttons.count == 1) return actions;
    UIView *parent = buttons.firstObject.superview;
    while (parent) {
        BOOL containsAll = YES;
        for (UIView *button in buttons) if (![button isDescendantOfView:parent]) containsAll = NO;
        if (containsAll) return parent;
        if (parent == actions) break;
        parent = parent.superview;
    }
    return nil;
}
void BHRDLayoutInlineActions(UIView *actionsView) {
    if (applying) return;
    NSMutableArray<UIView *> *buttons = [NSMutableArray array];
    NSMutableArray *pending = [actionsView.subviews mutableCopy];
    NSUInteger budget = 128;
    BOOL custom = NO;
    while (pending.count && budget--) {
        UIView *view = pending.firstObject; [pending removeObjectAtIndex:0];
        if (view.hidden || view.alpha <= 0.01) continue;
        if (IsAction(view)) {
            [buttons addObject:view];
            if ([NSStringFromClass(view.class) hasPrefix:@"BHRD"]) custom = YES;
        } else [pending addObjectsFromArray:view.subviews];
    }
    if (!buttons.count || (!custom && !BHRDHiddenInlineActionKeys().count)) return;
    UIView *container = SharedContainer(buttons, actionsView);
    if (!container || container.bounds.size.width <= 0) return;
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    NSMapTable<UIView *, NSNumber *> *ranks = [NSMapTable strongToStrongObjectsMapTable];
    for (UIView *button in buttons) {
        UIView *item = button;
        while (item.superview && item.superview != container) item = item.superview;
        // Never move a button out of a fixed-width wrapper.
        if ([items containsObject:item]) return;
        [items addObject:item];
        [ranks setObject:@(BHRDInlineActionOrder(NSStringFromClass(button.class))) forKey:item];
    }
    // Semantic order must not depend on previous frame positions or hash iteration.
    [items sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        NSInteger x = [[ranks objectForKey:a] integerValue], y = [[ranks objectForKey:b] integerValue];
        return x < y ? NSOrderedAscending : x > y ? NSOrderedDescending : NSOrderedSame;
    }];
    if (actionsView.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) items = [[[items reverseObjectEnumerator] allObjects] mutableCopy];
    NSMutableArray *widths = [NSMutableArray array];
    for (UIView *item in items) {
        if (item.bounds.size.width <= 0 || item.bounds.size.height <= 0) return;
        [widths addObject:@(item.frame.size.width)];
    }
    // Each row owns its geometry. Scrolling other cells into view cannot change it.
    applying = YES;
    @try {
        for (NSUInteger index = 0; index < items.count; index++) {
            UIView *item = items[index];
            item.frame = BHRDAlignedInlineActionFrame(container.bounds, item.frame, widths, index);
        }
    } @finally { applying = NO; }
}
