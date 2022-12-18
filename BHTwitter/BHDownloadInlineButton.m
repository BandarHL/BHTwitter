//
//  BHDownloadInlineButton.m
//  BHTwitter
//
//  Created by BandarHelal on 09/04/2022.
//

#import "BHDownloadInlineButton.h"
#import "Colours.h"
#import "BHTBundle.h"

@interface BHDownloadInlineButton () <BHDownloadDelegate>
@property (nonatomic, strong) JGProgressHUD *hud;
@end

@implementation BHDownloadInlineButton
+ (CGSize)buttonImageSizeUsingViewModel:(id)arg1 options:(unsigned long long)arg2 overrideButtonSize:(CGSize)arg3 account:(id)arg4 {
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
    } else {
        [self setTintColor:[UIColor colorFromHexString:@"6D6E70"]];
    }
}
- (id)initWithOptions:(unsigned long long)arg1 overrideSize:(struct CGSize)arg2 account:(id)arg3 {
    self = [super initWithFrame:CGRectMake(0, 0, arg2.width, arg2.height)];
    if (self != nil) {
        [self setInlineActionType:80];
        [self setTintColor:[UIColor colorFromHexString:@"6D6E70"]];
        [self setImage:[UIImage systemImageNamed:@"arrow.down"] forState:UIControlStateNormal];
        [self addTarget:self action:@selector(DownloadHandler:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (id)_t1_imageNamed:(id)arg1 fitSize:(struct CGSize)arg2 fillColor:(id)arg3 {
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
            }
        }
    }
    
    TFNMenuSheetViewController *alert = [[objc_getClass("TFNMenuSheetViewController") alloc] initWithActionItems:[NSArray arrayWithArray:actions]];
    [alert tfnPresentedCustomPresentFromViewController:topMostController() animated:YES completion:nil];
}
- (void)setTouchInsets:(struct UIEdgeInsets)arg1 {
    return;
}
- (bool)enabled {
    return true;
}
- (NSString *)actionSheetTitle {
    return @"BHDownload";
}
- (unsigned long long)visibility {
    return 1;
}
- (unsigned long long)alternateInlineActionType {
    return 6;
}
- (unsigned long long)touchInsetPriority {
    return 2;
}
- (double)extraWidth {
    return 48;
}
- (bool)shouldShowCount {
    return false;
}
- (unsigned long long)displayType {
    return self->_displayType;
}
- (unsigned long long)inlineActionType {
    return self->_inlineActionType;
}
- (T1StatusInlineActionsView *)delegate {
    return self->_delegate;
}
- (id)buttonAnimator {
    return self->_buttonAnimator;
}
- (void)downloadProgress:(float)progress {
    self.hud.detailTextLabel.text = [BHTManager getDownloadingPersent:progress];
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
