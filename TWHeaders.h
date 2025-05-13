//
//  TWHeaders.h
//  BHT
//
//  Created by BandarHelal on 23/12/1441 AH.
//

#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreServices/CoreServices.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>
#import <SafariServices/SafariServices.h>
#import "BHDownload/BHDownload.h"
#import "CustomTabBar/BHCustomTabBarUtility.h"
#import "JGProgressHUD/JGProgressHUD.h"
#import "SAMKeychain/keychain.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSEditableTableCell.h>
#import <Preferences/PSSwitchTableCell.h>
#import "ffmpeg/FFmpegKit.h"
#import "ffmpeg/FFprobeKit.h"
#import "ffmpeg/MediaInformationSession.h"
#import "ffmpeg/MediaInformation.h"


typedef UIFont *(*BH_BaseImp)(id,SEL,...);
static NSMutableDictionary<NSString*, NSValue*>* originalFontsIMP;
static id _PasteboardChangeObserver;
static NSDictionary<NSString*, NSArray<NSString*>*> *trackingParams;
static NSString *_lastCopiedURL;

@interface T1AppDelegate : UIResponder <UIApplicationDelegate>
@property(retain, nonatomic) UIWindow *window;
@end


@interface TTMAssetVideoFile: NSObject
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) CGFloat duration;

@end

@interface TTMAssetVoiceRecording: TTMAssetVideoFile
@property (nonatomic, strong, readwrite) NSNumber *totalDurationMillis;
@end

@interface T1MediaAttachmentsViewCell: UICollectionViewCell
@property (nonatomic, strong, readwrite) id attachment;
@property (nonatomic, strong) UIButton *uploadButton;
@end

@interface T1MediaAttachmentsViewCell () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@end

@interface TCRVoiceRecordingViewController: UIViewController
@property (nonatomic, assign, readwrite) CGFloat clipDuration;
- (void)_tcr_pauseRecording;
- (void)_tcr_endRecording;
@end

@interface TCRVoiceRecordingView: UIView
@property (nonatomic, strong) NSTimer *recordingTimer;
@property (nonatomic, assign) CGFloat desiredRecordingDuration;
@property (nonatomic, weak, readwrite) id delegate;
@end

@interface NSParagraphStyle ()
+ (NSWritingDirection)_defaultWritingDirection;
@end

@interface SFSafariViewController ()
- (NSURL *)initialURL;
@end

@interface TFNTwitterAccount : NSObject
@property (nonatomic, strong) NSString *displayFullName;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *displayUsername;
@property (nonatomic, strong) NSString *fullName;
@property (nonatomic, strong) id scribe;
@end

@interface T1StandardStatusAttachmentViewAdapter : NSObject
@property (nonatomic, assign, readonly) NSUInteger attachmentType;
@end

@interface T1DirectMessageConversationEntriesViewController: UIViewController
@end

@interface TFNTableView : UITableView
- (void)setShowsVerticalScrollIndicator:(BOOL)arg1;
@end

@interface TFNDataViewController : UIViewController
@property(readonly, nonatomic) TFNTableView *tableView;
@property(readonly, nonatomic) NSString *adDisplayLocation;
@end

@interface TFNItemsDataViewController : TFNDataViewController
@property(copy, nonatomic) NSArray *sections;
- (void)updateSections:(id)arg1 withRowAnimation:(long long)arg2;
- (id)itemAtIndexPath:(id)arg1;
@end

@interface TFNItemsDataViewControllerBackingStore: NSObject
- (void)insertSection:(id)section atIndex:(NSUInteger)index;
- (void)insertItem:(id)item atIndexPath:(NSIndexPath *)indexPath;
- (void)_tfn_insertSection:(id)section atIndex:(NSUInteger)index;
- (void)_tfn_insertItem:(id)item atIndexPath:(NSIndexPath *)indexPath;
@end

