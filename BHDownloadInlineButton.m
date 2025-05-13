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
@end

@implementation BHDownloadInlineButton

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
BH_METRIC(trailingEdgeInset,          6.0)
BH_METRIC(visibility,                 1)
BH_METRIC(alternateInlineActionType,  6)
BH_METRIC(touchInsetPriority,         2)
BH_METRIC(shouldShowCount,            NO)
BH_METRIC(displayType,                0)

#undef BH_METRIC

#pragma mark ••• Download handler
- (void)DownloadHandler:(UIButton *)sender {
    @try {
        NSAttributedString *titleString = [[NSAttributedString alloc] initWithString:[[BHTBundle sharedBundle] localizedStringForKey:@"DOWNLOAD_MENU_TITLE"]
                                                                         attributes:@{ NSFontAttributeName : [[objc_getClass("TAEStandardFontGroup") sharedFontGroup] headline2BoldFont],
                                                                                       NSForegroundColorAttributeName : UIColor.labelColor }];
        TFNActiveTextItem *title = [[objc_getClass("TFNActiveTextItem") alloc] initWithTextModel:[[objc_getClass("TFNAttributedTextModel") alloc] initWithAttributedString:titleString] activeRanges:nil];

        NSMutableArray *actions      = [NSMutableArray arrayWithObject:title];
        NSMutableArray *innerActions = [NSMutableArray arrayWithObject:title];

        // HUD helpers
        void (^startHUD)(NSString *) = ^(NSString *key) {
            if ([BHTManager DirectSave]) return;
            self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
            self.hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:key];
            [self.hud showInView:BHTopMostController().view];
        };
        void (^dismissHUD)(void) = ^{ [self.hud dismiss]; };

        // Variant builders
        TFNActionItem* (^makeMP4Item)(NSURL *) = ^TFNActionItem*(NSURL *url) {
            return [objc_getClass("TFNActionItem") actionItemWithTitle:[BHTManager getVideoQuality:url.absoluteString]
                                                               imageName:@"arrow_down_circle_stroke" action:^{
                BHDownload *dwManager = [[BHDownload alloc] init];
                [dwManager setDelegate:self];
                [dwManager downloadFileWithURL:url];
                startHUD(@"PROGRESS_DOWNLOADING_STATUS_TITLE");
            }];
        };

        TFNActionItem* (^makeM3U8Item)(NSURL *) = ^TFNActionItem*(NSURL *url) {
            return [objc_getClass("TFNActionItem") actionItemWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FFMPEG_DOWNLOAD_OPTION_TITLE"]
                                                               imageName:@"arrow_down_circle_stroke" action:^{
                startHUD(@"FETCHING_PROGRESS_TITLE");
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    MediaInformation *info = [BHTManager getM3U8Information:url];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        dismissHUD();
                        TFNMenuSheetViewController *sheet = [BHTManager newFFmpegDownloadSheet:info downloadingURL:url progressView:self.hud];
                        [sheet tfnPresentedCustomPresentFromViewController:BHTopMostController() animated:YES completion:nil];
                    });
                });
            }];
        };

        // Media enumeration
        BOOL isSlideShow = [self.delegate.delegate isKindOfClass:objc_getClass("T1SlideshowStatusView")];
        if (isSlideShow) {
            T1SlideshowStatusView *slide = self.delegate.delegate;
            for (TFSTwitterEntityMediaVideoVariant *variant in slide.media.videoInfo.variants) {
                if ([variant.contentType isEqualToString:@"video/mp4"])          [actions addObject:makeMP4Item([NSURL URLWithString:variant.url])];
                if ([variant.contentType isEqualToString:@"application/x-mpegURL"]) [actions addObject:makeM3U8Item([NSURL URLWithString:variant.url])];
            }
        } else {
            NSArray *mediaEntities = self.delegate.viewModel.representedMediaEntities;
            if (mediaEntities.count > 1) {
                [mediaEntities enumerateObjectsUsingBlock:^(TFSTwitterEntityMedia *obj, NSUInteger idx, BOOL *stop) {
                    if (obj.mediaType == 2 || obj.mediaType == 3) {
                        TFNActionItem *videoGroup = [objc_getClass("TFNActionItem") actionItemWithTitle:[NSString stringWithFormat:@"Video %lu", (unsigned long)idx + 1]
                                                                                           imageName:@"arrow_down_circle_stroke" action:^{
                            for (TFSTwitterEntityMediaVideoVariant *variant in obj.videoInfo.variants) {
                                if ([variant.contentType isEqualToString:@"video/mp4"])          [innerActions addObject:makeMP4Item([NSURL URLWithString:variant.url])];
                                if ([variant.contentType isEqualToString:@"application/x-mpegURL"]) [innerActions addObject:makeM3U8Item([NSURL URLWithString:variant.url])];
                            }
                            TFNMenuSheetViewController *inner = [[objc_getClass("TFNMenuSheetViewController") alloc] initWithActionItems:innerActions.copy];
                            [inner tfnPresentedCustomPresentFromViewController:BHTopMostController() animated:YES completion:nil];
                        }];
                        [actions addObject:videoGroup];
                    }
                }];
            } else if (mediaEntities.firstObject) {
                TFSTwitterEntityMedia *first = mediaEntities.firstObject;
                for (TFSTwitterEntityMediaVideoVariant *variant in first.videoInfo.variants) {
                    if ([variant.contentType isEqualToString:@"video/mp4"])          [actions addObject:makeMP4Item([NSURL URLWithString:variant.url])];
                    if ([variant.contentType isEqualToString:@"application/x-mpegURL"]) [actions addObject:makeM3U8Item([NSURL URLWithString:variant.url])];
                }
            }
        }

        TFNMenuSheetViewController *sheet = [[objc_getClass("TFNMenuSheetViewController") alloc] initWithActionItems:actions.copy];
        [sheet tfnPresentedCustomPresentFromViewController:BHTopMostController() animated:YES completion:nil];
    } @catch (__unused NSException *ex) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ERROR_TITLE"]
                                                                       message:[[BHTBundle sharedBundle] localizedStringForKey:@"UNKNOWN_ERROR"]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"OK_BUTTON"] style:UIAlertActionStyleDefault handler:nil]];
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
    if (![BHTManager DirectSave]) { [self.hud dismiss]; [BHTManager showSaveVC:dst]; }
    else                          { [BHTManager save:dst]; }
}

- (void)downloadDidFailureWithError:(NSError *)error {
    [self.hud dismiss]; if (!error) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ERROR_TITLE"]
                                                               message:error.localizedDescription
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"OK_BUTTON"] style:UIAlertActionStyleDefault handler:nil]];
    [BHTopMostController() presentViewController:a animated:YES completion:nil];
}

#pragma mark ••• Required by Twitter runtime
- (BOOL)enabled                { return YES; }
- (NSString *)actionSheetTitle { return @"BHDownload"; }
- (NSUInteger)inlineActionType { return self->_inlineActionType; }
@end
