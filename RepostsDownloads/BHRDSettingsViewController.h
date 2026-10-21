#import <UIKit/UIKit.h>
@interface BHRDSettingsViewController : UITableViewController
@end
void BHRDInstallSettingsEntry(UIViewController *controller, NSUInteger expectedSections);
BOOL BHRDIsSettingsEntry(UIViewController *controller, NSIndexPath *indexPath);
UITableViewCell *BHRDSettingsEntryCell(void);
void BHRDOpenSettings(UIViewController *controller);
