//
//  TWHeaders.h
//  BHT
//
//  Created by BandarHelal on 23/12/1441 AH.
//
#import <objc/runtime.h>
#import "./Classes/FLEX.h"
#import "BHDownload.h"
#import "JGProgressHUD/include/JGProgressHUD.h"

@interface T1AppDelegate : UIResponder <UIApplicationDelegate>
@property(retain, nonatomic) UIWindow *window;
@end

@interface TFNTableView: UITableView
@end

@interface TFNDataViewController : UIViewController
@property(readonly, nonatomic) TFNTableView *tableView;
@end

@interface TFNItemsDataViewController : TFNDataViewController
- (void)updateSections:(id)arg1 withRowAnimation:(long long)arg2;
- (id)itemAtIndexPath:(id)arg1;
@end

@interface TFNItemsDataViewControllerBackingStore
- (void)insertSection:(id)arg1 atIndex:(long long)arg2;
- (void)insertItem:(id)arg1 atIndexPath:(id)arg2;
@end

@interface T1GenericSettingsViewController: UIViewController
@property (nonatomic, strong) TFNItemsDataViewControllerBackingStore *backingStore;
@property (nonatomic, strong) NSArray *sections;
@end

@interface TTSSearchTypeaheadViewController : TFNItemsDataViewController
- (void)clearActionControlWantsClear:(id)arg1;
@end
@interface T1SearchTypeaheadViewController : TFNItemsDataViewController
- (void)clearActionControlWantsClear:(id)arg1;
@end


// For future use. Instead of UIAlertViewController
@interface TFNActionItem : NSObject
+ (id)cancelActionItemWithAction:(void (^)(void))arg1;
+ (id)cancelActionItemWithTitle:(NSString *)arg1;
+ (id)actionItemWithTitle:(NSString *)arg1 action:(void (^)(void))arg2;
+ (id)actionItemWithTitle:(NSString *)arg1 imageName:(NSString *)arg2 action:(void (^)(void))arg3;
+ (id)actionItemWithTitle:(NSString *)arg1 systemImageName:(NSString *)arg2 action:(void (^)(void))arg3;
@end

@interface TFNMenuSheetConfiguration : NSObject
@property(copy, nonatomic) NSString *title;
@end

@interface TFNModalSheetViewController : UIViewController
@property(nonatomic, getter=isExpandable) _Bool expandable;
- (id)initWithModalContentViewController:(id)arg1;
@end

@interface TFNMenuSheetViewController : TFNItemsDataViewController
@property(nonatomic) __weak TFNModalSheetViewController *modalSheet;
@property(retain, nonatomic) UIView *sourceView;
@property(retain, nonatomic) TFNMenuSheetConfiguration *configuration;
@property(nonatomic, assign, readwrite) BOOL shouldPresentAsMenu;
- (id)initWithTitle:(id)arg1 actionItems:(id)arg2;
- (id)initWithMessage:(id)arg1 actionItems:(id)arg2;
- (id)initWithActionItems:(id)arg1;
@end

@interface TFNNavigationController : UINavigationController
- (id)initWithRootViewController:(id)arg1;
@end

@interface T1SettingsViewController : UIViewController
@property (nonatomic, strong) TFNItemsDataViewControllerBackingStore *backingStore;
@property (nonatomic, strong) NSArray *sections;
@end

@interface TFNSettingsNavigationItem : NSObject
- (id)initWithTitle:(NSString *)arg1 detail:(NSString *)arg2 iconName:(NSString *)arg3 controllerFactory:(UIViewController* (^)(void))arg4;
- (id)initWithTitle:(NSString *)arg1 detail:(NSString *)arg2 systemIconName:(NSString *)arg3 controllerFactory:(UIViewController* (^)(void))arg4;
- (id)initWithTitle:(NSString *)arg1 detail:(NSString *)arg2 controllerFactory:(UIViewController* (^)(void))arg4;
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
@property(readonly, copy, nonatomic) NSString *fullName;
@property(readonly, copy, nonatomic) NSString *username;
@property(readonly, copy, nonatomic) NSString *bio;
@property(readonly, copy, nonatomic) NSString *url;
@end

@interface T1ProfileHeaderViewController: UIViewController
- (void)copyButtonHandler;
@property(retain, nonatomic) T1ProfileUserViewModel *viewModel;
@end

@interface T1StatusInlineActionButton : UIView
{
    TFNAnimatableButton *_modernButton;
    UIButton *_button;
}
@property (nonatomic, assign, readwrite) UIEdgeInsets touchInsets;
@property(readonly, nonatomic) TFNLegacyButtonAnimator *animator;
- (id)initWithOptions:(unsigned long long)arg1 overrideSize:(id)arg2 account:(id)arg3;
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
@end

@interface TFSTwitterEntitySet : NSObject
@property(readonly, copy, nonatomic) NSArray *media;
@end

@protocol T1StatusViewModel <NSObject>
@property(nonatomic, readonly) TFSTwitterEntitySet *entities;
@end

@interface T1SlideshowStatusView: NSObject
@end

@interface T1StatusInlineActionsView : UIView
{
    NSMutableArray *_inlineActionButtons;
}
- (void)appendNewButton:(BOOL)isSlideshow;
@property(readonly, nonatomic) id <T1StatusViewModel> viewModel;
@property(retain, nonatomic) NSMutableArray *inlineActionButtons;
@property (nonatomic, strong) JGProgressHUD *hud;
- (void)DownloadHandler;
- (void)_t1_layoutInlineActionButtons;
@end

@interface T1StatusInlineActionsView () <BHDownloadDelegate>
@end

@interface T1StandardStatusView : UIView
@property(readonly, nonatomic) UIView *visibleInlineActionsView;
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
- (void)mediaUploadProgress:(id)arg1;
@property(nonatomic, readonly) T1InlineMediaView *inlineMediaView; // @synthesize inlineMediaView;
- (void)updateConstraints;
- (_Bool)accessibilityActivate;
- (void)dealloc;
- (void)layoutSubviews;
- (id)initWithFrame:(struct CGRect)arg1;
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

@interface T1StatusBodyTextView : UIView
@property(readonly, nonatomic) id viewModel; // @synthesize viewModel=_viewModel;
@end

static BOOL isDeviceLanguageRTL() {
  return ([NSLocale characterDirectionForLanguage:[[NSLocale preferredLanguages] objectAtIndex:0]] == NSLocaleLanguageDirectionRightToLeft);
}
static BOOL is_iPad() {
    if ([(NSString *)[UIDevice currentDevice].model hasPrefix:@"iPad"]) {
        return YES;
    }
    return NO;
}
static NSString *accessGroupID() {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound)
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status != errSecSuccess)
            return nil;
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];

    return accessGroup;
}

// https://github.com/julioverne/MImport/blob/0275405812ff41ed2ca56e98f495fd05c38f41f2/mimporthook/MImport.xm#L59
static UIViewController *_topMostController(UIViewController *cont) {
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
static UIViewController *topMostController() {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *next = nil;
    while ((next = _topMostController(topController)) != nil) {
        topController = next;
    }
    return topController;
}
