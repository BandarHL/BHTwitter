//
//  BHRDDownloadButton.m
//  BHTwitter
//
//  Original author: BandarHelal at 09/04/2022
//  Modified by: actuallyaridan at 27/04/2025
//

#import "BHRDDownloadButton.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "BHRDDownload.h"
#import "BHRDInlineButtonStyle.h"
#import "BHRDMediaResolver.h"
#import "BHRDDownloadProgress.h"
#import "BHRDStreamJob.h"
#import "BHRDDownloadStore.h"
#import "BHRDStrings.h"
#import "../ffmpeg/MediaInformation.h"

#pragma mark - Helpers
static inline UIViewController *BHTopMostController(void) {
    return BHRDTopViewController();
}

static inline id BHTObjectForSelector(id object, SEL selector) { return BHRDMediaObject(object, NSStringFromSelector(selector)); }
static inline NSArray *BHTArrayForSelector(id object, SEL selector) {
    id value = BHTObjectForSelector(object, selector);
    return [value isKindOfClass:NSArray.class] ? value : nil;
}

static char kHitTestEdgeInsetsKey;   // associated‑object key

// Convenience shim to invoke a superclass selector that isn’t visible at compile‑time
static void _bh_callSuperIfPossible(__unsafe_unretained id self,
                                    SEL sel,
                                    id  a1,
                                    NSUInteger a2,
                                    NSUInteger a3,
                                    BOOL a4,
                                    id  a5)
{
    struct objc_super sup = { .receiver = self, .super_class = class_getSuperclass(object_getClass(self)) };
    if (class_getInstanceMethod(sup.super_class, sel)) {
        ((void (*)(struct objc_super *, SEL, id, NSUInteger, NSUInteger, BOOL, id))objc_msgSendSuper)(&sup, sel, a1, a2, a3, a4, a5);
    }
}

#pragma mark - BHRDDownloadButton
@interface BHRDDownloadButton () <BHRDDownloadDelegate>
@property (nonatomic, strong) JGProgressHUD *hud;
@property (nonatomic, strong) BHRDDownload *downloadManager;
@property (nonatomic, strong) BHRDStreamJob *streamJob;
@end

@implementation BHRDDownloadButton

+ (NSArray *)downloadableMediaEntitiesFromSource:(id)source { return BHRDResolveMedia(source); }
- (void)setViewModel:(id)model {
    _viewModel = model;
    BHRDRememberMedia(model);
}

#pragma mark ••• Class helpers
+ (CGSize)buttonImageSizeUsingViewModel:(id)viewModel
                                options:(NSUInteger)options
                      overrideButtonSize:(CGSize)overrideSize
                                 account:(id)account
{
    return CGSizeZero; // let host lay the image out
}

#pragma mark ••• Status updates
- (void)statusDidUpdate:(id)status
                options:(NSUInteger)options
     displayTextOptions:(NSUInteger)textOptions
               animated:(BOOL)animated
        featureSwitches:(id)featureSwitches
{
    _bh_callSuperIfPossible(self, _cmd, status, options, textOptions, animated, featureSwitches);
    BHRDRememberMedia(status);
    [self _bh_applyTint];
}

- (void)statusDidUpdate:(id)status
                options:(NSUInteger)options
     displayTextOptions:(NSUInteger)textOptions
               animated:(BOOL)animated
{
    _bh_callSuperIfPossible(self, _cmd, status, options, textOptions, animated, nil);
    BHRDRememberMedia(status);
    [self _bh_applyTint];
}

- (void)_bh_applyTint { BHRDRefreshCustomInlineTint(self); }
- (void)layoutSubviews { [super layoutSubviews]; BHRDLayoutCustomInlineGlyph(self); }

#pragma mark ••• Init
- (instancetype)initWithOptions:(NSUInteger)options overrideSize:(id)overrideSize account:(id)account {
    if ((self = [super initWithFrame:CGRectZero])) {
        [self _bh_commonInitWithInlineType:131];
    }
    return self;
}

