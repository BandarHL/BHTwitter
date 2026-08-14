#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "BHTManager.h"
#import "BHTBundle/BHTBundle.h"

static const NSInteger BHTProfileCopyButtonTag = 1216001;
static IMP BHTOriginalProfileHeaderLayoutIMP = NULL;
typedef void (*BHTLayoutIMP)(id, SEL);

static BOOL BHTLegacyCopyProfileInfoDisabled(id self, SEL _cmd) { return NO; }
static BOOL BHTX1216CopyProfileInfoEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"CopyProfileInfo"];
}

static void BHTDisableLegacyProfileCopyHook(void) {
    Class managerClass = NSClassFromString(@"BHTManager");
    SEL selector = NSSelectorFromString(@"CopyProfileInfo");
    Method method = managerClass ? class_getClassMethod(managerClass, selector) : NULL;
    if (!method) return;
    Class metaClass = object_getClass(managerClass);
    class_replaceMethod(metaClass, selector, (IMP)BHTLegacyCopyProfileInfoDisabled, method_getTypeEncoding(method));
}

static UIViewController *BHTProfileHeaderControllerFromView(UIView *view) {
    UIResponder *responder = view;
    Class cls = NSClassFromString(@"T1ProfileHeaderViewController");
    while (responder) {
        if (cls && [responder isKindOfClass:cls]) return (UIViewController *)responder;
        responder = responder.nextResponder;
    }
    return nil;
}

