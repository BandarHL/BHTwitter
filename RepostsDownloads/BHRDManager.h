#import <UIKit/UIKit.h>
#import "../JGProgressHUD/JGProgressHUD.h"

@class MediaInformation;
FOUNDATION_EXPORT UIViewController *BHRDTopViewController(void);
FOUNDATION_EXPORT void BHRDShowError(NSString *message);
#import "BHRDPreferences.h"

@interface BHRDManager : NSObject
+ (BOOL)HideReposts;
+ (BOOL)DownloadingVideos;
+ (BOOL)DirectSave;
+ (BOOL)DMDownload;
+ (BOOL)isVideoCell:(id)model;
+ (NSString *)getVideoQuality:(NSString *)url;
+ (NSString *)getDownloadingPersent:(float)progress;
+ (void)showSaveVC:(NSURL *)url;
+ (void)save:(NSURL *)url;
+ (UIAlertController *)newFFmpegDownloadSheet:(MediaInformation *)info downloadingURL:(NSURL *)url selection:(void (^)(NSNumber *index))selection;
@end

// Private interfaces used by the standalone features.
@interface T1StatusInlineActionsView : UIView
@property(nonatomic, weak) id delegate;
@end
@interface TTAStatusInlineActionsView : UIView
@end
@interface T1StatusInlineShareButton : UIView
@end
@interface TTAStatusInlineShareButton : UIView
@end
@interface TFNItemsDataViewController : UIViewController
@property(nonatomic, copy) NSArray *sections;
- (id)itemAtIndexPath:(NSIndexPath *)indexPath;
@end
@interface T1DirectMessageEntryMediaCell : UICollectionViewCell
@property(nonatomic, readonly) UIView *inlineMediaView;
@end
@interface T1GenericSettingsViewController : UIViewController
@end
@interface T1SettingsViewController : UIViewController
@end

@interface T1TabView : UIView
@property(copy, nonatomic) NSString *scribePage;
@end
@interface T1TabBarViewController : UIViewController
@property(copy, nonatomic) NSArray *tabViews;
@end
