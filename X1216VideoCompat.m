#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "BHTManager.h"
#import "BHDownloadInlineButton.h"

static const NSInteger BHTVideoDownloadButtonTag = 1216099;
static const void *BHTVideoItemKey = &BHTVideoItemKey;
static const void *BHTActiveDownloaderKey = &BHTActiveDownloaderKey;
static const void *BHTActiveDownloadProxyKey = &BHTActiveDownloadProxyKey;
static IMP BHTOriginalTableCellForItemIMP = NULL;

typedef UITableViewCell *(*BHTTableCellForItemIMP)(id, SEL, id, id);

static BOOL BHTRuntimeItemIsVideo(id item) {
    if (!item) return NO;

    SEL videoSEL = NSSelectorFromString(@"isMediaEntityVideo");
    if ([item respondsToSelector:videoSEL] && ((BOOL (*)(id, SEL))objc_msgSend)(item, videoSEL)) return YES;

    SEL gifSEL = NSSelectorFromString(@"isGIF");
    if ([item respondsToSelector:gifSEL] && ((BOOL (*)(id, SEL))objc_msgSend)(item, gifSEL)) return YES;

    SEL representedSEL = NSSelectorFromString(@"representedMediaEntities");
    if ([item respondsToSelector:representedSEL]) {
        id entities = ((id (*)(id, SEL))objc_msgSend)(item, representedSEL);
        if ([entities isKindOfClass:[NSArray class]]) {
            for (id media in (NSArray *)entities) {
                SEL mediaTypeSEL = NSSelectorFromString(@"mediaType");
                if ([media respondsToSelector:mediaTypeSEL]) {
                    NSInteger mediaType = ((NSInteger (*)(id, SEL))objc_msgSend)(media, mediaTypeSEL);
                    if (mediaType == 2 || mediaType == 3) return YES;
                }
                SEL videoInfoSEL = NSSelectorFromString(@"videoInfo");
                if ([media respondsToSelector:videoInfoSEL] && ((id (*)(id, SEL))objc_msgSend)(media, videoInfoSEL)) return YES;
            }
        }
    }

    SEL tweetSEL = NSSelectorFromString(@"tweet");
    if ([item respondsToSelector:tweetSEL]) {
        id tweet = ((id (*)(id, SEL))objc_msgSend)(item, tweetSEL);
        if (tweet && tweet != item && BHTRuntimeItemIsVideo(tweet)) return YES;
    }

    return NO;
}

static UIView *BHTFindActionsView(UIView *root) {
    if (!root) return nil;

    Class ttaClass = NSClassFromString(@"TTAStatusInlineActionsView");
    Class t1Class = NSClassFromString(@"T1StatusInlineActionsView");

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];

        if ((ttaClass && [view isKindOfClass:ttaClass]) ||
            (t1Class && [view isKindOfClass:t1Class])) {
            return view;
        }

        [stack addObjectsFromArray:view.subviews];
    }

    return nil;
}

static id BHTVideoViewModelForCell(UITableViewCell *cell) {
    if (!cell) return nil;

    UIView *actionsView = BHTFindActionsView(cell);
    SEL viewModelSEL = NSSelectorFromString(@"viewModel");
    if (actionsView && [actionsView respondsToSelector:viewModelSEL]) {
        id viewModel = ((id (*)(id, SEL))objc_msgSend)(actionsView, viewModelSEL);
        if (viewModel && BHTRuntimeItemIsVideo(viewModel)) return viewModel;
    }

    id fallback = objc_getAssociatedObject(cell, BHTVideoItemKey);
    if (fallback && BHTRuntimeItemIsVideo(fallback)) return fallback;

    return nil;
}

// BHDownloadInlineButton's legacy DownloadHandler expects delegate.viewModel and
// delegate.delegate. X 12.16's dedicated button is not an inline-action child,
// so provide exactly that interface without depending on the old view hierarchy.
@interface BHTDownloadDelegateProxy : NSObject
@property (nonatomic, strong) id viewModel;
@property (nonatomic, weak) id delegate;
@end

@implementation BHTDownloadDelegateProxy
@end

@interface BHTVideoDownloadTarget : NSObject
@end

@implementation BHTVideoDownloadTarget

+ (instancetype)sharedTarget {
    static BHTVideoDownloadTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ target = [BHTVideoDownloadTarget new]; });
    return target;
}

