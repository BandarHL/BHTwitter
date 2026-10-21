//
//  BHDownloadInlineButton.m
//  BHTwitter
//
//  Original author: BandarHelal at 09/04/2022
//  Modified by: actuallyaridan at 27/04/2025
//

#import "BHDownloadInlineButton.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "Colours/Colours.h"
#import "BHTBundle/BHTBundle.h"

#pragma mark - Helpers
static inline UIViewController *BHTopMostController(void) {
    UIViewController *top = UIApplication.sharedApplication.keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

static inline id BHTObjectForSelector(id object, SEL selector) {
    if (object == nil || ![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static inline NSArray *BHTArrayForSelector(id object, SEL selector) {
    id value = BHTObjectForSelector(object, selector);
    return [value isKindOfClass:NSArray.class] ? value : nil;
}

static BOOL BHTIsDownloadableMediaEntity(id object) {
    id videoInfo = BHTObjectForSelector(object, @selector(videoInfo));
    return BHTArrayForSelector(videoInfo, @selector(variants)).count > 0;
}

static void BHTCollectDownloadableMediaEntities(id source,
                                                 NSMutableArray *results,
                                                 NSMutableSet *visited) {
    if (source == nil || source == NSNull.null) return;

    NSValue *identity = [NSValue valueWithNonretainedObject:source];
    if ([visited containsObject:identity]) return;
    [visited addObject:identity];

    if (BHTIsDownloadableMediaEntity(source)) {
        [results addObject:source];
        return;
    }

    SEL arraySelectors[] = {
        @selector(representedMediaEntities),
        @selector(inlineMediaInfos)
    };
    for (NSUInteger index = 0;
         index < sizeof(arraySelectors) / sizeof(arraySelectors[0]);
         index++) {
        SEL arraySelector = arraySelectors[index];
        for (id item in BHTArrayForSelector(source, arraySelector)) {
            id media = BHTObjectForSelector(item, @selector(mediaEntity));
            BHTCollectDownloadableMediaEntities(media ?: item, results, visited);
        }
    }

    SEL objectSelectors[] = {
        @selector(mediaEntity),
        @selector(media),
        @selector(status),
        @selector(viewModel),
        @selector(delegate),
        @selector(extendedEntities),
        @selector(entities)
    };
    for (NSUInteger index = 0;
         index < sizeof(objectSelectors) / sizeof(objectSelectors[0]);
         index++) {
        SEL objectSelector = objectSelectors[index];
        id value = BHTObjectForSelector(source, objectSelector);
        if ([value isKindOfClass:NSArray.class]) {
            for (id item in value) {
                BHTCollectDownloadableMediaEntities(item, results, visited);
            }
        } else {
            BHTCollectDownloadableMediaEntities(value, results, visited);
        }
    }

    id producer = BHTObjectForSelector(source, @selector(playerSessionProducer));
    id producible = BHTObjectForSelector(producer, @selector(sessionProducible));
    BHTCollectDownloadableMediaEntities(producible, results, visited);
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

#pragma mark - BHDownloadInlineButton
@interface BHDownloadInlineButton () <BHDownloadDelegate>
@property (nonatomic, strong) JGProgressHUD *hud;
@property (nonatomic, strong) BHDownload *downloadManager;
@end

@implementation BHDownloadInlineButton

+ (NSArray *)downloadableMediaEntitiesFromSource:(id)source {
    NSMutableArray *results = [NSMutableArray array];
    BHTCollectDownloadableMediaEntities(source, results, [NSMutableSet set]);
    return [results copy];
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
    [self _bh_applyTint];
}

- (void)statusDidUpdate:(id)status
                options:(NSUInteger)options
     displayTextOptions:(NSUInteger)textOptions
               animated:(BOOL)animated
{
    _bh_callSuperIfPossible(self, _cmd, status, options, textOptions, animated, nil);
    [self _bh_applyTint];
}

- (void)_bh_applyTint {
    id dlg = self.delegate.delegate;
    if ([dlg isKindOfClass:objc_getClass("T1SlideshowStatusView")] ||
        [dlg isKindOfClass:objc_getClass("T1ImmersiveExploreCardView")] ||
        [dlg isKindOfClass:objc_getClass("T1TwitterSwift.ImmersiveExploreCardViewHelper")] ||
        [dlg isKindOfClass:objc_getClass("T1TwitterSwift.ImmersiveCardViewHelper")])
    {
        self.tintColor = UIColor.whiteColor;
    } else {
        self.tintColor = [UIColor colorFromHexString:@"6D6E70"];
    }
}

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
    self.tintColor        = [UIColor colorFromHexString:@"6D6E70"];
    [self setImage:[UIImage systemImageNamed:@"arrow.down"] forState:UIControlStateNormal];
    [self addTarget:self action:@selector(DownloadHandler:) forControlEvents:UIControlEventTouchUpInside];
}

// Twitter asks subclasses (+ class) for a custom glyph via this selector.
- (id)_t1_imageNamed:(id)name fitSize:(CGSize)size fillColor:(id)fill { return nil; }
+ (id)_t1_imageNamed:(id)name fitSize:(CGSize)size fillColor:(id)fill { return nil; }

#pragma mark ••• Hit‑testing tweaks
- (void)setTouchInsets:(UIEdgeInsets)insets {
    if ([self.delegate.delegate isKindOfClass:objc_getClass("T1StandardStatusInlineActionsViewAdapter")]) {
        self.imageEdgeInsets = insets;
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
BH_METRIC(visibility,                 1)
BH_METRIC(alternateInlineActionType,  6)
BH_METRIC(touchInsetPriority,         2)
BH_METRIC(shouldShowCount,            NO)
BH_METRIC(displayType,                0)

#undef BH_METRIC

#pragma mark ••• Download handler
- (void)DownloadHandler:(UIButton *)sender {
    NSMutableArray *mediaEntities = [NSMutableArray array];
    for (id source in @[self.viewModel ?: NSNull.null,
                        self.delegate ?: NSNull.null]) {
        for (id media in [BHDownloadInlineButton downloadableMediaEntitiesFromSource:source]) {
            if (![mediaEntities containsObject:media]) {
                [mediaEntities addObject:media];
            }
        }
    }

    [self presentDownloadOptionsForMediaEntities:mediaEntities sourceView:sender];
}

- (void)presentDownloadOptionsForMediaEntities:(NSArray *)mediaEntities
                                    sourceView:(UIView *)sourceView {
    @try {
        NSString *menuTitle = [[[BHTBundle sharedBundle] localizedStringForKey:@"DOWNLOAD_MENU_TITLE"]
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

                if (url == nil) continue;
                NSString *urlString = url.absoluteString;

                NSString *optionTitle = nil;
                if ([contentType isEqualToString:@"video/mp4"]) {
                    optionTitle = [BHTManager getVideoQuality:urlString];
                } else if ([contentType isEqualToString:@"application/x-mpegURL"]) {
                    optionTitle = [[BHTBundle sharedBundle] localizedStringForKey:@"FFMPEG_DOWNLOAD_OPTION_TITLE"];
                } else {
                    continue;
                }

                if (variantGroups.count > 1) {
                    optionTitle = [NSString stringWithFormat:@"Video %lu · %@", (unsigned long)groupIndex + 1, optionTitle];
                }

                UIAlertAction *action;
                if ([contentType isEqualToString:@"video/mp4"]) {
                    action = [UIAlertAction actionWithTitle:optionTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *selectedAction) {
                        self.downloadManager = [[BHDownload alloc] init];
                        [self.downloadManager setDelegate:self];
                        [self.downloadManager downloadFileWithURL:url];

                        if (![BHTManager DirectSave]) {
                            self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                            self.hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"PROGRESS_DOWNLOADING_STATUS_TITLE"];
                            [self.hud showInView:BHTopMostController().view];
                        }
                    }];
                } else {
                    action = [UIAlertAction actionWithTitle:optionTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *selectedAction) {
                        if (![BHTManager DirectSave]) {
                            self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                            self.hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"FETCHING_PROGRESS_TITLE"];
                            [self.hud showInView:BHTopMostController().view];
                        }

                        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                            MediaInformation *info = [BHTManager getM3U8Information:url];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.hud dismiss];
                                UIAlertController *ffmpegSheet = [BHTManager newFFmpegDownloadSheet:info downloadingURL:url progressView:self.hud];
                                ffmpegSheet.popoverPresentationController.sourceView = sourceView;
                                ffmpegSheet.popoverPresentationController.sourceRect = sourceView.bounds;
                                [BHTopMostController() presentViewController:ffmpegSheet animated:YES completion:nil];
                            });
                        });
                    }];
                }

                [sheet addAction:action];
                hasDownloadOption = YES;
            }
        }

        if (!hasDownloadOption) {
            [NSException raise:NSInvalidArgumentException format:@"No downloadable video variants were found"];
        }

        [sheet addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"]
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        sheet.popoverPresentationController.sourceView = sourceView;
        sheet.popoverPresentationController.sourceRect = sourceView.bounds;
        [BHTopMostController() presentViewController:sheet animated:YES completion:nil];
    } @catch (NSException *ex) {
        NSLog(@"[BHTwitter] 加载视频下载选项失败：%@\n%@", ex, ex.callStackSymbols);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BHTwitter"
                                                                       message:ex.reason ?: @"Unable to load video download options."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"OK_BUTTON_TITLE"] style:UIAlertActionStyleDefault handler:nil]];
        [BHTopMostController() presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark ••• BHDownloadDelegate
- (void)downloadProgress:(float)pct {
    self.hud.detailTextLabel.text = [BHTManager getDownloadingPersent:pct];
}

- (void)downloadDidFinish:(NSURL *)tmpURL Filename:(NSString *)name {
    NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSURL *dst = [[NSURL fileURLWithPath:doc] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", NSUUID.UUID.UUIDString]];
    [[NSFileManager defaultManager] moveItemAtURL:tmpURL toURL:dst error:nil];
    self.downloadManager = nil;
    if (![BHTManager DirectSave]) { [self.hud dismiss]; [BHTManager showSaveVC:dst]; }
    else                          { [BHTManager save:dst]; }
}

- (void)downloadDidFailureWithError:(NSError *)error {
    [self.hud dismiss];
    self.downloadManager = nil;
    if (!error) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"BHTwitter"
                                                               message:error.localizedDescription
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"OK_BUTTON_TITLE"] style:UIAlertActionStyleDefault handler:nil]];
    [BHTopMostController() presentViewController:a animated:YES completion:nil];
}

#pragma mark ••• Required by Twitter runtime
- (BOOL)enabled                { return YES; }
- (NSString *)actionSheetTitle { return @"BHDownload"; }
- (NSUInteger)inlineActionType { return self->_inlineActionType; }
@end