- (instancetype)initWithInlineActionType:(NSUInteger)actionType
                                 options:(NSUInteger)options
                              overrideSize:(id)overrideSize
                                 account:(id)account
{
    if ((self = [super initWithFrame:CGRectZero])) {
        [self _bh_commonInitWithInlineType:actionType];
    }
    return self;
}

- (void)_bh_commonInitWithInlineType:(NSUInteger)type {
    self.inlineActionType = type;
    BHRDRefreshCustomInlineTint(self);
    self.accessibilityLabel = @"下载视频与动图";
    [self setImage:BHRDInlineButtonGlyph(NO) forState:UIControlStateNormal];
    [self addTarget:self action:@selector(DownloadHandler:) forControlEvents:UIControlEventTouchUpInside];
}

// Twitter asks subclasses (+ class) for a custom glyph via this selector.
- (id)_t1_imageNamed:(id)name fitSize:(CGSize)size fillColor:(id)fill { return nil; }
+ (id)_t1_imageNamed:(id)name fitSize:(CGSize)size fillColor:(id)fill { return nil; }

#pragma mark ••• Hit‑testing tweaks
- (void)setTouchInsets:(UIEdgeInsets)insets {
    _touchInsets = insets;
    if ([self.delegate.delegate isKindOfClass:objc_getClass("T1StandardStatusInlineActionsViewAdapter")]) {
        self.imageEdgeInsets = UIEdgeInsetsZero;
        [self setHitTestEdgeInsets:insets];
    }
}

