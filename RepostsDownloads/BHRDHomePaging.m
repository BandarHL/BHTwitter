#import "BHRDHomePaging.h"
#import "BHRDHomeHeader.h"
#import "BHRDPreferences.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <string.h>

static char BindingKey, ScrollKey, TabKey, IndicatorKey, WindowStatesKey;
@interface BHRDHomePageBinding : NSObject
@property(nonatomic, weak) UIView *strip;
@property(nonatomic, weak) UIView *first;
@property(nonatomic, weak) UIView *second;
@property(nonatomic, strong) NSMapTable<UIView *, NSValue *> *frames;
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *hidden;
@property(nonatomic, strong) NSMapTable<id, NSMutableDictionary *> *arrays;
@property(nonatomic, strong) NSMapTable<UIScrollView *, NSValue *> *sizes;
@property(nonatomic, strong) NSMapTable<UIScrollView *, NSNumber *> *bounces;
@property(nonatomic) BOOL active;
@property(nonatomic) BOOL applyingPages;
@end
@implementation BHRDHomePageBinding @end
static BOOL Active(BHRDHomePageBinding *binding) { return binding.active && BHRDPreference(BHRDHideHomeAddKey); }
static id Read(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    if (![object respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}
static NSString *Setter(NSString *getter) {
    return [NSString stringWithFormat:@"set%@%@:", [[getter substringToIndex:1] uppercaseString], [getter substringFromIndex:1]];
}
static BOOL HookOnce(Class cls, SEL selector) {
    static NSMutableSet *installed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ installed = [NSMutableSet set]; });
    NSString *key = [NSString stringWithFormat:@"%@/%@", NSStringFromClass(cls), NSStringFromSelector(selector)];
    if ([installed containsObject:key]) return NO;
    [installed addObject:key];
    return YES;
}
static BHRDHomeTabRole PageRole(id page) {
    for (NSString *key in @[@"scribePage", @"identifier", @"title", @"accessibilityLabel"]) {
        id value = Read(page, key);
        if (![value isKindOfClass:NSString.class]) continue;
        BHRDHomeTabRole role = BHRDHomeHeaderRole(value);
        if (role == BHRDHomeTabForYou || role == BHRDHomeTabFollowing) return role;
        if ([@[@"for_you", @"home_for_you"] containsObject:value]) return BHRDHomeTabForYou;
        if ([@[@"following", @"home_latest"] containsObject:value]) return BHRDHomeTabFollowing;
    }
    return BHRDHomeTabNone;
}
static NSArray *PrimaryPages(NSArray *pages, BHRDHomePageBinding *binding) {
    NSMutableArray *roles = [NSMutableArray array];
    for (id page in pages) [roles addObject:@(page == binding.first ? BHRDHomeTabForYou : page == binding.second ? BHRDHomeTabFollowing : PageRole(page))];
    return BHRDHomeSelectPrimaryPages(pages, roles);
}
static void HookArraySetter(id object, NSString *name) {
    SEL selector = NSSelectorFromString(Setter(name));
    NSMethodSignature *sig = [object methodSignatureForSelector:selector];
    if (!sig || sig.numberOfArguments != 3 || sig.methodReturnType[0] != 'v' || [sig getArgumentTypeAtIndex:2][0] != '@') return;
    Class cls = object_getClass(object);
    if (!HookOnce(cls, selector)) return;
    __block IMP original = NULL;
    IMP replacement = imp_implementationWithBlock(^(id target, NSArray *pages) {
        BHRDHomePageBinding *binding = objc_getAssociatedObject(target, &BindingKey);
        if (Active(binding) && [pages isKindOfClass:NSArray.class]) {
            NSMutableDictionary *saved = [binding.arrays objectForKey:target];
            if (!binding.applyingPages) saved[name] = pages;
            NSArray *primary = PrimaryPages(pages, binding);
            if (primary) pages = primary;
            else { binding.active = NO; [binding.strip.window setNeedsLayout]; }

        }
        ((void (*)(id, SEL, id))original)(target, selector, pages);
    });
    MSHookMessageEx(cls, selector, replacement, &original);
}
static void HookIndexSetter(id object, NSString *name) {
    SEL selector = NSSelectorFromString(Setter(name));
    NSMethodSignature *sig = [object methodSignatureForSelector:selector];
    if (!sig || sig.numberOfArguments != 3 || sig.methodReturnType[0] != 'v' || !strchr("qQlL", [sig getArgumentTypeAtIndex:2][0])) return;
    Class cls = object_getClass(object);
    if (HookOnce(cls, selector)) {
        __block IMP original = NULL;
        IMP replacement = imp_implementationWithBlock(^(id target, NSInteger index) {
            if (Active(objc_getAssociatedObject(target, &BindingKey))) index = BHRDHomeSelectedPage(index);
            ((void (*)(id, SEL, NSInteger))original)(target, selector, index);
        });
        MSHookMessageEx(cls, selector, replacement, &original);
    }
    NSMethodSignature *getter = [object methodSignatureForSelector:NSSelectorFromString(name)];
    if (getter.numberOfArguments == 2 && strchr("qQlL", getter.methodReturnType[0])) {
        NSInteger selected = ((NSInteger (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(name));
        if (selected > 1 || selected < 0) ((void (*)(id, SEL, NSInteger))objc_msgSend)(object, selector, BHRDHomeSelectedPage(selected));
    }
}
static void BindPageArrays(id target, BHRDHomePageBinding *binding, BOOL pager) {
    BOOL bound = NO;
    for (NSString *name in (pager ? @[@"viewControllers", @"pageViewControllers", @"pages", @"pageItems"] : @[@"tabViews", @"tabs", @"items"])) {
        NSArray *pages = Read(target, name);
        SEL setter = NSSelectorFromString(Setter(name));
        if (![pages isKindOfClass:NSArray.class] || pages.count < 2 || pages.count > 20 || ![target respondsToSelector:setter]) continue;
        // Pager binding is limited to a home controller discovered from the actual
        // two header tabs. Strip arrays must contain the real first/second views.
        NSArray *primary = PrimaryPages(pages, binding);
        if (!primary) continue;
        NSMutableDictionary *saved = [binding.arrays objectForKey:target];
        if (!saved) { saved = [NSMutableDictionary dictionary]; [binding.arrays setObject:saved forKey:target]; }
        if (!saved[name]) saved[name] = pages;
        bound = YES;
        objc_setAssociatedObject(target, &BindingKey, binding, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        HookArraySetter(target, name);
        if (![pages isEqual:primary]) {
            binding.applyingPages = YES;
            @try { ((void (*)(id, SEL, id))objc_msgSend)(target, setter, primary); }
            @finally { binding.applyingPages = NO; }
        }
    }
    if (pager && bound) {
        objc_setAssociatedObject(target, &BindingKey, binding, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (NSString *name in @[@"selectedIndex", @"selectedPageIndex", @"currentPageIndex"]) HookIndexSetter(target, name);
    }
}
BOOL BHRDHomePagingLimitScroll(UIScrollView *scroll) { return Active(objc_getAssociatedObject(scroll, &ScrollKey)); }
CGSize BHRDHomePagingContentSize(UIScrollView *scroll, CGSize proposed) {
    BHRDHomePageBinding *binding = objc_getAssociatedObject(scroll, &ScrollKey);
    if (!Active(binding)) return proposed;
    if (proposed.width > 2 * scroll.bounds.size.width) [binding.sizes setObject:[NSValue valueWithCGSize:proposed] forKey:scroll];
    proposed.width = MIN(proposed.width, 2 * scroll.bounds.size.width);
    return proposed;
}
CGPoint BHRDHomePagingOffset(UIScrollView *scroll, CGPoint proposed) {
    if (BHRDHomePagingLimitScroll(scroll)) proposed.x = MIN(MAX(0, proposed.x), BHRDHomeMaximumOffset(scroll.bounds.size.width, scroll.contentSize.width));
    return proposed;
}
CGRect BHRDHomePagingTabFrame(UIView *view, CGRect proposed) {
    BHRDHomePageBinding *binding = objc_getAssociatedObject(view, &TabKey);
    if (!binding) {
        binding = objc_getAssociatedObject(view, &IndicatorKey);
        if (!Active(binding) || !binding.strip) return proposed;
        CGRect first = [[binding.frames objectForKey:binding.first] CGRectValue];
        CGRect second = [[binding.frames objectForKey:binding.second] CGRectValue];
        CGFloat distance = CGRectGetMidX(second) - CGRectGetMidX(first);
        if (distance <= 0) return proposed;
        CGFloat progress = MAX(0, MIN(1, (CGRectGetMidX(proposed) - CGRectGetMidX(first)) / distance));
        CGFloat half = binding.strip.bounds.size.width / 2;
        proposed.origin.x = half * (0.5 + progress) - proposed.size.width / 2;
        return proposed;
    }
    if (!Active(binding) || !binding.strip) return proposed;
    NSUInteger index = view == binding.first ? 0 : 1;
    CGFloat width = binding.strip.bounds.size.width / 2;
    return CGRectMake(index * width, proposed.origin.y, width, proposed.size.height);
}
static UIView *Branch(UIView *view, UIView *ancestor) {
    while (view.superview && view.superview != ancestor) view = view.superview;
    return view;
}
static BOOL InContentCell(UIView *view) {
    for (UIView *p = view; p; p = p.superview) if ([p isKindOfClass:UITableViewCell.class] || [p isKindOfClass:UICollectionViewCell.class]) return YES;
    return NO;
}
static void Restore(BHRDHomePageBinding *binding) {
    binding.active = NO;
    for (UIView *view in binding.frames.keyEnumerator) {
        objc_setAssociatedObject(view, &TabKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &IndicatorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.frame = [[binding.frames objectForKey:view] CGRectValue];
    }
    for (UIView *view in binding.hidden.keyEnumerator) view.hidden = [[binding.hidden objectForKey:view] boolValue];
    for (id target in binding.arrays.keyEnumerator) {
        NSDictionary *saved = [binding.arrays objectForKey:target];
        for (NSString *name in saved) ((void (*)(id, SEL, id))objc_msgSend)(target, NSSelectorFromString(Setter(name)), saved[name]);
        objc_setAssociatedObject(target, &BindingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (UIScrollView *scroll in binding.sizes.keyEnumerator) {
        objc_setAssociatedObject(scroll, &ScrollKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        scroll.contentSize = [[binding.sizes objectForKey:scroll] CGSizeValue];
        scroll.bounces = [[binding.bounces objectForKey:scroll] boolValue];
    }
    [binding.frames removeAllObjects]; [binding.hidden removeAllObjects]; [binding.arrays removeAllObjects];
    [binding.sizes removeAllObjects]; [binding.bounces removeAllObjects];
}
void BHRDUpdateHomePaging(UIWindow *window, NSArray<NSDictionary *> *labels) {
    NSMapTable<UIView *, BHRDHomePageBinding *> *states = objc_getAssociatedObject(window, &WindowStatesKey);
    if (!BHRDPreference(BHRDHideHomeAddKey)) {
        for (BHRDHomePageBinding *binding in states.objectEnumerator) Restore(binding);
        [states removeAllObjects];
        return;
    }
    UIView *firstLabel = nil, *secondLabel = nil;
    for (NSDictionary *label in labels) {
        if (!BHRDHomeHeaderHasPrimaryTabs(labels, [label[@"y"] doubleValue])) continue;
        if (BHRDHomeHeaderRole(label[@"text"]) == BHRDHomeTabForYou) firstLabel = label[@"view"];
        if (BHRDHomeHeaderRole(label[@"text"]) == BHRDHomeTabFollowing) secondLabel = label[@"view"];
    }
    if (!firstLabel || !secondLabel) {
        for (BHRDHomePageBinding *old in states.objectEnumerator) if (!old.strip.window || !old.active) Restore(old);
        return;
    }
    UIView *strip = firstLabel.superview;
    while (strip && ![secondLabel isDescendantOfView:strip]) strip = strip.superview;
    if (!strip || strip == window || strip.bounds.size.height > 110) return;
    UIView *first = Branch(firstLabel, strip), *second = Branch(secondLabel, strip);
    if (first == second) return;
    if (!states) {
        states = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(window, &WindowStatesKey, states, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BHRDHomePageBinding *binding = [states objectForKey:strip];
    if (!binding) {
        binding = [BHRDHomePageBinding new]; binding.strip = strip; binding.first = first; binding.second = second;
        binding.frames = [NSMapTable weakToStrongObjectsMapTable]; binding.hidden = [NSMapTable weakToStrongObjectsMapTable];
        binding.arrays = [NSMapTable weakToStrongObjectsMapTable]; binding.sizes = [NSMapTable weakToStrongObjectsMapTable];
        binding.bounces = [NSMapTable weakToStrongObjectsMapTable];
        [states setObject:binding forKey:strip];
    }
    if (binding.first != first || binding.second != second) { Restore(binding); binding.first = first; binding.second = second; }
    UIViewController *home = nil;
    for (UIResponder *r = strip.nextResponder; r; r = r.nextResponder) {
        if ([r isKindOfClass:UIViewController.class]) {
            NSString *name = NSStringFromClass(r.class);
            if ([name containsString:@"HomeTimelineContainer"]) { home = (UIViewController *)r; break; }
            if (!home && ([name containsString:@"HomeTimeline"] || [name containsString:@"PagingViewController"])) home = (UIViewController *)r;
        }
    }
    if (!home) { Restore(binding); return; }
    NSMutableArray *controllers = [NSMutableArray arrayWithObject:home];
    BOOL verifiedPager = NO;
    for (NSUInteger i=0; i<controllers.count && i<24; i++) {
        UIViewController *controller = controllers[i];
        for (NSString *key in @[@"viewControllers", @"pageViewControllers", @"pages", @"pageItems"]) {
            id pages = Read(controller, key);
            if ([pages isKindOfClass:NSArray.class] && PrimaryPages(pages, binding) && [controller respondsToSelector:NSSelectorFromString(Setter(key))]) verifiedPager = YES;
        }
        [controllers addObjectsFromArray:controller.childViewControllers];
    }
    if (!verifiedPager) { Restore(binding); [states removeObjectForKey:strip]; return; }
    binding.active = YES;
    for (UIView *tab in @[first, second]) {
        if (![binding.frames objectForKey:tab]) [binding.frames setObject:[NSValue valueWithCGRect:tab.frame] forKey:tab];
        objc_setAssociatedObject(tab, &TabKey, binding, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tab.frame = BHRDHomePagingTabFrame(tab, tab.frame);
    }
    for (UIView *tab in strip.subviews) {
        if (tab == first || tab == second || tab.bounds.size.height < 20) continue;
        if (![binding.hidden objectForKey:tab]) [binding.hidden setObject:@(tab.hidden) forKey:tab];
        tab.hidden = YES;
    }
    for (UIView *line in strip.subviews) {
        CGRect frame = line.frame;
        if (line == first || line == second || [line isKindOfClass:UIControl.class] || [line isKindOfClass:UILabel.class] || [line isKindOfClass:UIImageView.class]) continue;
        if (frame.size.height < 2 || frame.size.height > 8 || frame.size.width < 20 || frame.size.width > strip.bounds.size.width * 0.6 || CGRectGetMaxY(frame) < strip.bounds.size.height - 8) continue;
        if (!objc_getAssociatedObject(line, &IndicatorKey)) {
            [binding.frames setObject:[NSValue valueWithCGRect:frame] forKey:line];
            objc_setAssociatedObject(line, &IndicatorKey, binding, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            line.frame = frame;
        }
    }
    BindPageArrays(strip, binding, NO);
    // Structural association avoids touching profile/media/DM pagers elsewhere.
    if (!home) return;
    for (NSUInteger index = 0; index < controllers.count && index < 24; index++) {
        UIViewController *controller = controllers[index];
        NSString *name = NSStringFromClass(controller.class);
        if ([name containsString:@"PagingViewController"] || [name containsString:@"HomeTimelineContainer"]) BindPageArrays(controller, binding, YES);
    }
    NSMutableArray *pending = [NSMutableArray arrayWithObject:home.view];
    NSUInteger budget = 600;
    while (pending.count && budget--) {
        UIView *view = pending.lastObject; [pending removeLastObject];
        if (InContentCell(view)) continue;
        if ([view isKindOfClass:UIScrollView.class]) {
            UIScrollView *scroll = (UIScrollView *)view;
            BOOL recycledPager = [NSStringFromClass(scroll.class) containsString:@"QueuingScrollView"];
            if (!recycledPager && scroll.bounds.size.width >= window.bounds.size.width * 0.85 && scroll.bounds.size.height > home.view.bounds.size.height * 0.45 && scroll.contentSize.width >= scroll.bounds.size.width * 2.5) {
                if (![binding.sizes objectForKey:scroll]) [binding.sizes setObject:[NSValue valueWithCGSize:scroll.contentSize] forKey:scroll];
                if (![binding.bounces objectForKey:scroll]) [binding.bounces setObject:@(scroll.bounces) forKey:scroll];
                objc_setAssociatedObject(scroll, &ScrollKey, binding, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                scroll.bounces = NO;
                scroll.contentSize = BHRDHomePagingContentSize(scroll, scroll.contentSize);
                [scroll setContentOffset:BHRDHomePagingOffset(scroll, scroll.contentOffset) animated:NO];
            }
        }
        [pending addObjectsFromArray:view.subviews];
    }
}
