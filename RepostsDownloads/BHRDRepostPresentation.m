#import "BHRDRepostPresentation.h"
#import "BHRDPreferences.h"
#import "BHRDConversationScope.h"
#import "BHRDAdFilter.h"
#import "BHRDContentFilter.h"
#import "BHRDAvatarDiagnostics.h"
#import "BHRDSafety.h"
#import "BHRDRuntimeStatus.h"
#import <objc/runtime.h>
#import <objc/message.h>
@protocol BHRDTimelineItems <NSObject>
- (NSArray *)sections;
- (void)setSections:(NSArray *)sections;
- (id)itemAtIndexPath:(NSIndexPath *)path;
@end

static char BHRDCellStateKey, BHRDReloadKey, BHRDForceReloadKey;
static void RetryAvatar(UITableViewCell *cell);
static void RefreshNativeAvatar(UITableViewCell *cell);
static void ResetDetailNavigation(UITableViewCell *cell);
static NSHashTable *Controllers(void) {
    static NSHashTable *controllers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}
static NSInteger Presentation(id controller, id model) {
    if (BHRDIsConversationContext(controller) || BHRDIsConversationContext(model)) return -1;
    [Controllers() addObject:controller];
    if (BHRDShouldHideRecommendation(model, controller)) return BHRDRepostModeHidden;
    if (BHRDPreference(BHRDHideAdsKey) && BHRDIsPromotedModel(model)) return BHRDRepostModeHidden;
    if (!BHRDPreference(BHRDHideRepostsKey) || !BHRDIsRepostModel(model)) return -1;
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
            NSArray *sections = [(id<BHRDTimelineItems>)current sections];
            NSArray *recommendations = BHRDFilterRecommendations(sections, current);
            NSArray *filtered = BHRDPreference(BHRDHideAdsKey) ? BHRDSectionsByRemovingAds(recommendations) : recommendations;
            if (BHRDPreference(BHRDHideRepostsKey) && BHRDCurrentRepostMode() == BHRDRepostModeHidden) filtered = BHRDSectionsByRemovingReposts(filtered);
            if (filtered != sections) {
                [(id<BHRDTimelineItems>)current setSections:filtered];
                changed = YES;
            }
        }
        // Reloading also recalculates row heights. No manual contentOffset or frame changes.
        if (changed || force) [UIView performWithoutAnimation:^{ [table reloadData]; }];
    });
}
void BHRDScheduleTimelineRefresh(id controller) { ScheduleRefresh(controller, YES); }
void BHRDRefreshHiddenReposts(void) {
    for (id controller in Controllers().allObjects) {
        BHRDScheduleTimelineRefresh(controller);
    }
}
void BHRDRepostPreferencesChanged(void) { BHRDRefreshHiddenReposts(); }
void BHRDRepostControllerDidAppear(id controller) {
    if (![Controllers() containsObject:controller] || BHRDIsConversationContext(controller)) return;
    UITableView *table=Table(controller);
    if (!table.window || ![controller respondsToSelector:@selector(itemAtIndexPath:)]) return;
    if (table.hasUncommittedUpdates) { ScheduleRefresh(controller,YES); return; }
    for (UITableViewCell *cell in table.visibleCells) {
        NSIndexPath *path=[table indexPathForCell:cell];
        id model=path ? [(id<BHRDTimelineItems>)controller itemAtIndexPath:path] : nil;
        if (model) { BHRDConfigureRepostCell(cell,model,controller); ResetDetailNavigation(cell); RetryAvatar(cell); }
    }
}
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
@interface BHRDRepostOverlay : UIControl
@property(nonatomic, strong) UILabel *title;
@property(nonatomic, strong) UIButton *show;
@property(nonatomic, strong) UIImageView *avatar;
@property(nonatomic, strong) UILabel *author;
@property(nonatomic, strong) UILabel *empty;
@property(nonatomic, strong) UIStackView *grid;
@end
@implementation BHRDRepostOverlay
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // Every visible part of the card has one action. Child labels, thumbnails
    // and the visual button cannot dispatch independent taps or host actions.
    return [super hitTest:point withEvent:event] ? self : nil;
}
- (BOOL)accessibilityActivate {
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
    return YES;
}
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
@property(nonatomic) BOOL refreshingMetadata;
@property(nonatomic) BOOL avatarLoading;
@property(nonatomic) BOOL avatarLoaded;
@property(nonatomic) NSUInteger avatarAttempts;
@property(nonatomic,strong) NSMapTable<UIView *, NSDictionary *> *nativeAvatarBaselines;
@property(nonatomic,strong) UIImage *nativeAvatarImage;
@property(nonatomic) NSTimeInterval nativeAvatarScanTime;
@property(nonatomic) BOOL imageCaptureQueued;
@property(nonatomic) BOOL openingDetails;
@property(nonatomic) BOOL originalClips;
@property(nonatomic) BOOL originalAccessible;
@property(nonatomic) UITableViewCellSelectionStyle selection;
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *hiddenViews;
@property(nonatomic, strong) UIView *overlay;
@property(nonatomic, strong) NSMutableArray<NSURLSessionDataTask *> *tasks;
@end
@implementation BHRDRepostCellState
- (void)openDetails {
    UITableViewCell *cell=self.cell; id controller=self.controller;
    if (self.openingDetails || !cell || objc_getAssociatedObject(cell,&BHRDCellStateKey)!=self ||
        (self.mode!=BHRDRepostModePreview && self.mode!=BHRDRepostModeBar) ||
        BHRDIsConversationContext(controller) || BHRDIsConversationContext(cell)) return;
    UITableView *table=Table(controller); NSIndexPath *path=[table indexPathForCell:cell];
    id model=path && [controller respondsToSelector:@selector(itemAtIndexPath:)] ? [(id<BHRDTimelineItems>)controller itemAtIndexPath:path] : nil;
    if (!table.window || table.hasUncommittedUpdates || ![BHRDRepostIdentity(model) isEqual:self.identity]) {
        BHRDAvatarLog(@"repost_detail_navigation",@{@"row":self.identity ?: @"",@"result":@"stale_or_unavailable_row"}); return;
    }
    SEL select=NSSelectorFromString(@"tableView:didSelectRowAtIndexPath:");
    id target=table.delegate;
    if (![target respondsToSelector:select]) target=controller;
    NSMethodSignature *sig=[target respondsToSelector:select] ? [target methodSignatureForSelector:select] : nil;
    if (sig.numberOfArguments!=4 || sig.methodReturnType[0]!='v' ||
        [sig getArgumentTypeAtIndex:2][0]!='@' || [sig getArgumentTypeAtIndex:3][0]!='@') {
        BHRDRecordCapability(@"帖子详情导航",@"不可用",@"当前行委托未提供签名匹配的原生选择方法");
        BHRDAvatarLog(@"repost_detail_navigation",@{@"row":self.identity ?: @"",@"result":@"native_selection_unavailable"}); return;
    }
    self.openingDetails=YES;
    [table selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    ((void(*)(id,SEL,id,id))objc_msgSend)(target,select,table,path);
    BHRDRecordCapability(@"帖子详情导航",@"已调用",[@"原生选择目标：" stringByAppendingString:NSStringFromClass([target class])]);
    BHRDAvatarLog(@"repost_detail_navigation",@{@"row":self.identity ?: @"",@"result":@"native_row_selection",@"targetClass":NSStringFromClass([target class])});
    __weak BHRDRepostCellState *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.6*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ weakSelf.openingDetails=NO; });
}
@end
static void ResetDetailNavigation(UITableViewCell *cell) {
    BHRDRepostCellState *state=objc_getAssociatedObject(cell,&BHRDCellStateKey);
    state.openingDetails=NO;
}
void BHRDRepostMetadataChanged(void) {
    // Coalesce related network responses and only reconfigure visible previews.
    // Their row geometry is unchanged, so a full table reload is unnecessary.
    dispatch_async(dispatch_get_main_queue(), ^{
        static BOOL scheduled = NO;
        if (scheduled || !BHRDPreference(BHRDHideRepostsKey) || BHRDCurrentRepostMode() != BHRDRepostModePreview) return;
        scheduled = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            scheduled = NO;
            if (!BHRDPreference(BHRDHideRepostsKey) || BHRDCurrentRepostMode() != BHRDRepostModePreview) return;
            for (id controller in Controllers().allObjects) {
                UITableView *table = Table(controller);
                if (!table.window || ![controller respondsToSelector:@selector(itemAtIndexPath:)]) continue;
                if (table.hasUncommittedUpdates) { BHRDRepostMetadataChanged(); continue; }
                for (UITableViewCell *cell in table.visibleCells) {
                    BHRDRepostCellState *state = objc_getAssociatedObject(cell, &BHRDCellStateKey);
                    if (state.controller != controller || state.mode != BHRDRepostModePreview) continue;
                    NSIndexPath *indexPath = [table indexPathForCell:cell];
                    id model = indexPath ? [(id<BHRDTimelineItems>)controller itemAtIndexPath:indexPath] : nil;
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
static char ImageRequestKey;
static char NativeAvatarAssignmentKey;
static char NativeAvatarLayerImageKey;
static id AvatarObject(id object,NSString *key) {
    if (!object) return nil;
    @try {
        SEL selector=NSSelectorFromString(key);
        if (![object respondsToSelector:selector]) return nil;
        NSMethodSignature *signature=[object methodSignatureForSelector:selector];
        if (signature.numberOfArguments!=2 || signature.methodReturnType[0]!='@') return nil;
        return ((id(*)(id,SEL))objc_msgSend)(object,selector);
    } @catch (__unused NSException *exception) { return nil; }
}
static BOOL IsNativeAvatar(UIView *view) {
    for (Class cls=view.class; cls && cls!=UIView.class; cls=class_getSuperclass(cls))
        if ([NSStringFromClass(cls) isEqual:@"TUIAvatarImageView"]) return YES;
    return NO;
}
static BHRDRepostInfo *NativeAvatarOwner(UIView *view) {
    BHRDRepostInfo *user=BHRDRepostAuthorForUser(AvatarObject(view,@"user"));
    BHRDRepostInfo *model=BHRDRepostAuthorForUser(AvatarObject(view,@"userViewModel"));
    if (BHRDRepostAuthorKey(user) && BHRDRepostAuthorKey(model) && !BHRDRepostAuthorsMatch(user,model)) return nil;
    return BHRDRepostAuthorKey(user) ? user : model;
}
static UIImage *NativeAvatarImage(UIView *view) {
    id image=AvatarObject(view,@"image");
    if ([image isKindOfClass:UIImage.class]) return image;
    id contents=view.layer.contents;
    if (contents && CFGetTypeID((__bridge CFTypeRef)contents)==CGImageGetTypeID()) {
        NSDictionary *cached=objc_getAssociatedObject(view,&NativeAvatarLayerImageKey);
        if (cached[@"contents"]==contents) return cached[@"image"];
        UIImage *decoded=[UIImage imageWithCGImage:(__bridge CGImageRef)contents];
        if (decoded) objc_setAssociatedObject(view,&NativeAvatarLayerImageKey,@{@"contents":contents,@"image":decoded},OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return decoded;
    }
    objc_setAssociatedObject(view,&NativeAvatarLayerImageKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return nil;
}
static void RefreshNativeAvatar(UITableViewCell *cell) {
    BHRDRepostCellState *state=objc_getAssociatedObject(cell,&BHRDCellStateKey);
    if (!state || state.mode!=BHRDRepostModePreview || state.avatarURL || !BHRDRepostAuthorKey(state.info) || !cell.window) return;
    // Verify the current row again before consuming delayed native pixels.
    UITableView *table=Table(state.controller); NSIndexPath *path=[table indexPathForCell:cell];
    if (!path || ![state.controller respondsToSelector:@selector(itemAtIndexPath:)]) return;
    id model=[(id<BHRDTimelineItems>)state.controller itemAtIndexPath:path];
    BHRDRepostInfo *current=BHRDInfoForRepostModel(model);
    if (![state.identity isEqual:BHRDRepostIdentity(model)] || !BHRDRepostAuthorsMatch(state.info,current) ||
        ![(current.postIdentifier ?: @"") isEqual:(state.info.postIdentifier ?: @"")]) return;
    NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;
    if (now-state.nativeAvatarScanTime<0.1) return;
    state.nativeAvatarScanTime=now;
    if (!state.nativeAvatarBaselines) state.nativeAvatarBaselines=[NSMapTable weakToStrongObjectsMapTable];
    NSMutableArray *pending=[NSMutableArray arrayWithArray:cell.subviews]; NSUInteger budget=160;
    while (pending.count && budget--) {
        UIView *view=pending.firstObject; [pending removeObjectAtIndex:0];
        if ([view isKindOfClass:BHRDRepostOverlay.class]) continue;
        NSString *name=NSStringFromClass(view.class).lowercaseString;
        if ([name containsString:@"quote"] || [name containsString:@"attachment"] || [name containsString:@"mediagrid"]) continue;
        if (IsNativeAvatar(view)) {
            BHRDRepostInfo *owner=NativeAvatarOwner(view);
            UIImage *image=NativeAvatarImage(view);
            NSDictionary *baseline=[state.nativeAvatarBaselines objectForKey:view];
            if (!baseline || !BHRDRepostAuthorsMatch(baseline[@"owner"],owner)) {
                baseline=@{@"image":image ?: NSNull.null,@"owner":owner ?: [BHRDRepostInfo new]};
                [state.nativeAvatarBaselines setObject:baseline forKey:view];
            }
            CGRect rect=[view convertRect:view.bounds toView:cell];
            BOOL header=rect.origin.x>=0 && rect.origin.x<90 && rect.origin.y>=0 && rect.origin.y<150 && rect.size.width>=24 && rect.size.width<=90 && rect.size.height>=24 && rect.size.height<=90;
            BOOL matches=BHRDRepostAuthorsMatch(owner,state.info);
            NSDictionary *assignment=objc_getAssociatedObject(view,&NativeAvatarAssignmentKey);
            BOOL stamped=assignment[@"image"]==image && BHRDRepostAuthorsMatch(assignment[@"owner"],state.info);
            BOOL fresh=baseline[@"image"]!=image && BHRDRepostAuthorsMatch(baseline[@"owner"],state.info);
            // Matching labels/geometry alone never prove image ownership. A
            // fresh bitmap must arrive while this native view belongs to the
            // same original author, or carry an image-assignment identity stamp.
            if (header && matches && image && (stamped || fresh)) {
                if (state.nativeAvatarImage!=image) {
                    state.nativeAvatarImage=image; state.avatarLoaded=YES;
                    [(BHRDRepostOverlay *)state.overlay avatar].image=image;
                    BHRDAvatarLog(@"native_avatar_assigned",@{@"row":state.identity,@"handle":state.info.authorHandle ?: @"",@"source":@"TUIAvatarImageView",@"stamped":@(stamped),@"fresh":@(fresh),@"result":@"identity_verified_native_image"});
                }
                return;
            }
            BHRDAvatarLog(@"native_avatar_candidate",@{@"row":state.identity,@"handle":state.info.authorHandle ?: @"",@"ownerID":owner.authorIdentifier ?: @"",@"ownerHandle":owner.authorHandle ?: @"",@"matches":@(matches),@"header":@(header),@"hasImage":@(image!=nil),@"stamped":@(stamped),@"fresh":@(fresh)});
        }
        if (pending.count<160) [pending addObjectsFromArray:view.subviews];
    }
}
static void LoadImage(NSURL *url, UIImageView *view, BHRDRepostCellState *state) {
    if (!url) {
        if (view==[(BHRDRepostOverlay *)state.overlay avatar]) BHRDAvatarLog(@"avatar_missing_url",@{@"row":state.identity ?: @"",@"handle":state.info.authorHandle ?: @"",@"result":@"placeholder_no_request"});
        return;
    }
    NSString *request=NSUUID.UUID.UUIDString;
    objc_setAssociatedObject(view,&ImageRequestKey,request,OBJC_ASSOCIATION_COPY_NONATOMIC);
    BOOL avatar=view==[(BHRDRepostOverlay *)state.overlay avatar];
    UIImage *image = [ImageCache() objectForKey:url.absoluteString];
    if (image) {
        view.image = image;
        if (avatar) {
            state.avatarLoaded=YES; state.avatarLoading=NO;
            BHRDAvatarLog(@"avatar_cache_hit",@{@"row":state.identity ?: @"",@"handle":state.info.authorHandle ?: @"",@"url":BHRDAvatarDiagnosticURL(url),@"result":@"decoded_image_assigned"});
        }
        return;
    }
    if (avatar) { state.avatarLoading=YES; state.avatarLoaded=NO; state.avatarAttempts++; }
    if (avatar) BHRDAvatarLog(@"avatar_request_start",@{@"row":state.identity ?: @"",@"handle":state.info.authorHandle ?: @"",@"url":BHRDAvatarDiagnosticURL(url),@"request":request,@"attempt":@(state.avatarAttempts),@"loading":@YES});
    __weak BHRDRepostCellState *weakState = state;
    __weak UIImageView *weakView = view;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL httpOK=![response isKindOfClass:NSHTTPURLResponse.class] || ([(NSHTTPURLResponse *)response statusCode]>=200 && [(NSHTTPURLResponse *)response statusCode]<300);
        NSString *mime=response.MIMEType.lowercaseString;
        BOOL imageResponse=!mime.length || [mime hasPrefix:@"image/"] || [mime isEqual:@"application/octet-stream"];
        UIImage *downloaded = !error && httpOK && imageResponse && data.length>0 && data.length<=8*1024*1024 ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            BHRDRepostCellState *current = weakState;
            if (avatar) BHRDAvatarLog(@"avatar_response",@{@"row":current.identity ?: @"released",@"handle":current.info.authorHandle ?: @"",@"request":request,@"url":BHRDAvatarDiagnosticURL(url),@"finalURL":BHRDAvatarDiagnosticURL(response.URL),@"http":@([response isKindOfClass:NSHTTPURLResponse.class] ? [(NSHTTPURLResponse *)response statusCode] : 0),@"mime":mime ?: @"",@"bytes":@(data.length),@"decoded":@(downloaded!=nil),@"errorDomain":error.domain ?: @"",@"errorCode":@(error.code),@"cancelled":@(error.code==NSURLErrorCancelled),@"current":@(current && objc_getAssociatedObject(current.cell,&BHRDCellStateKey)==current && [objc_getAssociatedObject(weakView,&ImageRequestKey) isEqual:request])});
            // Reused cells must never display the previous tweet's asynchronous image.
            if (current && objc_getAssociatedObject(current.cell, &BHRDCellStateKey) == current &&
                [objc_getAssociatedObject(weakView,&ImageRequestKey) isEqual:request]) {
                if (avatar) { current.avatarLoading=NO; current.avatarLoaded=downloaded!=nil; }
                if (downloaded) {
                    [ImageCache() setObject:downloaded forKey:url.absoluteString cost:downloaded.size.width * downloaded.size.height * 4];
                    weakView.image = downloaded;
                    if (avatar) BHRDAvatarLog(@"avatar_assigned",@{@"row":current.identity ?: @"",@"handle":current.info.authorHandle ?: @"",@"request":request,@"result":@"decoded_image",@"loaded":@(current.avatarLoaded),@"loading":@(current.avatarLoading)});
                } else if (avatar && current.avatarAttempts<3) {
                    // Recover transient failures while the row stays onscreen.
                    // A reused row or newer request invalidates this retry too.
                    NSTimeInterval delay=current.avatarAttempts==1 ? 1.0 : 3.0;
                    BHRDAvatarLog(@"avatar_retry_scheduled",@{@"row":current.identity ?: @"",@"handle":current.info.authorHandle ?: @"",@"request":request,@"attempt":@(current.avatarAttempts),@"delay":@(delay)});
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                        BHRDRepostCellState *retry=weakState;
                        if (retry.cell.window && objc_getAssociatedObject(retry.cell,&BHRDCellStateKey)==retry &&
                            [objc_getAssociatedObject(weakView,&ImageRequestKey) isEqual:request]) RetryAvatar(retry.cell);
                    });
                } else if (avatar) {
                    BHRDAvatarLog(@"avatar_retries_exhausted",@{@"row":current.identity ?: @"",@"handle":current.info.authorHandle ?: @"",@"attempts":@(current.avatarAttempts),@"result":@"placeholder"});
                }
            }
        });
    }];
    [state.tasks addObject:task];
    [task resume];
}
static void RetryAvatar(UITableViewCell *cell) {
    BHRDRepostCellState *state=objc_getAssociatedObject(cell,&BHRDCellStateKey);
    if (state.mode==BHRDRepostModePreview && state.avatarURL && !state.avatarLoaded && !state.avatarLoading)
        LoadImage(state.avatarURL,[(BHRDRepostOverlay *)state.overlay avatar],state);
}
static UILabel *Label(NSString *text, CGFloat size, UIColor *color) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}
static void RefreshPreviewMetadata(BHRDRepostCellState *state) {
    if (state.mode != BHRDRepostModePreview || !state.cell || state.refreshingMetadata || BHRDIsConversationContext(state.controller)) return;
    UITableView *table = Table(state.controller);
    NSIndexPath *path = [table indexPathForCell:state.cell];
    if (!path || ![state.controller respondsToSelector:@selector(itemAtIndexPath:)]) return;
    id model=[(id<BHRDTimelineItems>)state.controller itemAtIndexPath:path];
    if (![BHRDRepostIdentity(model) isEqual:state.identity]) return;
    BHRDRepostInfo *info=BHRDInfoForRepostModel(model);
    BOOL sameAuthor=[(BHRDRepostAuthorKey(info) ?: @"") isEqual:(BHRDRepostAuthorKey(state.info) ?: @"")];
    if (sameAuthor && [state.author isEqual:info.author] &&
        (state.avatarURL==info.avatar || [state.avatarURL isEqual:info.avatar]) &&
        [state.thumbnailURLs isEqual:info.thumbnails] &&
        [(state.info.postIdentifier ?: @"") isEqual:(info.postIdentifier ?: @"")]) return;
    state.refreshingMetadata=YES;
    BHRDConfigureRepostCell(state.cell,model,state.controller);
    state.refreshingMetadata=NO;
}
static void ScheduleMetadataRefresh(BHRDRepostCellState *state) {
    if (state.mode != BHRDRepostModePreview) return;
    __weak BHRDRepostCellState *weakState = state;
    // Native author models may be hydrated after cellForRow returns.
    // Bounded retries complement layout callbacks; never retain/reload the row.
    if (!state.avatarURL) BHRDAvatarLog(@"native_avatar_poll_scheduled",@{@"row":state.identity ?: @"",@"handle":state.info.authorHandle ?: @"",@"delays":@[@0.15,@0.6,@1.5,@2.5,@4.0,@7.0,@12.0]});
    for (NSNumber *delay in @[@0.15, @0.6, @1.5, @2.5, @4.0, @7.0, @12.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BHRDRepostCellState *current = weakState;
            if (current.cell.window && objc_getAssociatedObject(current.cell, &BHRDCellStateKey) == current) {
                RefreshPreviewMetadata(current);
                RefreshNativeAvatar(current.cell);
#if BHRD_AVATAR_DIAGNOSTICS
                if (delay.doubleValue>=1.5) {
                    BHRDAvatarLog(@"overlay_state",@{@"row":current.identity ?: @"",@"handle":current.info.authorHandle ?: @"",@"url":BHRDAvatarDiagnosticURL(current.avatarURL),@"loaded":@(current.avatarLoaded),@"loading":@(current.avatarLoading),@"attempts":@(current.avatarAttempts),@"active":@(objc_getAssociatedObject(current.cell,&BHRDCellStateKey)==current),@"result":current.avatarLoaded ? @"decoded_image" : @"placeholder"});
                    BHRDAvatarInspectView(current.cell,current.identity);
                    UITableView *table=Table(current.controller); NSIndexPath *path=[table indexPathForCell:current.cell];
                    if (path && [current.controller respondsToSelector:@selector(itemAtIndexPath:)]) BHRDAvatarInspectModel([(id<BHRDTimelineItems>)current.controller itemAtIndexPath:path],current.identity);
                }
#endif
            }
        });
    }
}
void BHRDRepostNativeImageChanged(UIImageView *view) {
    if (!BHRDTweakEnabled()) return;
    if (!NSThread.isMainThread) return;
    if (IsNativeAvatar(view)) {
        BHRDRepostInfo *owner=NativeAvatarOwner(view); UIImage *image=NativeAvatarImage(view);
        objc_setAssociatedObject(view,&NativeAvatarAssignmentKey,(image && BHRDRepostAuthorKey(owner)) ? @{@"image":image,@"owner":owner} : nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
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
            if (current && objc_getAssociatedObject(current.cell, &BHRDCellStateKey) == current) {
                RefreshPreviewMetadata(current); current.nativeAvatarScanTime=0; RefreshNativeAvatar(current.cell);
            }
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
    RefreshPreviewMetadata(state);
    state=objc_getAssociatedObject(cell,&BHRDCellStateKey);
    if (!state) return;
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
    RefreshNativeAvatar(cell);
}
void BHRDConfigureRepostCell(UITableViewCell *cell, id model, id controller) {
    if (![cell isKindOfClass:UITableViewCell.class]) return;
    NSInteger mode = BHRDIsConversationContext(cell) ? -1 : Presentation(controller, model);
    BHRDRepostCellState *old = objc_getAssociatedObject(cell, &BHRDCellStateKey);
    NSString *identity = mode < 0 ? nil : BHRDRepostIdentity(model);
    BHRDRepostInfo *info = mode == BHRDRepostModePreview ? BHRDInfoForRepostModel(model) : nil;
    BOOL sameIdentity = old && old.controller == controller && [old.identity isEqual:identity];
    // The native header/UIImageView may still belong to the previous row.
    // Preview identity and avatar URL come only from the bound model snapshot.
    // A reused identity can receive fuller metadata later. Keep value snapshots so
    // an earlier placeholder cannot mask an updated author, avatar or media list.
    BOOL samePreview = mode != BHRDRepostModePreview ||
        ([old.author isEqual:info.author] &&
         [(BHRDRepostAuthorKey(old.info) ?: @"") isEqual:(BHRDRepostAuthorKey(info) ?: @"")] &&
         [(old.info.postIdentifier ?: @"") isEqual:(info.postIdentifier ?: @"")] &&
         (old.avatarURL == info.avatar || [old.avatarURL isEqual:info.avatar]) &&
         [old.thumbnailURLs isEqual:info.thumbnails]);
    if (sameIdentity && old.mode == mode && samePreview) { old.info=info; BHRDLayoutRepostCell(cell); return; }
    if (mode==BHRDRepostModePreview) {
        BHRDAvatarLog(@"preview_resolved",@{@"row":identity ?: @"",@"post":info.postIdentifier ?: @"",@"handle":info.authorHandle ?: @"",@"authorID":info.authorIdentifier ?: @"",@"priority":@(info.authorPriority),@"avatarURL":BHRDAvatarDiagnosticURL(info.avatar),@"cellClass":NSStringFromClass(cell.class),@"modelClass":NSStringFromClass([model class]),@"result":info.avatar ? @"model_url_found" : @"model_url_missing"});
        BHRDAvatarInspectModel(model,identity);
        BHRDAvatarInspectView(cell,identity);
    }
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
    if (mode==BHRDRepostModePreview || mode==BHRDRepostModeBar) {
        [overlay addTarget:state action:@selector(openDetails) forControlEvents:UIControlEventTouchUpInside];
        overlay.isAccessibilityElement=YES;
        overlay.accessibilityTraits=UIAccessibilityTraitButton;
        overlay.accessibilityLabel=info.author.length ? [@"已隐藏一条转推，" stringByAppendingString:info.author] : @"已隐藏一条转推";
        overlay.accessibilityHint=@"打开帖子详情，返回后仍保持隐藏";
    }
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
        [show setTitle:@"查看详情" forState:UIControlStateNormal];
        show.frame = CGRectMake(cell.bounds.size.width - 104, 10, 88, 40);
        show.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        show.userInteractionEnabled=NO;
        overlay.show = show;
        [overlay addSubview:show];
        if (mode == BHRDRepostModePreview) {
            UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 54, 28, 28)];
            avatar.image = [UIImage systemImageNamed:@"person.crop.circle"];
            avatar.contentMode = UIViewContentModeScaleAspectFill;
            avatar.layer.cornerRadius = 14;
            avatar.clipsToBounds = YES;
            overlay.avatar = avatar;
            [overlay addSubview:avatar];
            LoadImage(info.avatar, avatar, state);
            UILabel *author = Label(info.author, 13, UIColor.labelColor);
            author.frame = CGRectMake(52, 54, MAX(60, cell.bounds.size.width - 68), 28);
            author.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            overlay.author = author;
            [overlay addSubview:author];
            if (!info.thumbnails.count) {
                UILabel *empty = Label(@"暂无媒体缩略图，点按查看帖子详情", 12, UIColor.secondaryLabelColor);
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
                    thumb.userInteractionEnabled = NO;
                    [grid addArrangedSubview:thumb];
                    LoadImage(url, thumb, state);
                }
            }
        }
    }
    BHRDLayoutRepostCell(cell);
    ScheduleMetadataRefresh(state);
}
