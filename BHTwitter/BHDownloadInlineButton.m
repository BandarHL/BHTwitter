//
//  BHDownloadInlineButton.m
//  BHTwitter
//
//  Created by BandarHelal on 09/04/2022.
//

#import "BHDownloadInlineButton.h"
#import "Colours.h"
#import "BHTBundle.h"
#import <ffmpegkit/FFmpegKit.h>

@interface BHDownloadInlineButton () <BHDownloadDelegate>
@property (nonatomic, strong) JGProgressHUD *hud;
@end

@implementation BHDownloadInlineButton
static const NSString *KEY_HIT_TEST_EDGE_INSETS = @"HitTestEdgeInsets";

+ (CGSize)buttonImageSizeUsingViewModel:(id)arg1 options:(NSUInteger)arg2 overrideButtonSize:(CGSize)arg3 account:(id)arg4 {
    return CGSizeZero;
}

- (void)statusDidUpdate:(id)arg1 options:(NSUInteger)arg2 displayTextOptions:(NSUInteger)arg3 animated:(BOOL)arg4 featureSwitches:(id)arg5 {
    [self statusDidUpdate:arg1 options:arg2 displayTextOptions:arg3 animated:arg4];
}

- (void)statusDidUpdate:(id)arg1 options:(NSUInteger)arg2 displayTextOptions:(NSUInteger)arg3 animated:(BOOL)arg4 {
    if ([self.delegate.delegate isKindOfClass:objc_getClass("T1SlideshowStatusView")]) {
        [self setTintColor:UIColor.whiteColor];
    } else if ([self.delegate.delegate isKindOfClass:objc_getClass("T1ImmersiveExploreCardView")]) {
        [self setTintColor:UIColor.whiteColor];
    } else if ([self.delegate.delegate isKindOfClass:objc_getClass("T1TwitterSwift.ImmersiveExploreCardViewHelper")]) {
        [self setTintColor:UIColor.whiteColor];
    } else {
        [self setTintColor:[UIColor colorFromHexString:@"6D6E70"]];
    }
}
- (instancetype)initWithOptions:(NSUInteger)arg1 overrideSize:(id)arg2 account:(id)arg3 {
    self = [super initWithFrame:CGRectZero];
    if (self != nil) {
        [self setInlineActionType:131];
        [self setTintColor:[UIColor colorFromHexString:@"6D6E70"]];
        [self setImage:[UIImage systemImageNamed:@"arrow.down"] forState:UIControlStateNormal];
        [self addTarget:self action:@selector(DownloadHandler:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (instancetype)initWithInlineActionType:(NSUInteger)arg1 options:(NSUInteger)arg2 overrideSize:(id)arg3 account:(id)arg4 {
    self = [super initWithFrame:CGRectZero];
    if (self != nil) {
        [self setInlineActionType:arg1];
        [self setTintColor:[UIColor colorFromHexString:@"6D6E70"]];
        [self setImage:[UIImage systemImageNamed:@"arrow.down"] forState:UIControlStateNormal];
        [self addTarget:self action:@selector(DownloadHandler:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (id)_t1_imageNamed:(id)arg1 fitSize:(CGSize)arg2 fillColor:(id)arg3 {
    return nil;
}
- (void)DownloadHandler:(UIButton *)sender {
    NSAttributedString *AttString = [[NSAttributedString alloc] initWithString:[[BHTBundle sharedBundle] localizedStringForKey:@"DOWNLOAD_MENU_TITLE"] attributes:@{
        NSFontAttributeName: [[objc_getClass("TAEStandardFontGroup") sharedFontGroup] headline2BoldFont],
        NSForegroundColorAttributeName: UIColor.labelColor
    }];
    TFNActiveTextItem *title = [[objc_getClass("TFNActiveTextItem") alloc] initWithTextModel:[[objc_getClass("TFNAttributedTextModel") alloc] initWithAttributedString:AttString] activeRanges:nil];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:title];
    NSMutableArray *innerActions = [[NSMutableArray alloc] init];
    [innerActions addObject:title];
    
    
    if ([self.delegate.delegate isKindOfClass:objc_getClass("T1SlideshowStatusView")]) {
        T1SlideshowStatusView *selectedMedia = self.delegate.delegate;
        
        for (TFSTwitterEntityMediaVideoVariant *video in selectedMedia.media.videoInfo.variants) {
            if ([video.contentType isEqualToString:@"video/mp4"]) {
                TFNActionItem *option = [objc_getClass("TFNActionItem") actionItemWithTitle:[BHTManager getVideoQuality:video.url] imageName:@"arrow_down_circle_stroke" action:^{
                    BHDownload *dwManager = [[BHDownload alloc] init];
                    [dwManager downloadFileWithURL:[NSURL URLWithString:video.url]];
                    [dwManager setDelegate:self];
                    
                    if (![BHTManager DirectSave]) {
                        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                        self.hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"PROGRESS_DOWNLOADING_STATUS_TITLE"];
                        [self.hud showInView:topMostController().view];
                    }
                }];
                
                [actions addObject:option];
            }
            
            if ([video.contentType isEqualToString:@"application/x-mpegURL"]) {
                TFNActionItem *option = [objc_getClass("TFNActionItem") actionItemWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FFMPEG_DOWNLOAD_OPTION_TITLE"] imageName:@"arrow_down_circle_stroke" action:^{
                    self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                    TFNMenuSheetViewController *alert2 = [BHTManager newFFmpegDownloadSheet:[NSURL URLWithString:video.url] withProgressView:self.hud];
                    [alert2 tfnPresentedCustomPresentFromViewController:topMostController() animated:YES completion:nil];
                }];
                
                [actions addObject:option];
            }
        }
    } else {
        if (self.delegate.viewModel.representedMediaEntities.count > 1) {
            [self.delegate.viewModel.representedMediaEntities enumerateObjectsUsingBlock:^(TFSTwitterEntityMedia * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                
                if (obj.mediaType == 2 || obj.mediaType == 3) {
                    TFNActionItem *option = [objc_getClass("TFNActionItem") actionItemWithTitle:[NSString stringWithFormat:@"Video %lu", (unsigned long)idx+1] imageName:@"arrow_down_circle_stroke" action:^{
                        
                        for (TFSTwitterEntityMediaVideoVariant *video in obj.videoInfo.variants) {
                            if ([video.contentType isEqualToString:@"video/mp4"]) {
                                TFNActionItem *innerOption = [objc_getClass("TFNActionItem") actionItemWithTitle:[BHTManager getVideoQuality:video.url] imageName:@"arrow_down_circle_stroke" action:^{
                                    
                                    BHDownload *dwManager = [[BHDownload alloc] init];
                                    [dwManager downloadFileWithURL:[NSURL URLWithString:video.url]];
                                    [dwManager setDelegate:self];
                                    
                                    if (![BHTManager DirectSave]) {
                                        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                                        self.hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"PROGRESS_DOWNLOADING_STATUS_TITLE"];
                                        [self.hud showInView:topMostController().view];
                                    }
                                    
                                }];
                                
                                [innerActions addObject:innerOption];
                            }
                            
                            if ([video.contentType isEqualToString:@"application/x-mpegURL"]) {
                                TFNActionItem *option = [objc_getClass("TFNActionItem") actionItemWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FFMPEG_DOWNLOAD_OPTION_TITLE"] imageName:@"arrow_down_circle_stroke" action:^{
                                    self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                                    TFNMenuSheetViewController *alert2 = [BHTManager newFFmpegDownloadSheet:[NSURL URLWithString:video.url] withProgressView:self.hud];
                                    [alert2 tfnPresentedCustomPresentFromViewController:topMostController() animated:YES completion:nil];
                                }];
                                
                                [innerActions addObject:option];
                            }
                        }
                        
                        TFNMenuSheetViewController *innerAlert = [[objc_getClass("TFNMenuSheetViewController") alloc] initWithActionItems:[NSArray arrayWithArray:innerActions]];
                        [innerAlert tfnPresentedCustomPresentFromViewController:topMostController() animated:YES completion:nil];
                    }];
                    
                    [actions addObject:option];
                }
            }];
        } else {
            for (TFSTwitterEntityMediaVideoVariant *video in self.delegate.viewModel.representedMediaEntities.firstObject.videoInfo.variants) {
                if ([video.contentType isEqualToString:@"video/mp4"]) {
                    
                    TFNActionItem *option = [objc_getClass("TFNActionItem") actionItemWithTitle:[BHTManager getVideoQuality:video.url] imageName:@"arrow_down_circle_stroke" action:^{
                        BHDownload *dwManager = [[BHDownload alloc] init];
                        [dwManager downloadFileWithURL:[NSURL URLWithString:video.url]];
                        [dwManager setDelegate:self];
                        
                        if (![BHTManager DirectSave]) {
                            self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                            self.hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"PROGRESS_DOWNLOADING_STATUS_TITLE"];
                            [self.hud showInView:topMostController().view];
                        }
                    }];
                    
                    [actions addObject:option];
                }
                if ([video.contentType isEqualToString:@"application/x-mpegURL"]) {
                    TFNActionItem *option = [objc_getClass("TFNActionItem") actionItemWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FFMPEG_DOWNLOAD_OPTION_TITLE"] imageName:@"arrow_down_circle_stroke" action:^{
                        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                        TFNMenuSheetViewController *alert2 = [BHTManager newFFmpegDownloadSheet:[NSURL URLWithString:video.url] withProgressView:self.hud];
                        [alert2 tfnPresentedCustomPresentFromViewController:topMostController() animated:YES completion:nil];
                    }];
                    
                    [actions addObject:option];
                }
            }
        }
    }
    
    TFNMenuSheetViewController *alert = [[objc_getClass("TFNMenuSheetViewController") alloc] initWithActionItems:[NSArray arrayWithArray:actions]];
    [alert tfnPresentedCustomPresentFromViewController:topMostController() animated:YES completion:nil];
}



- (void)setTouchInsets:(UIEdgeInsets)arg1 {
    if ([self.delegate.delegate isKindOfClass:objc_getClass("T1StandardStatusInlineActionsViewAdapter")]) {
        [self setImageEdgeInsets:arg1];
        [self setHitTestEdgeInsets:arg1];
    }
}

// https://stackoverflow.com/a/13067285
- (void)setHitTestEdgeInsets:(UIEdgeInsets)hitTestEdgeInsets {
    NSValue *value = [NSValue value:&hitTestEdgeInsets withObjCType:@encode(UIEdgeInsets)];
    objc_setAssociatedObject(self, &KEY_HIT_TEST_EDGE_INSETS, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)hitTestEdgeInsets {
    NSValue *value = objc_getAssociatedObject(self, &KEY_HIT_TEST_EDGE_INSETS);
    if (value) {
        UIEdgeInsets edgeInsets; [value getValue:&edgeInsets]; return edgeInsets;
    } else {
        return UIEdgeInsetsZero;
    }
}

- (bool)enabled {
    return true;
}

- (NSString *)actionSheetTitle {
    return @"BHDownload";
}

- (NSUInteger)visibility {
    return 1;
}

- (NSUInteger)alternateInlineActionType {
    return 6;
}

- (NSUInteger)touchInsetPriority {
    return 2;
}

- (double)extraWidth {
    return 40;
}

- (CGFloat)trailingEdgeInset {
    return 6;
}

- (bool)shouldShowCount {
    return false;
}

- (NSUInteger)displayType {
    return self->_displayType;
}

- (NSUInteger)inlineActionType {
    return self->_inlineActionType;
}

- (T1StatusInlineActionsView *)delegate {
    return self->_delegate;
}

- (id)buttonAnimator {
    return self->_buttonAnimator;
}

- (id)viewModel {
    return self->_viewModel;
}

- (void)downloadProgress:(float)progress {
    self.hud.detailTextLabel.text = [BHTManager getDownloadingPersent:progress];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (UIEdgeInsetsEqualToEdgeInsets(self.hitTestEdgeInsets, UIEdgeInsetsZero) || !self.enabled || self.hidden) {
        return [super pointInside:point withEvent:event];
    }
    
    CGRect relativeFrame = self.bounds;
    CGRect hitFrame = UIEdgeInsetsInsetRect(relativeFrame, self.hitTestEdgeInsets);
    
    return CGRectContainsPoint(hitFrame, point);
}

- (void)downloadDidFinish:(NSURL *)filePath Filename:(NSString *)fileName {
    NSString *DocPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *newFilePath = [[NSURL fileURLWithPath:DocPath] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", NSUUID.UUID.UUIDString]];
    [manager moveItemAtURL:filePath toURL:newFilePath error:nil];
    if (!([BHTManager DirectSave])) {
        [self.hud dismiss];
        [BHTManager showSaveVC:newFilePath];
    } else {
        [BHTManager save:newFilePath];
    }
}
- (void)downloadDidFailureWithError:(NSError *)error {
    if (error) {
        [self.hud dismiss];
    }
}
@end