@interface T1TabView : UIView
@property(readonly, nonatomic) UILabel *titleLabel;
@property(readonly, nonatomic) long long panelID;
@property(copy, nonatomic) NSString *scribePage;
@end

@interface T1TabBarViewController : UIViewController
@property(copy, nonatomic) NSArray *tabViews;
@end

@interface T1GenericSettingsViewController: UIViewController
@property (nonatomic, strong) TFNItemsDataViewControllerBackingStore *backingStore;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) TFNTwitterAccount *account;
@end

@interface TFNNavigationController : UINavigationController
@end

@interface TTSSearchTypeaheadViewController : TFNItemsDataViewController
- (void)clearActionControlWantsClear:(id)arg1;
@end
@interface T1SearchTypeaheadViewController : TFNItemsDataViewController
- (void)clearActionControlWantsClear:(id)arg1;
@end

@interface T1ColorThemeSettingsViewController : TFNItemsDataViewController
- (instancetype)initWithAccount:(TFNTwitterAccount *)acoount scribeContext:(id)context;
@end

@interface TAEStandardFontGroup : NSObject
+ (instancetype)sharedFontGroup;
- (UIFont *)fixedLargeBoldFont;
- (UIFont *)headline2BoldFont;
@end

@interface TFNActionItem : NSObject
+ (instancetype)cancelActionItemWithAction:(void (^)(void))arg1;
+ (instancetype)cancelActionItemWithTitle:(NSString *)arg1;
+ (instancetype)actionItemWithTitle:(NSString *)arg1 action:(void (^)(void))arg2;
+ (instancetype)actionItemWithTitle:(NSString *)arg1 imageName:(NSString *)arg2 action:(void (^)(void))arg3;
+ (instancetype)actionItemWithTitle:(NSString *)arg1 subtitle:(NSString *)arg2 imageName:(NSString *)arg3 action:(void (^) (void))arg4;
+ (instancetype)actionItemWithTitle:(NSString *)arg1 systemImageName:(NSString *)arg2 action:(void (^)(void))arg3;
@end

@interface TFNMenuSheetCenteredIconItem : NSObject
- (instancetype)initWithIconImageName:(id)imageName height:(CGFloat)arg1 fillColor:(id)Color;
@end

@interface TFNAttributedTextModel : NSObject
- (instancetype)initWithAttributedString:(NSMutableAttributedString *)arg;
@end

@interface TFNActiveTextItem : NSObject
- (instancetype)initWithTextModel:(id)arg activeRanges:(id)arg1;
@end

@interface TFNMenuSheetViewController : TFNItemsDataViewController
@property(nonatomic, assign, readwrite) BOOL shouldPresentAsMenu;
@property(retain, nonatomic) UIView *sourceView;
- (instancetype)initWithTitle:(NSString *)sheetTitle actionItems:(NSArray *)actionItems;
- (instancetype)initWithMessage:(NSString *)sheetMessage actionItems:(NSArray *)actionItems;
- (instancetype)initWithActionItems:(NSArray *)actionItems;
- (instancetype)initWithTitle:(NSString *)sheetTitle titleStyle:(long long)sheetTitleStyle message:(NSString *)sheetMessage messageIconName:(id)sheetMessageIconName actionItemSections:(NSArray *)actionItemSections;
- (void)tfnPresentedCustomPresentFromViewController:(id)arg1 animated:(BOOL)arg2 completion:(void (^) (void))arg3;
@end

@interface T1SettingsViewController : UIViewController
@property (nonatomic, strong) TFNItemsDataViewControllerBackingStore *backingStore;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) TFNTwitterAccount *account;
@end

@interface TFNSettingsNavigationItem : NSObject
- (instancetype)initWithTitle:(NSString *)arg1 detail:(NSString *)arg2 iconName:(NSString *)arg3 controllerFactory:(UIViewController* (^)(void))arg4;
- (instancetype)initWithTitle:(NSString *)arg1 detail:(NSString *)arg2 systemIconName:(NSString *)arg3 controllerFactory:(UIViewController* (^)(void))arg4;
- (instancetype)initWithTitle:(NSString *)arg1 detail:(NSString *)arg2 controllerFactory:(UIViewController* (^)(void))arg4;
@end

