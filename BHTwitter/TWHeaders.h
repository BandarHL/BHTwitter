//
//  TWHeaders.h
//  BHT
//
//  Created by BandarHelal on 23/12/1441 AH.
//
#import <objc/runtime.h>
#import "./Classes/FLEX.h"
#import "BHDownload.h"

@interface TFNItemsDataViewController : NSObject
- (id)itemAtIndexPath:(id)arg1;
@end

@interface TFNItemsDataViewControllerBackingStore
- (void)insertSection:(id)arg1 atIndex:(long long)arg2;
- (void)insertItem:(id)arg1 atIndexPath:(id)arg2;
@end


@interface T1SettingsViewController : UIViewController
@property ( nonatomic, strong) TFNItemsDataViewControllerBackingStore *backingStore;
@property ( nonatomic, strong) NSArray* sections;
@end

@interface TFNTextCell: UITableViewCell
@end

@interface TFNButton : UIButton
@end

@interface T1StatusInlineActionButton : UIButton
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

@interface T1StatusInlineActionsView : UIView
{
    NSMutableArray *_inlineActionButtons;
}
- (void)appendNewButton;
@property(readonly, nonatomic) id <T1StatusViewModel> viewModel;
@property(retain, nonatomic) NSMutableArray *inlineActionButtons;
- (void)DownloadHandler;
@end

@interface T1StatusInlineActionsView () <BHDownloadDelegate>
@end

@interface T1StandardStatusView : UIView
@property(readonly, nonatomic) UIView *visibleInlineActionsView;
@end


@interface TFSKeychainDefaultTwitterConfiguration : NSObject
{
    NSString *_serviceName;
    NSString *_defaultAccessGroup;
    NSString *_sharedAccessGroup;
}
@property(readonly, nonatomic) NSString *sharedAccessGroup; // @synthesize sharedAccessGroup=_sharedAccessGroup;
@property(readonly, nonatomic) NSString *defaultAccessGroup; // @synthesize defaultAccessGroup=_defaultAccessGroup;
@property(readonly, nonatomic) NSString *serviceName; // @synthesize serviceName=_serviceName;
- (id)init;
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
- (void)mediaUploadProgress:(id)arg1;
@property(nonatomic, readonly) T1InlineMediaView *inlineMediaView; // @synthesize inlineMediaView;
- (void)updateConstraints;
- (_Bool)accessibilityActivate;
- (void)dealloc;
- (void)layoutSubviews;
- (id)initWithFrame:(struct CGRect)arg1;
- (void)DownloadHandler;
@end

@interface T1DirectMessageEntryMediaCell () <BHDownloadDelegate>
@end

@interface TFNTwitterStatus : NSObject
@property(readonly, nonatomic) NSDictionary *scribeParameters;
@property(readonly, nonatomic) _Bool isPromoted;
@property(readonly, nonatomic) NSString *mediaScribeContentID;
@end

@interface T1StatusBodyTextView : UIView
@property(readonly, nonatomic) id viewModel; // @synthesize viewModel=_viewModel;
@end

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
