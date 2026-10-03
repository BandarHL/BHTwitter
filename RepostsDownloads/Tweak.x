#import "BHRDSafety.h"
#import "BHRDManager.h"
#import "BHRDDownloadButton.h"
#import "BHRDSettingsViewController.h"
#import "BHRDFullscreenDownloadControl.h"
#import "BHRDFullscreenPhotoCopy.h"
#import "BHRDFullscreenContext.h"
#import "BHRDHomeHeaderView.h"
#import "BHRDInlineLayout.h"
#import "BHRDInlineButtonStyle.h"
#import "BHRDShareImageController.h"
#import "BHRDShareImageButton.h"
#import "BHRDFullscreenVisibility.h"
#import "BHRDMediaResolver.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static id BHObjectValueForSelector(id object, SEL selector) {
    return BHRDMediaObject(object, NSStringFromSelector(selector));
}

static BOOL BHViewIsInImmersiveFullScreen(UIView *view) {
    UIResponder *responder = view;
    for (NSUInteger depth = 0; responder != nil && depth < 64; depth++) {
        NSString *className = NSStringFromClass(responder.class);
        if ([responder isKindOfClass:UIViewController.class]) {
            if (BHRDIsFullscreenMediaController(responder)) {
                return true;
            }
        }
        if ([className containsString:@"ImmersiveCardView"] ||
            [className containsString:@"ImmersiveCardOverlayView"] ||
            [className hasSuffix:@"T1SlideshowStatusView"]) {
            return true;
        }
        responder = responder.nextResponder;
    }
    return false;
}

static NSArray *BHFullscreenVideoMediaEntitiesForShareButton(UIView *shareButton) {
    if (![BHRDManager DownloadingVideos] || !BHViewIsInImmersiveFullScreen(shareButton)) {
        return @[];
    }

    NSMutableArray *results = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    UIResponder *responder = shareButton;
    for (NSUInteger depth = 0; responder != nil && depth < 64; depth++) {
        for (id media in [BHRDDownloadButton downloadableMediaEntitiesFromSource:responder]) {
            NSValue *identity = [NSValue valueWithNonretainedObject:media];
            if (![seen containsObject:identity]) {
                [seen addObject:identity];
                [results addObject:media];
            }
        }
        if (results.count > 0) {
            break;
        }
        responder = responder.nextResponder;
    }
    return [results copy];
}

static char BHFullscreenDownloadHandlerKey;
static void BHRDRegisterFloatingSource(UIView *shareButton);