@interface TFNTextCell: UITableViewCell
@end

@interface TFNButton : UIButton
+ (id)buttonWithImage:(id)arg1 style:(long long)arg2 sizeClass:(long long)arg3;
@end

@interface TFNLegacyButtonAnimator : NSObject
@end

@interface TFNAnimatableButton : TFNButton
@property(nonatomic) __weak id animationCoordinator;
@end

@interface T1ProfileActionButtonsView : UIView
@end

@interface T1ProfileHeaderView : UIView
@property(readonly, nonatomic) T1ProfileActionButtonsView *actionButtonsView;
@end

@interface T1ProfileUserViewModel : NSObject
@property(readonly, copy, nonatomic) NSString *location;
@property(readonly, copy, nonatomic) NSString *fullName;
@property(readonly, copy, nonatomic) NSString *username;
@property(readonly, copy, nonatomic) NSString *bio;
@property(readonly, copy, nonatomic) NSString *url;
@end

@interface T1ProfileHeaderViewController: UIViewController
- (void)copyButtonHandler;
@property(retain, nonatomic) T1ProfileUserViewModel *viewModel;
@end

@protocol T1StatusInlineActionButtonDelegate <NSObject>
@end
@protocol TTAStatusInlineActionButtonDelegate <NSObject>
@end

@interface T1StatusInlineShareButton : UIView
@property(nonatomic) __weak id <T1StatusInlineActionButtonDelegate> delegate;
@end

@interface TTAStatusInlineShareButton : UIView
@property(nonatomic) __weak id <T1StatusInlineActionButtonDelegate> delegate;
@end

@protocol TTACoreStatusViewEventHandler <NSObject>
@end

@interface T1StatusCell : UITableViewCell <TTACoreStatusViewEventHandler>
@end

@interface T1TweetDetailsFocalStatusViewTableViewCell : T1StatusCell
@end

@interface TFSTwitterEntityMediaVideoVariant : NSObject
@property(readonly, copy, nonatomic) NSString *contentType;
@property(readonly, copy, nonatomic) NSString *url;
@end

@interface TFSTwitterEntityMediaVideoInfo : NSObject
@property(readonly, copy, nonatomic) NSArray *variants;
@property(readonly, copy, nonatomic) NSString *primaryUrl;
@end

@interface TFSTwitterEntityMedia : NSObject
@property(readonly, nonatomic) TFSTwitterEntityMediaVideoInfo *videoInfo;
@property(readonly, copy, nonatomic) NSString *mediaURL;
@property(nonatomic, assign, readonly) NSInteger mediaType; // 1 = photo, 2 = GIF, 3 = video
@end

@interface TFSTwitterEntitySet : NSObject
@property(readonly, copy, nonatomic) NSArray *media;
@end

@protocol T1StatusViewModel <NSObject>
@property(nonatomic, readonly) TFSTwitterEntitySet *entities;
@property(nonatomic, assign, readonly) NSArray <TFSTwitterEntityMedia *> *representedMediaEntities;
@property (nonatomic, assign, readonly) BOOL isMediaEntityVideo;
@property (nonatomic, assign, readonly) BOOL isGIF;
@end

@interface T1StatusInlineActionsView : UIView <T1StatusInlineActionButtonDelegate>
@property(readonly, nonatomic) id <T1StatusViewModel> viewModel;
@property(nonatomic) id delegate;
@end

@interface TTAStatusInlineActionsView : UIView <TTAStatusInlineActionButtonDelegate>
@property(readonly, nonatomic) id <T1StatusViewModel> viewModel;
@property(nonatomic) id delegate;
@end

@interface T1SlideshowStatusView : UIView
@property (nonatomic, strong, readwrite) TFSTwitterEntityMedia *media;
@end

