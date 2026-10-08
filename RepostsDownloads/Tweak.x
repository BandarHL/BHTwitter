#import "BHRDSafety.h"
#import "BHRDManager.h"
#import "BHRDDownloadButton.h"
#import "BHRDSettingsViewController.h"
#import "BHRDFullscreenDownloadControl.h"
#import "BHRDFullscreenPhotoCopy.h"
#import "BHRDFullscreenContext.h"
#import "BHRDFullscreenVideoResolver.h"
#import "BHRDFullscreenVideoPresence.h"
#import "BHRDHomeHeaderView.h"
#import "BHRDInlineLayout.h"
#import "BHRDInlineButtonStyle.h"
#import "BHRDShareImageController.h"
#import "BHRDShareImageButton.h"
#import "BHRDFullscreenVisibility.h"
#import "BHRDMediaResolver.h"
#import "BHRDAvatarDiagnostics.h"
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

static char BHFullscreenDownloadHandlerKey;
static void BHRDRegisterFloatingSource(UIView *shareButton);

@interface BHRDFullscreenMediaSource : NSObject
@property(nonatomic, weak) UIView *view;
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

static NSArray *BHRDResolveFullscreenMedia(UIViewController *controller) {
    return BHRDCurrentFullscreenVideoContext(controller)[@"media"];
}
static void BHRDLogVideoResolution(NSString *phase,NSDictionary *context,NSString *attempt,NSString *session) {
    BHRDAvatarLog(@"fullscreen_video_resolution",@{@"phase":phase,@"reason":context[@"reason"] ?: @"",
        @"sourceClass":context[@"sourceClass"] ?: @"",@"sourcePath":context[@"sourcePath"] ?: @"",
        @"playerCount":context[@"playerCount"] ?: @0,@"modelCount":context[@"modelCount"] ?: @0,
        @"visibleSourceCount":context[@"visibleSourceCount"] ?: @0,
        @"observedViewClasses":context[@"observedViewClasses"] ?: @[],@"examinedViewCount":context[@"examinedViewCount"] ?: @0,
        @"scanTruncated":context[@"scanTruncated"] ?: @NO,
        @"attempt":attempt ?: @"",@"acceptanceSession":session ?: @""});
}
void BHRDRefreshFullscreenController(UIViewController *controller) {
    if (!BHRDTweakEnabled()) { BHRDRemoveFullscreenPhotoCopy(controller); BHRDRemoveFloatingDownloadControl(controller); return; }
    if (!BHRDIsFullscreenController(controller) && !objc_getAssociatedObject(controller, &BHRDFloatingSourceKey)) return;
    UIView *root = controller.viewIfLoaded;
    if (!root) return;
    BOOL photoSelected=BHRDHasSelectedFullscreenPhoto(controller);
    if (photoSelected) [BHRDFloatingVisibility(controller) observePhotoPresence];
    BOOL videoPresent=!photoSelected && BHRDHasVisibleFullscreenVideo(controller);
    if (videoPresent) BHRDRemoveFullscreenPhotoCopy(controller);
    else if (BHRDRefreshFullscreenPhotoCopy(controller)) { [BHRDFloatingVisibility(controller) observePhotoPresence]; return; }
    [BHRDFloatingVisibility(controller) observeVideoPresence:videoPresent];
    BHRDFullscreenActionRouter *router = objc_getAssociatedObject(controller, &BHRDFloatingRouterKey);
    if (!router) {
        router = [BHRDFullscreenActionRouter new];
        __weak UIViewController *weakController = controller;
        router.isEnabled = ^BOOL { return [BHRDFloatingVisibility(weakController) shouldDisplayEnabled:([BHRDManager DownloadingVideos] && BHRDPreference(BHRDFloatingDownloadKey)) attached:weakController.viewIfLoaded.window != nil]; };
        router.resolveMedia = ^NSArray * { return BHRDResolveFullscreenMedia(weakController); };
        router.resolveSelection=^NSDictionary * { return BHRDCurrentFullscreenVideoContext(weakController); };
        router.observeResolution=^(NSString *phase,NSDictionary *context,NSString *attempt,NSString *session) { BHRDLogVideoResolution(phase,context,attempt,session); };
        router.retryOnUnavailable = YES;
        __weak BHRDFullscreenActionRouter *weakRouter=router;
        router.showDownloads = ^(NSArray *media) {
            UIView *view = weakController.viewIfLoaded;
            NSString *identity=weakRouter.activationIdentity, *attempt=weakRouter.activationAttempt, *session=weakRouter.acceptanceSession;
            NSDictionary *context=BHRDCurrentFullscreenVideoContext(weakController);
            NSString *resource=context[@"resourceIdentity"];
            NSString *expectedAsset=context[@"assetIdentity"];
            NSString *expectedPost=context[@"statusIdentity"];
            NSArray *expectedAssets=context[@"assetIdentities"] ?: (expectedAsset.length ? @[expectedAsset] : @[]);
            if (!view.window) { BHRDLogVideoResolution(@"unavailable",@{@"reason":@"detached_or_hidden_host"},attempt,session); return; }
            BHRDDownloadButton *handler = objc_getAssociatedObject(view, &BHFullscreenDownloadHandlerKey);
            if (!handler) {
                handler = [BHRDDownloadButton new];
                objc_setAssociatedObject(view, &BHFullscreenDownloadHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            __block BOOL cancelled=NO;
            BOOL (^stillCurrent)(void)=^BOOL {
                NSDictionary *now=BHRDCurrentFullscreenVideoContext(weakController);
                BOOL active=[BHRDFloatingVisibility(weakController) shouldDisplayEnabled:[BHRDManager DownloadingVideos] attached:weakController.viewIfLoaded.window!=nil];
                BOOL sameSelection=identity.length && [identity isEqual:now[@"identity"]];
                NSString *nowAsset=now[@"assetIdentity"];
                NSArray *nowAssets=now[@"assetIdentities"] ?: (nowAsset.length ? @[nowAsset] : @[]);
                BOOL sameAsset=expectedAsset.length && [expectedAsset isEqual:nowAsset];
                BOOL sameBoundResource=(nowAsset.length && [expectedAssets containsObject:nowAsset]) || (expectedAsset.length && [nowAssets containsObject:expectedAsset]);
                NSString *nowPost=now[@"statusIdentity"];
                BOOL postMatches=!expectedPost.length || !nowPost.length || [expectedPost isEqual:nowPost];
                BOOL same=active && postMatches && (sameAsset || (sameSelection && (!resource.length || [resource isEqual:now[@"resourceIdentity"]] || sameBoundResource)));
                if (!same && !cancelled) { cancelled=YES; BHRDLogVideoResolution(@"cancelled",@{@"reason":@"selection_changed"},attempt,session); }
                return same;
            };
            [handler presentDownloadOptionsForMediaEntities:media sourceView:view selectionStillCurrent:stillCurrent presented:^(BOOL shown) {
                if (!cancelled) BHRDLogVideoResolution(shown ? @"menu_presented" : @"unavailable",shown ? context : @{@"reason":@"menu_presentation_failed"},attempt,session);
            }];
        };
        router.showUnavailable = ^{ BHRDShowError(@"未能确认当前视频的播放资源。请重新打开视频后重试；若仍失败，可在实际运行验收页导出读取诊断。"); };
        objc_setAssociatedObject(controller, &BHRDFloatingRouterKey, router, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Video UI evidence controls visibility. Download URL/quality discovery is
    // performed only on tap and can never remove the user's download entry.
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
    BHRDRefreshFullscreenController(owner);
}

static void BHRemoveExtraFullscreenDownloadButtons(UIView *actionsView) {
    id model=BHRDMediaObject(actionsView,@"viewModel") ?: BHRDMediaObject(BHRDMediaObject(actionsView,@"delegate"),@"viewModel");
    BHRDRegisterFullscreenInlineModel(actionsView,model);
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
