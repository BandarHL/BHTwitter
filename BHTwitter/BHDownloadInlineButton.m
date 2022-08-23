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


- (void)statusDidUpdate:(id)arg1 options:(unsigned long long)arg2 displayTextOptions:(unsigned long long)arg3 animated:(_Bool)arg4 {
    if ([self.delegate.delegate isKindOfClass:objc_getClass("T1SlideshowStatusView")]) {
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
    
    for (TFSTwitterEntityMedia *i in self.delegate.viewModel.entities.media) {
        for (TFSTwitterEntityMediaVideoVariant *k in i.videoInfo.variants) {
            if ([k.contentType isEqualToString:@"video/mp4"]) {
                TFNActionItem *download = [objc_getClass("TFNActionItem") actionItemWithTitle:[BHTManager getVideoQuality:k.url] imageName:@"arrow_down_circle_stroke" action:^{
                    BHDownload *DownloadManager = [[BHDownload alloc] init];
                    [DownloadManager downloadFileWithURL:[NSURL URLWithString:k.url]];
                    [DownloadManager setDelegate:self];
                    if (!([BHTManager DirectSave])) {
                        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
                        self.hud.textLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"PROGRESS_DOWNLOADING_STATUS_TITLE"];
                        [self.hud showInView:topMostController().view];
                    }
                }];
                [actions addObject:download];
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