@interface T1StandardStatusView : UIView
@property(nonatomic) __weak id <TTACoreStatusViewEventHandler> eventHandler;
@property(readonly, nonatomic) UIView *visibleInlineActionsView;
@end

@interface T1TweetDetailsFocalStatusView : UIView
@property(nonatomic) __weak id <TTACoreStatusViewEventHandler> eventHandler;
@end

@interface T1ConversationFocalStatusView : UIView
@property(nonatomic) __weak id <TTACoreStatusViewEventHandler> eventHandler;
@end

@interface TFNButtonBarView : UIView
@property(nonatomic) double trailingViewsSpacing;
@property(nonatomic) double leadingViewsSpacing;
@property(copy, nonatomic) NSArray *leadingViews;
@end

@interface T1TweetComposeViewController : UIViewController
@property(retain, nonatomic) TFNButton *voiceButton;
@property(retain, nonatomic) TFNButtonBarView *buttonBarView;
- (void)_t1_insertVoiceButtonIfNeeded;
@end

@interface T1PlayerMediaEntitySessionProducible : NSObject
@property(readonly, nonatomic) TFSTwitterEntityMedia *mediaEntity;
@end

@protocol T1PlayerSessionProducible <NSObject>
@end

@interface T1PlayerSessionProducer : NSObject
@property(readonly, nonatomic) id <T1PlayerSessionProducible> sessionProducible;
@end


@protocol T1InlineMediaViewModel <NSObject>
@property(nonatomic, readonly) T1PlayerSessionProducer *playerSessionProducer;
@end

@interface T1InlineMediaView : UIView
@property (retain, nonatomic) id <T1InlineMediaViewModel> viewModel;
@property (readonly, nonatomic) UIImageView *previewImageView;
@property (retain, nonatomic) UIView *playerIconView;
@property (nonatomic, assign, readwrite) NSUInteger playerIconViewType;
@end

@interface T1DirectMessageAbstractConversationEntryViewModel : NSObject
@property(retain, nonatomic) UIImage *previewImage;
@end

@interface T1DirectMessageEntryViewModel : T1DirectMessageAbstractConversationEntryViewModel
@property(nonatomic) _Bool isOutgoingMessage;
@end

@interface T1DirectMessageEntryBaseCell: UICollectionViewCell
@property(nonatomic, readonly) T1DirectMessageEntryViewModel *messageEntryViewModel;
@property(nonatomic, readonly) UIImage *profileImage;
@end

@interface T1DirectMessageEntryMediaCell : T1DirectMessageEntryBaseCell
@property (nonatomic, strong) JGProgressHUD *hud;
// @property (nonatomic, strong) NSURL *ffmepgExportURL;
- (void)mediaUploadProgress:(id)arg1;
@property(nonatomic, readonly) T1InlineMediaView *inlineMediaView; // @synthesize inlineMediaView;
- (void)updateConstraints;
- (_Bool)accessibilityActivate;
- (void)dealloc;
- (void)layoutSubviews;
- (instancetype)initWithFrame:(struct CGRect)arg1;
- (void)DownloadHandler;
@end

@interface T1DirectMessageEntryMediaCell () <BHDownloadDelegate, UIContextMenuInteractionDelegate>
@end

@protocol TFNTwitterStatusBanner <NSObject>
@end

@interface TFNTwitterURTTimelineStatusBanner : NSObject <TFNTwitterStatusBanner>
@end

@interface TFNTwitterURTTimelineStatusTopicBanner : TFNTwitterURTTimelineStatusBanner
@end

@interface T1URTTimelineStatusItemViewModel : NSObject
@property(nonatomic, readonly) NSString *text;
@property(nonatomic, readonly) _Bool isPromoted;
@property(nonatomic, retain) id <TFNTwitterStatusBanner> banner;
@end

@interface TFNTwitterStatus : NSObject
@property(readonly, nonatomic) NSDictionary *scribeParameters;
@property(readonly, nonatomic) _Bool isPromoted;
@property(readonly, nonatomic) NSString *mediaScribeContentID;
@end