static void BHTShowProfileCopyMenu(UIViewController *controller, id viewModel, UIView *sourceView) {
    if (!controller || !viewModel || !controller.view.window) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"プロフィール情報をコピー"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSDictionary *> *items = @[
        @{ @"selector": @"bio", @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_1"] ?: @"自己紹介" },
        @{ @"selector": @"username", @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_2"] ?: @"ユーザー名" },
        @{ @"selector": @"fullName", @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_3"] ?: @"表示名" },
        @{ @"selector": @"url", @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_4"] ?: @"URL" },
        @{ @"selector": @"location", @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_MENU_OPTION_5"] ?: @"場所" },
    ];

    for (NSDictionary *item in items) {
        SEL selector = NSSelectorFromString(item[@"selector"]);
        if (![viewModel respondsToSelector:selector]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(viewModel, selector);
        if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] == 0) continue;

        [alert addAction:[UIAlertAction actionWithTitle:item[@"title"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            UIPasteboard.generalPasteboard.string = value;
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"キャンセル"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = sourceView ?: controller.view;
        popover.sourceRect = sourceView ? sourceView.bounds : controller.view.bounds;
    }

    if (!controller.presentedViewController) {
        [controller presentViewController:alert animated:YES completion:nil];
    }
}

@interface BHTProfileCopyTarget : NSObject
@end

@implementation BHTProfileCopyTarget

+ (instancetype)sharedTarget {
    static BHTProfileCopyTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ target = [BHTProfileCopyTarget new]; });
    return target;
}

- (void)bht_profileCopyTapped:(UIButton *)sender {
    UIViewController *controller = BHTProfileHeaderControllerFromView(sender);
    if (!controller || !controller.view.window) return;

    SEL selector = NSSelectorFromString(@"viewModel");
    id viewModel = nil;
    if ([controller respondsToSelector:selector]) {
        viewModel = ((id (*)(id, SEL))objc_msgSend)(controller, selector);
    }
    if (!viewModel) return;

    BHTShowProfileCopyMenu(controller, viewModel, sender);
}

@end

static UIButton *BHTEnsureCopyButton(UIView *headerView) {
    UIButton *button = (UIButton *)[headerView viewWithTag:BHTProfileCopyButtonTag];
    if (button) return button;

    button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = BHTProfileCopyButtonTag;
    button.tintColor = UIColor.labelColor;
    button.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.92];
    button.layer.cornerRadius = 18.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.7].CGColor;
    [button setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
    button.accessibilityLabel = @"プロフィール情報をコピー";
    [button addTarget:[BHTProfileCopyTarget sharedTarget]
               action:@selector(bht_profileCopyTapped:)
     forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:button];
    return button;
}

// Find the small action controls in the lower part of the profile header.
// Instead of depending on a private X class name or a "share" accessibility
// label, use the real button row that is already visible. The copy button is
// placed immediately to the left of the left-most small control in that row.
static UIView *BHTFindLeftmostProfileActionControl(UIView *root) {
    if (!root || CGRectGetWidth(root.bounds) <= 0.0 || CGRectGetHeight(root.bounds) <= 0.0) return nil;

    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    CGFloat rootHeight = CGRectGetHeight(root.bounds);

    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];

        if (view != root &&
            view.tag != BHTProfileCopyButtonTag &&
            !view.hidden &&
            view.alpha > 0.05 &&
            view.superview) {

            BOOL isControl = [view isKindOfClass:[UIControl class]];
            NSString *className = NSStringFromClass(view.class).lowercaseString ?: @"";
            BOOL looksLikeButton = isControl || [className containsString:@"button"] || [className containsString:@"control"];

            if (looksLikeButton) {
                CGRect frame = [view.superview convertRect:view.frame toView:root];
                CGFloat width = CGRectGetWidth(frame);
                CGFloat height = CGRectGetHeight(frame);
                CGFloat midY = CGRectGetMidY(frame);

                BOOL smallActionSize = width >= 28.0 && width <= 64.0 && height >= 28.0 && height <= 64.0;
                BOOL lowerHeader = midY >= MAX(105.0, rootHeight * 0.42) && midY <= rootHeight - 4.0;

                if (smallActionSize && lowerHeader) {
                    [candidates addObject:@{ @"view": view,
                                             @"frame": [NSValue valueWithCGRect:frame] }];
                }
            }
        }

        [stack addObjectsFromArray:view.subviews];
    }

    if (candidates.count == 0) return nil;

    // The visible profile action row is normally the lowest group of small
    // controls. Find its Y position first, then select its left-most member.
    CGFloat lowestMidY = -CGFLOAT_MAX;
    for (NSDictionary *candidate in candidates) {
        CGRect frame = [candidate[@"frame"] CGRectValue];
        lowestMidY = MAX(lowestMidY, CGRectGetMidY(frame));
    }

    UIView *best = nil;
    CGFloat bestX = CGFLOAT_MAX;
    for (NSDictionary *candidate in candidates) {
        CGRect frame = [candidate[@"frame"] CGRectValue];
        if (fabs(CGRectGetMidY(frame) - lowestMidY) > 28.0) continue;
        if (CGRectGetMinX(frame) < bestX) {
            bestX = CGRectGetMinX(frame);
            best = candidate[@"view"];
        }
    }

    return best;
}

static void BHTProfileHeaderLayoutSubviews(id self, SEL _cmd) {
    if (BHTOriginalProfileHeaderLayoutIMP) {
        ((BHTLayoutIMP)BHTOriginalProfileHeaderLayoutIMP)(self, _cmd);
    }

    if (![self isKindOfClass:[UIView class]]) return;
    UIView *headerView = (UIView *)self;
    UIButton *button = (UIButton *)[headerView viewWithTag:BHTProfileCopyButtonTag];

    if (!BHTX1216CopyProfileInfoEnabled()) {
        [button removeFromSuperview];
        return;
    }

    CGFloat headerWidth = CGRectGetWidth(headerView.bounds);
    CGFloat headerHeight = CGRectGetHeight(headerView.bounds);

    // The compact/collapsed profile header should not retain our floating
    // button. It will be recreated automatically when the full header returns.
    if (headerWidth < 100.0 || headerHeight < 125.0) {
        [button removeFromSuperview];
        return;
    }

    if (!button) button = BHTEnsureCopyButton(headerView);
    if (!button) return;

    const CGFloat size = 36.0;
    const CGFloat gap = 8.0;
    UIView *anchor = BHTFindLeftmostProfileActionControl(headerView);
    CGRect targetFrame = CGRectZero;

    if (anchor && anchor.superview) {
        CGRect anchorFrame = [anchor.superview convertRect:anchor.frame toView:headerView];
        targetFrame = CGRectMake(CGRectGetMinX(anchorFrame) - gap - size,
                                 CGRectGetMidY(anchorFrame) - size * 0.5,
                                 size,
                                 size);
    } else {
        // Fallback for layouts whose action controls are Swift wrappers rather
        // than UIControls. Keep it in the lower-right action area but far enough
        // left to avoid the Follow/Notification controls.
        targetFrame = CGRectMake(MAX(8.0, headerWidth - 188.0),
                                 MAX(8.0, headerHeight - 54.0),
                                 size,
                                 size);
    }

    targetFrame.origin.x = MAX(8.0, MIN(targetFrame.origin.x, MAX(8.0, headerWidth - size - 8.0)));
    targetFrame.origin.y = MAX(8.0, MIN(targetFrame.origin.y, MAX(8.0, headerHeight - size - 8.0)));

    button.frame = CGRectIntegral(targetFrame);
    button.hidden = NO;
    button.alpha = 1.0;
    button.userInteractionEnabled = YES;
    [headerView bringSubviewToFront:button];
}

static void BHTInstallX1216ProfileCompat(void) {
    Class cls = NSClassFromString(@"T1ProfileHeaderView");
    SEL selector = @selector(layoutSubviews);
    Method inheritedMethod = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!cls || !inheritedMethod) return;

    const char *types = method_getTypeEncoding(inheritedMethod);
    IMP replacement = (IMP)BHTProfileHeaderLayoutSubviews;
    BHTOriginalProfileHeaderLayoutIMP = method_getImplementation(inheritedMethod);

    if (class_addMethod(cls, selector, replacement, types)) return;

    Method ownMethod = class_getInstanceMethod(cls, selector);
    if (!ownMethod) return;

    BHTOriginalProfileHeaderLayoutIMP = method_getImplementation(ownMethod);
    method_setImplementation(ownMethod, replacement);
}

__attribute__((constructor)) static void BHTX1216ProfileCompatInit(void) {
    BHTDisableLegacyProfileCopyHook();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BHTInstallX1216ProfileCompat();
    });
}