- (void)bht_downloadVideoTapped:(UIButton *)sender {
    UITableViewCell *cell = nil;
    UIResponder *responder = sender;
    while (responder) {
        if ([responder isKindOfClass:[UITableViewCell class]]) {
            cell = (UITableViewCell *)responder;
            break;
        }
        responder = responder.nextResponder;
    }
    if (!cell) return;

    UIView *actionsView = BHTFindActionsView(cell);
    id viewModel = nil;

    SEL viewModelSEL = NSSelectorFromString(@"viewModel");
    if (actionsView && [actionsView respondsToSelector:viewModelSEL]) {
        id liveModel = ((id (*)(id, SEL))objc_msgSend)(actionsView, viewModelSEL);
        if (liveModel && BHTRuntimeItemIsVideo(liveModel)) {
            viewModel = liveModel;
        }
    }

    if (!viewModel) viewModel = BHTVideoViewModelForCell(cell);
    if (!viewModel) return;

    BHTDownloadDelegateProxy *proxy = [BHTDownloadDelegateProxy new];
    proxy.viewModel = viewModel;
    proxy.delegate = nil;

    BHDownloadInlineButton *downloadButton = [[BHDownloadInlineButton alloc] initWithFrame:CGRectZero];
    downloadButton.delegate = (id)proxy;
    downloadButton.viewModel = viewModel;

    // Both properties above are weak/temporary in the legacy inline-action path.
    // Keep the bridge and downloader alive until the menu/download flow finishes.
    objc_setAssociatedObject(sender,
                             BHTActiveDownloadProxyKey,
                             proxy,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(sender,
                             BHTActiveDownloaderKey,
                             downloadButton,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    dispatch_async(dispatch_get_main_queue(), ^{
        [downloadButton DownloadHandler:sender];
    });
}

@end

static void BHTApplyVideoButtonToCell(UITableViewCell *cell) {
    if (!cell) return;

    UIView *host = cell.contentView ?: cell;
    UIButton *button = (UIButton *)[host viewWithTag:BHTVideoDownloadButtonTag];
    id viewModel = BHTVideoViewModelForCell(cell);

    if (!viewModel) {
        [button removeFromSuperview];
        return;
    }

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = BHTVideoDownloadButtonTag;
        button.backgroundColor = UIColor.clearColor;
        button.tintColor = UIColor.secondaryLabelColor;
        button.accessibilityLabel = @"動画をダウンロード";

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightRegular];
        UIImage *image = [UIImage systemImageNamed:@"arrow.down.to.line" withConfiguration:config];
        if (!image) image = [UIImage systemImageNamed:@"arrow.down" withConfiguration:config];
        [button setImage:image forState:UIControlStateNormal];

        [button addTarget:[BHTVideoDownloadTarget sharedTarget]
                   action:@selector(bht_downloadVideoTapped:)
         forControlEvents:UIControlEventTouchUpInside];
        [host addSubview:button];
    }

    const CGFloat size = 30.0;
    const CGFloat rightInset = 28.0;
    const CGFloat bottomInset = 12.0;
    CGFloat width = CGRectGetWidth(host.bounds);
    CGFloat height = CGRectGetHeight(host.bounds);

    CGFloat x = MAX(8.0, width - rightInset - size);
    CGFloat y = MAX(8.0, height - bottomInset - size);
    button.frame = CGRectIntegral(CGRectMake(x, y, size, size));
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    button.hidden = NO;
    button.alpha = 1.0;
    button.userInteractionEnabled = YES;
    [host bringSubviewToFront:button];
}

static void BHTScheduleVideoButtonEvaluation(UITableViewCell *cell) {
    if (!cell) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        BHTApplyVideoButtonToCell(cell);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BHTApplyVideoButtonToCell(cell);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BHTApplyVideoButtonToCell(cell);
    });
}

static UITableViewCell *BHTVideoTableCellForItem(id self, SEL _cmd, id item, id indexPath) {
    UITableViewCell *cell = nil;
    if (BHTOriginalTableCellForItemIMP) {
        cell = ((BHTTableCellForItemIMP)BHTOriginalTableCellForItemIMP)(self, _cmd, item, indexPath);
    }

    id timelineItem = item;
    SEL itemAtIndexPathSEL = NSSelectorFromString(@"itemAtIndexPath:");
    if ([self respondsToSelector:itemAtIndexPathSEL] && indexPath) {
        id resolved = ((id (*)(id, SEL, id))objc_msgSend)(self, itemAtIndexPathSEL, indexPath);
        if (resolved) timelineItem = resolved;
    }

    if (cell && timelineItem) {
        objc_setAssociatedObject(cell, BHTVideoItemKey, timelineItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    BHTScheduleVideoButtonEvaluation(cell);
    return cell;
}

static void BHTInstallVideoTimelineHook(void) {
    Class cls = NSClassFromString(@"TFNItemsDataViewController");
    SEL selector = NSSelectorFromString(@"tableViewCellForItem:atIndexPath:");
    if (!cls) return;

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;

    const char *types = method_getTypeEncoding(method);

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    Method ownMethod = NULL;
    for (unsigned int i = 0; i < count; i++) {
        if (method_getName(methods[i]) == selector) {
            ownMethod = methods[i];
            break;
        }
    }
    free(methods);

    if (ownMethod) {
        BHTOriginalTableCellForItemIMP = method_getImplementation(ownMethod);
        method_setImplementation(ownMethod, (IMP)BHTVideoTableCellForItem);
    } else {
        BHTOriginalTableCellForItemIMP = method_getImplementation(method);
        class_addMethod(cls, selector, (IMP)BHTVideoTableCellForItem, types);
    }

    NSLog(@"[BHTwitter][X12.16] Installed video download button with delegate proxy");
}

__attribute__((constructor)) static void BHTX1216VideoCompatInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BHTInstallVideoTimelineHook();
    });
}