@interface TFSTwitterEntityURL : NSObject
@property(readonly, copy, nonatomic) NSString *expandedURL;
@end

@interface T1StatusBodyTextView : UIView
@property(readonly, nonatomic) id viewModel; // @synthesize viewModel=_viewModel;
@end

@interface T1RichTextFormatViewController : UIViewController
- (instancetype)initWithRichTextFormatDocumentPath:(NSString *)documentPath;
@end

@interface TFNTitleView: UIView
+ (instancetype)titleViewWithTitle:(NSString *)title subtitle:(NSString *)subTitle;
@end

@interface _TtC10TwitterURT32URTTimelineEventSummaryViewModel : NSObject
@property(nonatomic, readonly) NSDictionary *scribeItem;
@end

@interface _TtC10TwitterURT25URTTimelineTrendViewModel : NSObject
@property(nonatomic, readonly) NSDictionary *scribeItem;
@end

@class FLEXAlert, FLEXAlertAction;

typedef void (^FLEXAlertReveal)(void);
typedef void (^FLEXAlertBuilder)(FLEXAlert *make);
typedef FLEXAlert * _Nonnull (^FLEXAlertStringProperty)(NSString * _Nullable);
typedef FLEXAlert * _Nonnull (^FLEXAlertStringArg)(NSString * _Nullable);
typedef FLEXAlert * _Nonnull (^FLEXAlertTextField)(void(^configurationHandler)(UITextField *textField));
typedef FLEXAlertAction * _Nonnull (^FLEXAlertAddAction)(NSString *title);
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionStringProperty)(NSString * _Nullable);
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionProperty)(void);
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionBOOLProperty)(BOOL);
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionHandler)(void(^handler)(NSArray<NSString *> *strings));

@interface FLEXAlert : NSObject

/// Shows a simple alert with one button which says "Dismiss"
+ (void)showAlert:(NSString * _Nullable)title message:(NSString * _Nullable)message from:(UIViewController *)viewController;

/// Shows a simple alert with no buttons and only a title, for half a second
+ (void)showQuickAlert:(NSString *)title from:(UIViewController *)viewController;

/// Construct and display an alert
+ (void)makeAlert:(FLEXAlertBuilder)block showFrom:(UIViewController *)viewController;
/// Construct and display an action sheet-style alert
+ (void)makeSheet:(FLEXAlertBuilder)block
         showFrom:(UIViewController *)viewController
           source:(id)viewOrBarItem;

/// Construct an alert
+ (UIAlertController *)makeAlert:(FLEXAlertBuilder)block;
/// Construct an action sheet-style alert
+ (UIAlertController *)makeSheet:(FLEXAlertBuilder)block;

/// Set the alert's title.
///
/// Call in succession to append strings to the title.
@property (nonatomic, readonly) FLEXAlertStringProperty title;
/// Set the alert's message.
///
/// Call in succession to append strings to the message.
@property (nonatomic, readonly) FLEXAlertStringProperty message;
/// Add a button with a given title with the default style and no action.
@property (nonatomic, readonly) FLEXAlertAddAction button;
/// Add a text field with the given (optional) placeholder text.
@property (nonatomic, readonly) FLEXAlertStringArg textField;
/// Add and configure the given text field.
///
/// Use this if you need to more than set the placeholder, such as
/// supply a delegate, make it secure entry, or change other attributes.
@property (nonatomic, readonly) FLEXAlertTextField configuredTextField;

@end

@interface FLEXAlertAction : NSObject

