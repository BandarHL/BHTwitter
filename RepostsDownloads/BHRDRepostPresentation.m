#import "BHRDRepostPresentation.h"
#import "BHRDManager.h"
#import "BHRDConversationScope.h"
#import "BHRDAdFilter.h"
#import "BHRDContentFilter.h"
#import "BHRDRepostAuthor.h"
#import <objc/runtime.h>
#import <objc/message.h>

static char BHRDCellStateKey, BHRDExpandedKey, BHRDReloadKey, BHRDForceReloadKey;
static NSHashTable *Controllers(void) {
    static NSHashTable *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}
static NSMutableSet *Expanded(id controller) {
    NSMutableSet *set = objc_getAssociatedObject(controller, &BHRDExpandedKey);
    if (!set) {
        set = [NSMutableSet set];
        objc_setAssociatedObject(controller, &BHRDExpandedKey, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return set;
}
static NSInteger Presentation(id controller, id model) {
    if (BHRDIsConversationContext(controller) || BHRDIsConversationContext(model)) return -1;
    [Controllers() addObject:controller];
    if (BHRDShouldHideRecommendation(model, controller)) return BHRDRepostModeHidden;
    if (BHRDPreference(BHRDHideAdsKey) && BHRDIsPromotedModel(model)) return BHRDRepostModeHidden;
    if (![BHRDManager HideReposts] || !BHRDIsRepostModel(model)) return -1;
    if ([Expanded(controller) containsObject:BHRDRepostIdentity(model)]) return -1;
    return BHRDCurrentRepostMode();
}
static UITableView *Table(id controller) {
    if (![controller respondsToSelector:@selector(tableView)]) return nil;
    id table = ((id (*)(id, SEL))objc_msgSend)(controller, @selector(tableView));
    return [table isKindOfClass:UITableView.class] ? table : nil;
}
static void ScheduleRefresh(id controller, BOOL forceReload) {
    if (!controller) return;
    if (forceReload) objc_setAssociatedObject(controller, &BHRDForceReloadKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ([objc_getAssociatedObject(controller, &BHRDReloadKey) boolValue]) return;
    [Controllers() addObject:controller];
    objc_setAssociatedObject(controller, &BHRDReloadKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak id weakController = controller;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id current = weakController;
        if (!current) return;
        objc_setAssociatedObject(current, &BHRDReloadKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        BOOL force = [objc_getAssociatedObject(current, &BHRDForceReloadKey) boolValue];
        objc_setAssociatedObject(current, &BHRDForceReloadKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (BHRDIsConversationContext(current)) return;
        UITableView *table = Table(current);
        if (!table) return;
        // Never rewrite row counts inside a delegate callback or a host batch update.
        if (table.hasUncommittedUpdates || table.dragging || table.decelerating) {
            ScheduleRefresh(current, force);
            return;
        }
        BOOL changed = NO;
        if ([current respondsToSelector:@selector(sections)] && [current respondsToSelector:@selector(setSections:)]) {
            NSArray *sections = [(TFNItemsDataViewController *)current sections];
            NSArray *recommendations = BHRDFilterRecommendations(sections, current);
            NSArray *filtered = BHRDPreference(BHRDHideAdsKey) ? BHRDSectionsByRemovingAds(recommendations) : recommendations;
            if ([BHRDManager HideReposts] && BHRDCurrentRepostMode() == BHRDRepostModeHidden) filtered = BHRDSectionsByRemovingReposts(filtered);
            if (filtered != sections) {
                [(TFNItemsDataViewController *)current setSections:filtered];
                changed = YES;
            }
        }
        // Reloading also recalculates row heights. No manual contentOffset or frame changes.
        if (changed || force) [UIView performWithoutAnimation:^{ [table reloadData]; }];
    });
}
void BHRDScheduleTimelineRefresh(id controller) { ScheduleRefresh(controller, YES); }
void BHRDResetExpandedReposts(void) {
    for (id controller in Controllers().allObjects) {
        [Expanded(controller) removeAllObjects];
        BHRDScheduleTimelineRefresh(controller);
    }
}
void BHRDRepostPreferencesChanged(void) { BHRDResetExpandedReposts(); }
double BHRDRepostRowHeight(id controller, id model, double originalHeight) {
    NSInteger mode = Presentation(controller, model);
    if (mode < 0) return originalHeight;
    if (mode == BHRDRepostModeHidden) {
        ScheduleRefresh(controller, NO);
        // A clipped, empty one-point safety cell only until the deferred model purge.
        // A zero-height live Twitter cell was the cause of the old overlapping fallback.
        return 1.0;
    }
    return mode == BHRDRepostModeBar ? 60.0 : 172.0;
}

// Lay out from the final row bounds, not the cell's pre-layout (possibly zero) width.
@interface BHRDRepostOverlay : UIView
@property(nonatomic, strong) UILabel *title;
@property(nonatomic, strong) UIButton *show;
@property(nonatomic, strong) UIImageView *avatar;
@property(nonatomic, strong) UILabel *author;
@property(nonatomic, strong) UILabel *empty;
@property(nonatomic, strong) UIStackView *grid;
@end
@implementation BHRDRepostOverlay
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    self.title.frame = CGRectMake(16, 18, MAX(0, width - 132), 24);
    self.show.frame = CGRectMake(MAX(16, width - 104), 10, 88, 40);
    self.avatar.frame = CGRectMake(16, 54, 28, 28);
    self.author.frame = CGRectMake(52, 54, MAX(0, width - 68), 28);
    self.empty.frame = CGRectMake(16, 94, MAX(0, width - 32), 52);
    self.grid.frame = CGRectMake(16, 92, MAX(0, width - 32), 68);
}
@end

@interface BHRDRepostCellState : NSObject
@property(nonatomic, weak) UITableViewCell *cell;
@property(nonatomic, weak) id controller;
@property(nonatomic, copy) NSString *identity;
@property(nonatomic) NSInteger mode;
@property(nonatomic, copy) NSString *author;
@property(nonatomic, copy) NSURL *avatarURL;
@property(nonatomic, copy) NSArray<NSURL *> *thumbnailURLs;
@property(nonatomic, strong) BHRDRepostInfo *info;
@property(nonatomic, strong) UIImage *nativeAvatar;
@property(nonatomic) BOOL capturingAuthor;
@property(nonatomic) BOOL imageCaptureQueued;
@property(nonatomic) BOOL originalClips;
@property(nonatomic) BOOL originalAccessible;
@property(nonatomic) UITableViewCellSelectionStyle selection;
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *hiddenViews;
@property(nonatomic, strong) UIView *overlay;
@property(nonatomic, strong) NSMutableArray<NSURLSessionDataTask *> *tasks;
@end
@implementation BHRDRepostCellState
- (void)showThis {
    id controller = self.controller;
    if (!controller) return;
    [Expanded(controller) addObject:self.identity];
    BHRDScheduleTimelineRefresh(controller);
}
@end
void BHRDRepostMetadataChanged(void) {
    // Coalesce related network responses and only reconfigure visible previews.
    // Their row geometry is unchanged, so a full table reload is unnecessary.
    dispatch_async(dispatch_get_main_queue(), ^{
        static BOOL scheduled = NO;
        if (scheduled || ![BHRDManager HideReposts] || BHRDCurrentRepostMode() != BHRDRepostModePreview) return;
        scheduled = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            scheduled = NO;
            if (![BHRDManager HideReposts] || BHRDCurrentRepostMode() != BHRDRepostModePreview) return;
            for (id controller in Controllers().allObjects) {
                UITableView *table = Table(controller);
                if (!table.window || ![controller respondsToSelector:@selector(itemAtIndexPath:)]) continue;
                if (table.hasUncommittedUpdates) { BHRDRepostMetadataChanged(); continue; }
                for (UITableViewCell *cell in table.visibleCells) {
                    BHRDRepostCellState *state = objc_getAssociatedObject(cell, &BHRDCellStateKey);
                    if (state.controller != controller || state.mode != BHRDRepostModePreview) continue;
                    NSIndexPath *indexPath = [table indexPathForCell:cell];
                    id model = indexPath ? [(TFNItemsDataViewController *)controller itemAtIndexPath:indexPath] : nil;
                    if (model) BHRDConfigureRepostCell(cell, model, controller);
                }
            }
        });
    });
}
static NSCache *ImageCache(void) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 100; cache.totalCostLimit = 20 * 1024 * 1024; });
    return cache;
}
static void LoadImage(NSURL *url, UIImageView *view, BHRDRepostCellState *state) {
    if (!url) return;
    UIImage *image = [ImageCache() objectForKey:url.absoluteString];
    if (image) { view.image = image; return; }
    __weak BHRDRepostCellState *weakState = state;
    __weak UIImageView *weakView = view;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || data.length > 8 * 1024 * 1024 || ![response.MIMEType hasPrefix:@"image/"]) return;
        UIImage *downloaded = [UIImage imageWithData:data];
        if (!downloaded) return;
        [ImageCache() setObject:downloaded forKey:url.absoluteString cost:downloaded.size.width * downloaded.size.height * 4];
        dispatch_async(dispatch_get_main_queue(), ^{
            BHRDRepostCellState *current = weakState;
            // Reused cells must never display the previous tweet's asynchronous image.
            if (current && objc_getAssociatedObject(current.cell, &BHRDCellStateKey) == current) weakView.image = downloaded;
        });
    }];
    [state.tasks addObject:task];
    [task resume];
}
static UILabel *Label(NSString *text, CGFloat size, UIColor *color) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}
static void CaptureNativeAuthor(BHRDRepostCellState *state) {
    if (state.mode != BHRDRepostModePreview || !state.cell || state.capturingAuthor) return;
    UITableView *table = Table(state.controller);
    NSIndexPath *path = [table indexPathForCell:state.cell];
    if (path && [state.controller respondsToSelector:@selector(itemAtIndexPath:)]) {
        id model = [(TFNItemsDataViewController *)state.controller itemAtIndexPath:path];
        if (![BHRDRepostIdentity(model) isEqual:state.identity]) return;
    }
    state.capturingAuthor = YES;
    // The host's child header layout can run after the cell's own layout.
    // Finish pending child layout before reading coordinates, including when
    // this tweak has hidden the enclosing content view underneath its overlay.
    for (UIView *view in state.cell.subviews) if (view != state.overlay) [view layoutIfNeeded];
    UIImage *image = BHRDCaptureRepostAuthor(state.cell, state.overlay, state.hiddenViews, state.info);
    BHRDRepostOverlay *overlay = (BHRDRepostOverlay *)state.overlay;
    if (![state.author isEqual:state.info.author]) {
        state.author = state.info.author;
        overlay.author.text = state.author;
    }
    if (image) { state.nativeAvatar = image; overlay.avatar.image = image; }
    if (state.info.avatar && ![state.avatarURL isEqual:state.info.avatar]) {
        state.avatarURL = state.info.avatar;
        if (!state.nativeAvatar) LoadImage(state.avatarURL, overlay.avatar, state);
    }
    state.capturingAuthor = NO;
}
static void ScheduleAuthorCapture(BHRDRepostCellState *state) {
    if (state.mode != BHRDRepostModePreview) return;
    __weak BHRDRepostCellState *weakState = state;
    // Host headers and image views may be populated after cellForRow returns.
    // Bounded retries complement layout callbacks; never retain/reload the row.
    for (NSNumber *delay in @[@0.15, @0.6, @1.5, @4.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BHRDRepostCellState *current = weakState;
            if (current.cell.window && objc_getAssociatedObject(current.cell, &BHRDCellStateKey) == current) CaptureNativeAuthor(current);
        });
    }
}
void BHRDRepostNativeImageChanged(UIImageView *view) {
    if (!NSThread.isMainThread) return;
    for (UIView *parent = view.superview; parent; parent = parent.superview) {
        if ([parent isKindOfClass:BHRDRepostOverlay.class]) return;
        if (![parent isKindOfClass:UITableViewCell.class]) continue;
        BHRDRepostCellState *state = objc_getAssociatedObject(parent, &BHRDCellStateKey);
        if (!state || state.mode != BHRDRepostModePreview || state.imageCaptureQueued) return;
        state.imageCaptureQueued = YES;
        __weak BHRDRepostCellState *weakState = state;
        dispatch_async(dispatch_get_main_queue(), ^{
            BHRDRepostCellState *current = weakState;
            current.imageCaptureQueued = NO;
            if (current && objc_getAssociatedObject(current.cell, &BHRDCellStateKey) == current) CaptureNativeAuthor(current);
        });
        return;
    }
}
void BHRDRestoreRepostCell(UITableViewCell *cell) {
    BHRDRepostCellState *state = objc_getAssociatedObject(cell, &BHRDCellStateKey);
    if (!state) return;
    objc_setAssociatedObject(cell, &BHRDCellStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (NSURLSessionTask *task in state.tasks) [task cancel];
    for (UIView *view in state.hiddenViews.keyEnumerator) view.hidden = [[state.hiddenViews objectForKey:view] boolValue];
    [state.overlay removeFromSuperview];
    cell.clipsToBounds = state.originalClips;
    cell.isAccessibilityElement = state.originalAccessible;
    cell.selectionStyle = state.selection;
}
void BHRDLayoutRepostCell(UITableViewCell *cell) {
    BHRDRepostCellState *state = objc_getAssociatedObject(cell, &BHRDCellStateKey);
    if (!state) return;
    if (BHRDIsConversationContext(cell) || BHRDIsConversationContext(state.controller)) {
        BHRDRestoreRepostCell(cell);
        return;
    }
    CaptureNativeAuthor(state);
    // Hide the original host subtree after each host layout, including newly added views.
    // The separate overlay does not inherit the tweet's text/media layout constraints.
    for (UIView *view in cell.subviews) {
        if (view == state.overlay) continue;
        if (![state.hiddenViews objectForKey:view]) [state.hiddenViews setObject:@(view.hidden) forKey:view];
        view.hidden = YES;
    }
    cell.clipsToBounds = YES;
    state.overlay.frame = cell.bounds;
    [state.overlay setNeedsLayout];
    [cell bringSubviewToFront:state.overlay];
}
void BHRDConfigureRepostCell(UITableViewCell *cell, id model, id controller) {
    if (![cell isKindOfClass:UITableViewCell.class]) return;
    NSInteger mode = BHRDIsConversationContext(cell) ? -1 : Presentation(controller, model);
    BHRDRepostCellState *old = objc_getAssociatedObject(cell, &BHRDCellStateKey);
    NSString *identity = mode < 0 ? nil : BHRDRepostIdentity(model);
    BHRDRepostInfo *info = mode == BHRDRepostModePreview ? BHRDInfoForRepostModel(model) : nil;
    BOOL sameIdentity = old && old.controller == controller && [old.identity isEqual:identity];
    UIImage *nativeAvatar = nil;
    if (info) {
        // Do not lose a native header snapshot when a partial network update
        // reconfigures this same cell. Reuse never carries it to a different ID.
        BOOL sameAuthor = !info.authorHandle.length || !old.info.authorHandle.length || [info.authorHandle caseInsensitiveCompare:old.info.authorHandle] == NSOrderedSame;
        if (sameIdentity && sameAuthor) {
            if (!info.authorName.length) info.authorName = old.info.authorName;
            if (!info.authorHandle.length) info.authorHandle = old.info.authorHandle;
            if (!info.avatar) info.avatar = old.info.avatar;
            if (info.authorHandle.length) info.author = info.authorName.length ? [NSString stringWithFormat:@"%@ · @%@", info.authorName, info.authorHandle] : [@"@" stringByAppendingString:info.authorHandle];
            nativeAvatar = old.nativeAvatar;
        }
        nativeAvatar = BHRDCaptureRepostAuthor(cell, old.overlay, old.hiddenViews, info) ?: nativeAvatar;
    }
    // A reused identity can receive fuller metadata later. Keep value snapshots so
    // an earlier placeholder cannot mask an updated author, avatar or media list.
    BOOL samePreview = mode != BHRDRepostModePreview ||
        ([old.author isEqual:info.author] &&
         (old.avatarURL == info.avatar || [old.avatarURL isEqual:info.avatar]) &&
         [old.thumbnailURLs isEqual:info.thumbnails]);
    if (sameIdentity && old.mode == mode && samePreview) { BHRDLayoutRepostCell(cell); return; }
    BHRDRestoreRepostCell(cell);
    if (mode < 0) return;
    BHRDRepostCellState *state = [BHRDRepostCellState new];
    state.cell = cell;
    state.controller = controller;
    state.identity = identity;
    state.mode = mode;
    state.author = info.author;
    state.avatarURL = info.avatar;
    state.thumbnailURLs = info.thumbnails;
    state.info = info;
    state.nativeAvatar = nativeAvatar;
    state.originalClips = cell.clipsToBounds;
    state.originalAccessible = cell.isAccessibilityElement;
    state.selection = cell.selectionStyle;
    state.hiddenViews = [NSMapTable weakToStrongObjectsMapTable];
    state.tasks = [NSMutableArray array];
    cell.isAccessibilityElement = NO;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    BHRDRepostOverlay *overlay = [[BHRDRepostOverlay alloc] initWithFrame:cell.bounds];
    overlay.backgroundColor = UIColor.systemBackgroundColor;
    overlay.clipsToBounds = YES;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    state.overlay = overlay;
    objc_setAssociatedObject(cell, &BHRDCellStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [cell addSubview:overlay];
    if (mode != BHRDRepostModeHidden) {
        UILabel *title = Label(@"已隐藏一条转推", 14, UIColor.secondaryLabelColor);
        title.frame = CGRectMake(16, 18, MAX(60, cell.bounds.size.width - 132), 24);
        title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        overlay.title = title;
        [overlay addSubview:title];
        UIButton *show = [UIButton buttonWithType:UIButtonTypeSystem];
        [show setTitle:@"显示这条" forState:UIControlStateNormal];
        show.frame = CGRectMake(cell.bounds.size.width - 104, 10, 88, 40);
        show.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [show addTarget:state action:@selector(showThis) forControlEvents:UIControlEventTouchUpInside];
        overlay.show = show;
        [overlay addSubview:show];
        if (mode == BHRDRepostModePreview) {
            UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 54, 28, 28)];
            avatar.image = nativeAvatar ?: [UIImage systemImageNamed:@"person.crop.circle"];
            avatar.contentMode = UIViewContentModeScaleAspectFill;
            avatar.layer.cornerRadius = 14;
            avatar.clipsToBounds = YES;
            overlay.avatar = avatar;
            [overlay addSubview:avatar];
            if (!nativeAvatar) LoadImage(info.avatar, avatar, state);
            UILabel *author = Label(info.author, 13, UIColor.labelColor);
            author.frame = CGRectMake(52, 54, MAX(60, cell.bounds.size.width - 68), 28);
            author.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            overlay.author = author;
            [overlay addSubview:author];
            if (!info.thumbnails.count) {
                UILabel *empty = Label(@"暂无媒体缩略图，可点“显示这条”查看原文", 12, UIColor.secondaryLabelColor);
                empty.numberOfLines = 2;
                empty.frame = CGRectMake(16, 94, MAX(60, cell.bounds.size.width - 32), 52);
                empty.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                overlay.empty = empty;
                [overlay addSubview:empty];
            } else {
                UIStackView *grid = [[UIStackView alloc] initWithFrame:CGRectMake(16, 92, MAX(60, cell.bounds.size.width - 32), 68)];
                grid.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                grid.axis = UILayoutConstraintAxisHorizontal;
                grid.distribution = UIStackViewDistributionFillEqually;
                grid.spacing = 6;
                overlay.grid = grid;
                [overlay addSubview:grid];
                for (NSURL *url in info.thumbnails) {
                    UIImageView *thumb = [UIImageView new];
                    thumb.image = [UIImage systemImageNamed:@"photo"];
                    // Keep the current column width and compact row height. Fit
                    // the entire photo/poster into its slot instead of cropping
                    // a narrow horizontal strip out of the original image.
                    thumb.contentMode = UIViewContentModeScaleAspectFit;
                    thumb.clipsToBounds = YES;
                    thumb.layer.cornerRadius = 8;
                    thumb.backgroundColor = UIColor.secondarySystemBackgroundColor;
                    thumb.accessibilityLabel = @"媒体缩略图，点击显示这条转推";
                    thumb.isAccessibilityElement = YES;
                    thumb.userInteractionEnabled = YES;
                    [thumb addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:state action:@selector(showThis)]];
                    [grid addArrangedSubview:thumb];
                    LoadImage(url, thumb, state);
                }
            }
        }
    }
    BHRDLayoutRepostCell(cell);
    ScheduleAuthorCapture(state);
}