- (void)setHitTestEdgeInsets:(UIEdgeInsets)insets {
    objc_setAssociatedObject(self, &kHitTestEdgeInsetsKey,
                             [NSValue value:&insets withObjCType:@encode(UIEdgeInsets)],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)hitTestEdgeInsets {
    NSValue *val = objc_getAssociatedObject(self, &kHitTestEdgeInsetsKey);
    if (val) { UIEdgeInsets e; [val getValue:&e]; return e; }
    return UIEdgeInsetsZero;
}

- (BOOL)pointInside:(CGPoint)pt withEvent:(UIEvent *)evt {
    if (UIEdgeInsetsEqualToEdgeInsets(self.hitTestEdgeInsets, UIEdgeInsetsZero) || !self.enabled || self.isHidden) {
        return [super pointInside:pt withEvent:evt];
    }
    return CGRectContainsPoint(UIEdgeInsetsInsetRect(self.bounds, self.hitTestEdgeInsets), pt);
}

#pragma mark ••• Inline‑action metrics (instance + class)
#define BH_METRIC(name, value) \
    - (typeof(value))name { return value; } \
    + (typeof(value))name { return value; }

BH_METRIC(extraWidth,                 40.0)
BH_METRIC(extraWidthWithStyle,        40.0)
BH_METRIC(horizontalLayoutOffset,      0.0)
BH_METRIC(trailingEdgeInset,          6.0)
BH_METRIC(visibility, (NSUInteger)1)
BH_METRIC(alternateInlineActionType, (NSUInteger)6)
BH_METRIC(touchInsetPriority, (NSUInteger)2)
BH_METRIC(shouldShowCount,            NO)
- (NSUInteger)displayType { return _displayType; }
+ (NSUInteger)displayType { return 0; }

#undef BH_METRIC

#pragma mark ••• Download handler
- (void)DownloadHandler:(UIButton *)sender {
    NSMutableArray *mediaEntities = [NSMutableArray array];
    for (id source in @[self.viewModel ?: NSNull.null,
                        self.delegate ?: NSNull.null]) {
        for (id media in [BHRDDownloadButton downloadableMediaEntitiesFromSource:source]) {
            if (![mediaEntities containsObject:media]) {
                [mediaEntities addObject:media];
            }
        }
    }

    [self presentDownloadOptionsForMediaEntities:mediaEntities sourceView:sender];
}

- (void)presentDownloadOptionsForMediaEntities:(NSArray *)mediaEntities
                                    sourceView:(UIView *)sourceView {
    [self presentDownloadOptionsForMediaEntities:mediaEntities sourceView:sourceView selectionStillCurrent:nil presented:nil];
}
- (void)presentDownloadOptionsForMediaEntities:(NSArray *)mediaEntities sourceView:(UIView *)sourceView
                         selectionStillCurrent:(BOOL (^)(void))selectionStillCurrent presented:(void (^)(BOOL))presented {
    if (![BHRDManager DownloadingVideos] || (selectionStillCurrent && !selectionStillCurrent())) { if (presented) presented(NO); return; }
    if (self.downloadManager || self.streamJob) { if (presented) presented(NO); BHRDShowError(@"当前任务仍在进行，可点击底部进度提示取消后重试。"); return; }
    @try {
        NSString *menuTitle = [BHRDLocalized(@"DOWNLOAD_MENU_TITLE")
                               stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:menuTitle
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];

        NSMutableArray<NSArray *> *variantGroups = [NSMutableArray array];
        for (id media in mediaEntities) {
            id videoInfo = BHTObjectForSelector(media, @selector(videoInfo));
            NSArray *variants = BHTArrayForSelector(videoInfo, @selector(variants));
            if (variants.count > 0) [variantGroups addObject:variants];
        }

        BOOL hasDownloadOption = NO;
        for (NSUInteger groupIndex = 0; groupIndex < variantGroups.count; groupIndex++) {
            for (id variant in variantGroups[groupIndex]) {
                id contentTypeValue = BHTObjectForSelector(variant, @selector(contentType));
                if (![contentTypeValue isKindOfClass:NSString.class]) continue;
                NSString *contentType = contentTypeValue;

                id urlValue = BHTObjectForSelector(variant, @selector(url));
                NSURL *url = nil;
                if ([urlValue isKindOfClass:NSURL.class]) {
                    url = urlValue;
                } else if ([urlValue isKindOfClass:NSString.class] && [urlValue length] > 0) {
                    url = [NSURL URLWithString:urlValue];
                }

                if (url == nil || ![@[@"https", @"http"] containsObject:url.scheme.lowercaseString]) continue;
                NSString *urlString = url.absoluteString;

                NSString *optionTitle = nil;
                if ([contentType isEqualToString:@"video/mp4"]) {
                    optionTitle = [BHRDManager getVideoQuality:urlString];
                } else if (([contentType.lowercaseString isEqualToString:@"application/x-mpegurl"] || [contentType.lowercaseString isEqualToString:@"application/vnd.apple.mpegurl"])) {
                    optionTitle = BHRDLocalized(@"FFMPEG_DOWNLOAD_OPTION_TITLE");
                } else {
                    continue;
                }

                if (variantGroups.count > 1) {
                    optionTitle = [NSString stringWithFormat:@"视频 %lu · %@", (unsigned long)groupIndex + 1, optionTitle];
                }

                UIAlertAction *action;
                if ([contentType isEqualToString:@"video/mp4"]) {
                    action = [UIAlertAction actionWithTitle:optionTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *selectedAction) {
                        if (selectionStillCurrent && !selectionStillCurrent()) { BHRDShowError(@"视频已切换，请重新打开当前视频的下载菜单。"); return; }
                        if (![BHRDManager DownloadingVideos] || self.downloadManager) return;
                        self.downloadManager = [[BHRDDownload alloc] init];
                        [self.downloadManager setDelegate:self];
                        __weak BHRDDownloadButton *weakSelf = self;
                        self.hud = BHRDShowDownloadProgress(@"正在下载视频…", ^{ [weakSelf.downloadManager cancel]; });
                        [self.downloadManager downloadFileWithURL:url];
                    }];
                } else {
                    action = [UIAlertAction actionWithTitle:optionTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *selectedAction) {
                        if (selectionStillCurrent && !selectionStillCurrent()) { BHRDShowError(@"视频已切换，请重新打开当前视频的下载菜单。"); return; }
                        if (![BHRDManager DownloadingVideos]) return;
                        if (self.downloadManager || self.streamJob) return;
                        self.streamJob = [BHRDStreamJob probeURL:url completion:^(MediaInformation *info, NSError *error) {
                            self.streamJob = nil;
                            if (selectionStillCurrent && !selectionStillCurrent()) return;
                            if (error) {
                                if (error.code != NSURLErrorCancelled) BHRDShowError([error.domain isEqual:@"BHRDBusy"] ? @"已有下载任务进行中，请等待完成或点击进度提示取消。" : @"无法读取流媒体清晰度，可能是网络中断或等待超时，请重试。");
                                return;
                            }
                            UIAlertController *ffmpegSheet = [BHRDManager newFFmpegDownloadSheet:info downloadingURL:url selection:^(NSNumber *index) {
                                if (selectionStillCurrent && !selectionStillCurrent()) { BHRDShowError(@"视频已切换，请重新打开当前视频的下载菜单。"); return; }
                                if (self.downloadManager || self.streamJob || ![BHRDManager DownloadingVideos]) return;
                                self.streamJob = [BHRDStreamJob downloadURL:url streamIndex:index completion:^{ self.streamJob = nil; }];
                            }];
                            UIView *anchor = sourceView.window ? sourceView : BHTopMostController().view;
                            ffmpegSheet.popoverPresentationController.sourceView = anchor;
                            ffmpegSheet.popoverPresentationController.sourceRect = anchor.bounds;
                            [BHTopMostController() presentViewController:ffmpegSheet animated:YES completion:nil];
                        }];
                    }];
                }

                [sheet addAction:action];
                hasDownloadOption = YES;
            }
        }

        if (!hasDownloadOption) {
            [NSException raise:NSInvalidArgumentException format:@"没有找到可下载的视频，请打开视频或刷新推文后重试。"];
        }

        [sheet addAction:[UIAlertAction actionWithTitle:BHRDLocalized(@"CANCEL_BUTTON_TITLE")
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        sheet.popoverPresentationController.sourceView = sourceView;
        sheet.popoverPresentationController.sourceRect = sourceView.bounds;
        UIViewController *owner=BHTopMostController();
        if (!owner.view.window || owner.presentedViewController || [owner isKindOfClass:UIAlertController.class]) { if (presented) presented(NO); return; }
        [owner presentViewController:sheet animated:YES completion:^{ if (presented) presented(sheet.presentingViewController!=nil && sheet.view.window!=nil); }];
    } @catch (NSException *ex) {
        if (presented) presented(NO);
        NSLog(@"[BHTwitter] 加载视频下载选项失败：%@\n%@", ex, ex.callStackSymbols);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"X 随心"
                                                                       message:@"无法加载下载选项，请打开视频或刷新推文后重试。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:BHRDLocalized(@"OK_BUTTON_TITLE") style:UIAlertActionStyleDefault handler:nil]];
        [BHTopMostController() presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark ••• BHRDDownloadDelegate
- (void)downloadProgress:(float)pct {
    BHRDUpdateDownloadProgress(self.hud, pct < 0 ? @"正在接收数据" : [BHRDManager getDownloadingPersent:pct]);
}

- (void)downloadDidFinish:(NSURL *)tmpURL Filename:(NSString *)name {
    NSURL *dst = BHRDNewDownloadURL(NO);
    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:tmpURL toURL:dst error:&error]) {
        [self downloadDidFailureWithError:error];
        return;
    }
    self.downloadManager = nil;
    BHRDDismissDownloadProgress(self.hud);
    self.hud = nil;
    if ([BHRDManager DirectSave]) [BHRDManager save:dst];
    else [BHRDManager showSaveVC:dst];
}

- (void)downloadDidFailureWithError:(NSError *)error {
    BHRDDismissDownloadProgress(self.hud);
    self.hud = nil;
    self.downloadManager = nil;
    if (!error || ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"X 随心"
                                                               message:BHRDDownloadErrorMessage(error)
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:BHRDLocalized(@"OK_BUTTON_TITLE") style:UIAlertActionStyleDefault handler:nil]];
    [BHTopMostController() presentViewController:a animated:YES completion:nil];
}

#pragma mark ••• Required by Twitter runtime
- (BOOL)enabled                { return YES; }
- (NSString *)actionSheetTitle { return @"下载视频与动图"; }
- (NSUInteger)inlineActionType { return self->_inlineActionType; }
@end