@interface BHRDFullscreenMediaSource : NSObject
@property(nonatomic, weak) UIView *view;
@property(nonatomic, weak) UIView *card;
@property(nonatomic, strong) id model;
@property(nonatomic, copy) NSString *identity;
@end
@implementation BHRDFullscreenMediaSource @end
static char BHRDFloatingSourceKey, BHRDFloatingRouterKey, BHRDFloatingVisibilityKey;
static BHRDFullscreenVisibility *BHRDFloatingVisibility(UIViewController *controller) {
    if (!controller) return nil;
    BHRDFullscreenVisibility *state = objc_getAssociatedObject(controller, &BHRDFloatingVisibilityKey);
    if (!state) {
        state = [BHRDFullscreenVisibility new];
        objc_setAssociatedObject(controller, &BHRDFloatingVisibilityKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
static BOOL BHRDIsFullscreenController(UIViewController *controller) { return BHRDIsFullscreenMediaController(controller); }

static id BHRDVideoModel(UIView *view) {
    return BHRDMediaObject(view, @"viewModel") ?: BHRDMediaObject(BHRDMediaObject(view, @"delegate"), @"viewModel");
}
static BOOL BHRDOnCurrentCard(UIView *view, UIView *root) {
    if (!view || !view.window || ![view isDescendantOfView:root]) return NO;
    CGRect rect = [view convertRect:view.bounds toView:root];
    if (rect.size.height > root.bounds.size.height * 0.6 && rect.size.width > root.bounds.size.width * 0.6 && !CGRectContainsPoint(rect, CGPointMake(CGRectGetMidX(root.bounds), CGRectGetMidY(root.bounds)))) return NO;
    return CGRectIntersectsRect(rect, root.bounds);
}
static NSArray *BHRDResolveFullscreenMedia(UIViewController *controller) {
    UIView *root = controller.viewIfLoaded;
    if (!root.window) return @[];
    BHRDFullscreenMediaSource *source = objc_getAssociatedObject(controller, &BHRDFloatingSourceKey);
    // First resolve the actual live player. Its asset ID can recover the full
    // native quality list collected earlier by the inline button.
    UIView *card = BHRDOnCurrentCard(source.card, root) ? source.card : root;
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:card];
    NSMutableArray *modelSources = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *players = [NSMutableArray array];
    NSMutableSet *seenLayers = [NSMutableSet set];
    NSUInteger budget = 700;
    while (pending.count && budget--) {
        UIView *view = pending.lastObject; [pending removeLastObject];
        if (view != root && !BHRDOnCurrentCard(view, root)) continue;
        // Do not inspect the adjacent off-screen page in a recycled video pager.
        CGRect rect = [view convertRect:view.bounds toView:root];
        if (rect.size.height > root.bounds.size.height * 0.6 && !CGRectContainsPoint(rect, CGPointMake(CGRectGetMidX(root.bounds), CGRectGetMidY(root.bounds)))) continue;
        NSMutableArray<CALayer *> *layers = [NSMutableArray arrayWithObject:view.layer];
        NSUInteger layerBudget = 24;
        while (layers.count && layerBudget--) {
            CALayer *layer = layers.lastObject; [layers removeLastObject];
            NSValue *layerID = [NSValue valueWithNonretainedObject:layer];
            if ([seenLayers containsObject:layerID]) continue;
            [seenLayers addObject:layerID];
            if ([layer isKindOfClass:AVPlayerLayer.class]) {
                AVPlayer *player = ((AVPlayerLayer *)layer).player;
                CGRect visible = CGRectIntersection([layer convertRect:layer.bounds toLayer:root.layer], root.bounds);
                if (player && !CGRectIsNull(visible) && !CGRectIsEmpty(visible)) [players addObject:@{@"player": player, @"area": @(visible.size.width * visible.size.height)}];
            }
            [layers addObjectsFromArray:layer.sublayers ?: @[]];
        }
        NSString *name = NSStringFromClass(view.class);
        if ([name containsString:@"StatusInlineActionsView"] || [name containsString:@"SlideshowStatusView"] || [name containsString:@"ImmersiveCardView"]) {
            id model = BHRDVideoModel(view);
            if (model) [modelSources addObject:model];
        }
        [pending addObjectsFromArray:view.subviews];
    }
    [players sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [b[@"area"] compare:a[@"area"]]; }];
    for (NSDictionary *candidate in players) {
        NSArray *media = BHRDResolveMedia(candidate[@"player"]);
        if (media.count) return media;
    }
    for (id model in modelSources) {
        NSArray *media = BHRDResolveMedia(model);
        if (media.count) return media;
    }
    if (BHRDOnCurrentCard(source.view, root) && (!source.card || BHRDOnCurrentCard(source.card, root))) {
        id currentModel = BHRDVideoModel(source.view);
        if (currentModel) {
            // A reused control whose model changed invalidates the retained model.
            source.model = currentModel;
            source.identity = BHRDMediaStatusIdentity(currentModel);
        }
        NSArray *media = BHFullscreenVideoMediaEntitiesForShareButton(source.view);
        if (media.count) return media;
    }
    // Retain the same model used by inline download while its specific video card
    // stays on screen. Never use a global 'most recently seen video' fallback.
    if (source.card != root && BHRDOnCurrentCard(source.card, root) && source.model) {
        NSString *currentIdentity = BHRDMediaStatusIdentity(source.model);
        if ((source.identity == nil && currentIdentity == nil) || [source.identity isEqual:currentIdentity]) {
            NSArray *media = BHRDResolveMedia(source.model);
            if (media.count) return media;
        }
    }
    NSArray *media = BHRDResolveMedia(controller);
    return media.count ? media : BHRDResolveMedia(root);
}
void BHRDRefreshFullscreenController(UIViewController *controller) {
    if (BHRDRefreshFullscreenPhotoCopy(controller)) return;
    if (!BHRDIsFullscreenController(controller) && !objc_getAssociatedObject(controller, &BHRDFloatingSourceKey)) return;
    UIView *root = controller.viewIfLoaded;
    if (!root) return;
    BHRDFullscreenActionRouter *router = objc_getAssociatedObject(controller, &BHRDFloatingRouterKey);
    if (!router) {
        router = [BHRDFullscreenActionRouter new];
        __weak UIViewController *weakController = controller;
        router.isEnabled = ^BOOL { return [BHRDFloatingVisibility(weakController) shouldDisplayEnabled:([BHRDManager DownloadingVideos] && BHRDPreference(BHRDFloatingDownloadKey)) attached:weakController.viewIfLoaded.window != nil]; };
        router.resolveMedia = ^NSArray * { return BHRDResolveFullscreenMedia(weakController); };
        router.retryOnUnavailable = YES;

        router.showDownloads = ^(NSArray *media) {
            UIView *view = weakController.viewIfLoaded;
            if (!view) return;
            BHRDDownloadButton *handler = objc_getAssociatedObject(view, &BHFullscreenDownloadHandlerKey);
            if (!handler) {
                handler = [BHRDDownloadButton new];
                objc_setAssociatedObject(view, &BHFullscreenDownloadHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            [handler presentDownloadOptionsForMediaEntities:media sourceView:view];
        };
        router.showUnavailable = ^{ BHRDShowError(@"暂时无法读取当前视频，请等待加载完成或切换回来后重试。"); };
        objc_setAssociatedObject(controller, &BHRDFloatingRouterKey, router, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (root.window && ![BHRDFloatingVisibility(controller) shouldDisplayEnabled:YES attached:YES]) [BHRDFloatingVisibility(controller) observeMedia:router.resolveMedia().count > 0];
    // Keep a verified video session's control visible when playback chrome fades
    // or media discovery is temporarily empty. Resolve fresh media only on tap.
    BOOL active = router.isEnabled();
    BHRDUpdateFloatingDownloadControl(controller, active, router);
}
void BHRDFullscreenControllerDidAppear(UIViewController *controller) {
    if (!BHRDIsFullscreenController(controller) && !objc_getAssociatedObject(controller, &BHRDFloatingSourceKey)) return;
    [BHRDFloatingVisibility(controller) didAppear];
    BHRDRefreshFullscreenController(controller);
}
void BHRDFullscreenControllerDidDisappear(UIViewController *controller) {
    BHRDRemoveFullscreenPhotoCopy(controller);
    if (!BHRDIsFullscreenController(controller) && !objc_getAssociatedObject(controller, &BHRDFloatingSourceKey)) return;
    [BHRDFloatingVisibility(controller) didDisappear];
    BHRDRemoveFloatingDownloadControl(controller);
}
static void BHRDRegisterFloatingSource(UIView *shareButton) {
    if (!shareButton.window || !BHViewIsInImmersiveFullScreen(shareButton)) return;
    UIViewController *owner = nil, *fallback = nil;
    UIResponder *responder = shareButton.nextResponder;
    for (NSUInteger depth = 0; responder && depth < 64; depth++, responder = responder.nextResponder) {
        if (![responder isKindOfClass:UIViewController.class]) continue;
        UIViewController *controller = (UIViewController *)responder;
        UIView *root = controller.viewIfLoaded;
        if (!root.window || root.bounds.size.height < root.window.bounds.size.height * 0.7) continue;
        if (!CGRectIntersectsRect([shareButton convertRect:shareButton.bounds toView:root], root.bounds)) continue;
        if (!fallback) fallback = controller;
        // Prefer the outer fullscreen screen over its transient controls/card child.
        if (BHRDIsFullscreenController(controller)) owner = controller;
    }
    owner = owner ?: fallback;
    if (!owner) return;
    BHRDRegisterFullscreenMediaSource(owner,shareButton);
    BHRDFullscreenMediaSource *source = objc_getAssociatedObject(owner, &BHRDFloatingSourceKey);
    if (!source) {
        source = [BHRDFullscreenMediaSource new];
        objc_setAssociatedObject(owner, &BHRDFloatingSourceKey, source, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    source.view = shareButton;
    id model = BHRDVideoModel(shareButton);
    UIView *card = nil;
    for (UIView *parent = shareButton.superview; parent && parent != owner.view; parent = parent.superview) {
        NSString *name = NSStringFromClass(parent.class);
        if ([name containsString:@"ImmersiveCardView"] || [name hasSuffix:@"T1SlideshowStatusView"]) card = parent;
        if (!model) model = BHRDVideoModel(parent);
    }
    BOOL sameCard = source.card == card;
    source.card = card;
    if (model) {
        if (source.model != model || ![source.identity isEqual:BHRDMediaStatusIdentity(model)]) BHRDRememberMedia(model);
        source.model = model; source.identity = BHRDMediaStatusIdentity(model);
    } else if (!card || !sameCard) {
        source.model = nil; source.identity = nil;
    }
    BHRDRefreshFullscreenController(owner);
}

static void BHRemoveExtraFullscreenDownloadButtons(UIView *actionsView) {
    if (BHViewIsInImmersiveFullScreen(actionsView)) BHRDRegisterFloatingSource(actionsView);
    if (![BHRDManager DownloadingVideos] || !BHRDPreference(BHRDFloatingDownloadKey) || !BHViewIsInImmersiveFullScreen(actionsView)) {
        return;
    }

    id inlineActionButtons = BHObjectValueForSelector(actionsView, @selector(inlineActionButtons));
    if ([inlineActionButtons isKindOfClass:NSMutableArray.class]) {
        NSMutableArray *buttons = inlineActionButtons;
        NSIndexSet *downloadButtonIndexes = [buttons indexesOfObjectsPassingTest:^BOOL(id button, NSUInteger index, BOOL *stop) {
            return [button isKindOfClass:BHRDDownloadButton.class];
        }];
        for (UIView *button in [buttons objectsAtIndexes:downloadButtonIndexes]) {
            [button removeFromSuperview];
        }
        [buttons removeObjectsAtIndexes:downloadButtonIndexes];
    }

    NSMutableArray<UIView *> *pendingViews = [actionsView.subviews mutableCopy];
    while (pendingViews.count > 0) {
        UIView *view = pendingViews.lastObject;
        [pendingViews removeLastObject];
        if ([view isKindOfClass:BHRDDownloadButton.class]) {
            [view removeFromSuperview];
            continue;
        }
        [pendingViews addObjectsFromArray:view.subviews];
    }
}

// Observe layout only to find the current video's model. Sharing is untouched.
%hook TTAStatusInlineShareButton
- (void)layoutSubviews { %orig; BHRDRegisterFloatingSource((UIView *)self); }
%end

%hook T1StatusInlineShareButton
- (void)layoutSubviews { %orig; BHRDRegisterFloatingSource((UIView *)self); }
%end

%hook TTAStatusInlineActionsView
+ (NSArray *)_t1_inlineActionViewClassesForViewModel:(id)arg1 options:(NSUInteger)arg2 displayType:(NSUInteger)arg3 account:(id)arg4 {
    NSArray *_orig = %orig;
    NSMutableArray *newOrig = [_orig mutableCopy] ?: [NSMutableArray array];

    if ([BHRDManager isVideoCell:arg1] && [BHRDManager DownloadingVideos] && ![newOrig containsObject:BHRDDownloadButton.class]) {
        BHRDRememberMedia(arg1);
        [newOrig addObject:%c(BHRDDownloadButton)];
    }

    return BHRDSetShareImageButtonClass(BHRDFilterInlineActionClasses([newOrig copy], BHRDHiddenInlineActionKeys()), BHRDShareImageButton.class, BHRDPreference(BHRDShowShareImageKey));
}

- (void)layoutSubviews {
    BHRemoveExtraFullscreenDownloadButtons((UIView *)self);
    %orig;
    BHRemoveExtraFullscreenDownloadButtons((UIView *)self);
    if (!BHViewIsInImmersiveFullScreen((UIView *)self)) BHRDLayoutInlineActions((UIView *)self);
    BHRDMatchAddedButtonsToNative((UIView *)self);
}
%end

%hook T1StatusInlineActionsView
+ (NSArray *)_t1_inlineActionViewClassesForViewModel:(id)arg1 options:(NSUInteger)arg2 displayType:(NSUInteger)arg3 account:(id)arg4 {
    NSArray *_orig = %orig;
    NSMutableArray *newOrig = [_orig mutableCopy] ?: [NSMutableArray array];

    if ([BHRDManager isVideoCell:arg1] && [BHRDManager DownloadingVideos] && ![newOrig containsObject:BHRDDownloadButton.class]) {
        BHRDRememberMedia(arg1);
        [newOrig addObject:%c(BHRDDownloadButton)];
    }

    return BHRDSetShareImageButtonClass(BHRDFilterInlineActionClasses([newOrig copy], BHRDHiddenInlineActionKeys()), BHRDShareImageButton.class, BHRDPreference(BHRDShowShareImageKey));
}


- (void)layoutSubviews {
    BHRemoveExtraFullscreenDownloadButtons((UIView *)self);
    %orig;
    BHRemoveExtraFullscreenDownloadButtons((UIView *)self);
    if (!BHViewIsInImmersiveFullScreen((UIView *)self)) BHRDLayoutInlineActions((UIView *)self);
    BHRDMatchAddedButtonsToNative((UIView *)self);
}
%end

// An independent interaction object avoids replacing X's context-menu delegate methods.
@interface BHRDDMInteractionDelegate : NSObject <UIContextMenuInteractionDelegate>
@property(nonatomic, weak) T1DirectMessageEntryMediaCell *cell;
@property(nonatomic, strong) BHRDDownloadButton *handler;
@end
@implementation BHRDDMInteractionDelegate
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    if (![BHRDManager DMDownload]) return nil;
    NSArray *media = [BHRDDownloadButton downloadableMediaEntitiesFromSource:self.cell.inlineMediaView];
    if (!media.count) return nil;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIAction *download = [UIAction actionWithTitle:@"下载视频 / 动图" image:[UIImage systemImageNamed:@"square.and.arrow.down"] identifier:nil handler:^(UIAction *action) {
            if (![BHRDManager DMDownload]) return;
            if (!self.handler) self.handler = [BHRDDownloadButton new];
            [self.handler presentDownloadOptionsForMediaEntities:media sourceView:self.cell];
        }];
        return [UIMenu menuWithTitle:@"" children:[suggested arrayByAddingObject:download]];
    }];
}
@end
static char BHRDDMDelegateKey, BHRDDMInteractionKey;
%hook T1DirectMessageEntryMediaCell
- (void)setEntryViewModel:(id)model {
    %orig;
    UIContextMenuInteraction *old = objc_getAssociatedObject(self, &BHRDDMInteractionKey);
    if (old) [self removeInteraction:old];
    objc_setAssociatedObject(self, &BHRDDMInteractionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (![BHRDManager DMDownload]) return;
    if (![[BHRDDownloadButton downloadableMediaEntitiesFromSource:self.inlineMediaView] count]) return;
    BHRDDMInteractionDelegate *delegate = objc_getAssociatedObject(self, &BHRDDMDelegateKey);
    if (!delegate) {
        delegate = [BHRDDMInteractionDelegate new];
        delegate.cell = self;
        objc_setAssociatedObject(self, &BHRDDMDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UIContextMenuInteraction *interaction = [[UIContextMenuInteraction alloc] initWithDelegate:delegate];
    self.userInteractionEnabled = YES;
    [self addInteraction:interaction];
    objc_setAssociatedObject(self, &BHRDDMInteractionKey, interaction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

%hook T1GenericSettingsViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    BHRDInstallSettingsEntry(self, 1);
}
%end
%hook T1SettingsViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    BHRDInstallSettingsEntry(self, 2);
}
%end

%hook T1SettingsViewController
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (BHRDIsSettingsEntry(self, indexPath)) return BHRDSettingsEntryCell();
    return %orig;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (BHRDIsSettingsEntry(self, indexPath)) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        BHRDOpenSettings(self);
    } else { %orig; }
}
%end

// Original CustomTabBar uses scribePage, not the position or translated label.
// Remember only the visibility changed by this tweak so unrelated hidden tabs stay hidden.
static char BHRDTabVisibilityKey;
static void BHRDUpdateTabVisibility(T1TabBarViewController *controller) {
    for (id object in controller.tabViews) {
        if (![object isKindOfClass:UIView.class] || ![object respondsToSelector:@selector(scribePage)]) continue;
        UIView *tab = object;
        NSString *key = BHRDPreferenceKeyForTabPage(BHObjectValueForSelector(tab, @selector(scribePage)));
        BOOL hide = key && BHRDPreference(key);
        NSNumber *original = objc_getAssociatedObject(tab, &BHRDTabVisibilityKey);
        if (hide) {
            if (!original) objc_setAssociatedObject(tab, &BHRDTabVisibilityKey, @(tab.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            tab.hidden = YES;
        } else if (original) {
            tab.hidden = original.boolValue;
            objc_setAssociatedObject(tab, &BHRDTabVisibilityKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}
%hook T1TabBarViewController
- (void)loadView {
    %orig;
    BHRDUpdateTabVisibility(self);
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    BHRDUpdateTabVisibility(self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    BHRDUpdateTabVisibility(self);
}
%end

%ctor { if (BHRDFeatureHooksEnabledAtLaunch()) { %init; } }