/// Set the action's title.
///
/// Call in succession to append strings to the title.
@property (nonatomic, readonly) FLEXAlertActionStringProperty title;
/// Make the action destructive. It appears with red text.
@property (nonatomic, readonly) FLEXAlertActionProperty destructiveStyle;
/// Make the action cancel-style. It appears with a bolder font.
@property (nonatomic, readonly) FLEXAlertActionProperty cancelStyle;
/// Enable or disable the action. Enabled by default.
@property (nonatomic, readonly) FLEXAlertActionBOOLProperty enabled;
/// Give the button an action. The action takes an array of text field strings.
@property (nonatomic, readonly) FLEXAlertActionHandler handler;
/// Access the underlying UIAlertAction, should you need to change it while
/// the encompassing alert is being displayed. For example, you may want to
/// enable or disable a button based on the input of some text fields in the alert.
/// Do not call this more than once per instance.
@property (nonatomic, readonly) UIAlertAction *action;

@end
@interface FLEXManager : NSObject
+ (instancetype)sharedManager;
- (void)showExplorer;
- (void)hideExplorer;
- (void)toggleExplorer;
@end

@protocol TAEColorPalette
- (UIColor *)primaryColorForOption:(NSUInteger)colorOption;
@end

@interface TAETwitterColorPaletteSettingInfo : NSObject
@property(readonly, nonatomic) id <TAEColorPalette> colorPalette;
@property(readonly, nonatomic) _Bool isDark;
@end

@interface TAEColorSettings : NSObject
@property(retain, nonatomic) TAETwitterColorPaletteSettingInfo *currentColorPalette;
- (void)setPrimaryColorOption:(NSInteger)colorOption;
+ (instancetype)sharedSettings;
@end

static void BH_changeTwitterColor(NSInteger colorID) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    TAEColorSettings *colorSettings = [objc_getClass("TAEColorSettings") sharedSettings];
    
    [defaults setObject:@(colorID) forKey:@"T1ColorSettingsPrimaryColorOptionKey"];
    [colorSettings setPrimaryColorOption:colorID];
}
static UIImage *BH_imageFromView(UIView *view) {
    TAEColorSettings *colorSettings = [objc_getClass("TAEColorSettings") sharedSettings];
    bool opaque = [colorSettings.currentColorPalette isDark] ? true : false;
    UIGraphicsBeginImageContextWithOptions(view.frame.size, opaque, 0.0);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:false];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return img;
}

static  UIFont * _Nullable BH_getDefaultFont(UIFont *font) {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"en_font"]) {
        // https://stackoverflow.com/a/20515367/16619237
        UIFontDescriptorSymbolicTraits fontDescriptorSymbolicTraits = font.fontDescriptor.symbolicTraits;
        BOOL isBold = (fontDescriptorSymbolicTraits & UIFontDescriptorTraitBold) != 0;

        if ([[NSUserDefaults standardUserDefaults] objectForKey:isBold ? @"bhtwitter_font_2" : @"bhtwitter_font_1"]) {
            NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:isBold ? @"bhtwitter_font_2" : @"bhtwitter_font_1"];
            return [UIFont fontWithName:fontName size:font.pointSize];
        }
        return nil;
    }
    return nil;
}
static BOOL isDeviceLanguageRTL() {
    return [NSParagraphStyle _defaultWritingDirection] == NSWritingDirectionRightToLeft;
}
static BOOL is_iPad() {
    if ([(NSString *)[UIDevice currentDevice].model hasPrefix:@"iPad"]) {
        return YES;
    }
    return NO;
}

// https://github.com/julioverne/MImport/blob/0275405812ff41ed2ca56e98f495fd05c38f41f2/mimporthook/MImport.xm#L59
static UIViewController * _Nullable _topMostController(UIViewController * _Nonnull cont) {
    UIViewController *topController = cont;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    if ([topController isKindOfClass:[UINavigationController class]]) {
        UIViewController *visible = ((UINavigationController *)topController).visibleViewController;
        if (visible) {
            topController = visible;
        }
    }
    return (topController != cont ? topController : nil);
}
static UIViewController * _Nonnull topMostController() {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *next = nil;
    while ((next = _topMostController(topController)) != nil) {
        topController = next;
    }
    return topController;
}
