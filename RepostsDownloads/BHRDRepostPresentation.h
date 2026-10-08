#import <UIKit/UIKit.h>
#import "BHRDRepostModel.h"
void BHRDConfigureRepostCell(UITableViewCell *cell, id model, id controller);
void BHRDLayoutRepostCell(UITableViewCell *cell);
void BHRDRestoreRepostCell(UITableViewCell *cell);
double BHRDRepostRowHeight(id controller, id model, double originalHeight);
void BHRDScheduleTimelineRefresh(id controller);
void BHRDRefreshHiddenReposts(void);
void BHRDRepostPreferencesChanged(void);
void BHRDRepostMetadataChanged(void);
void BHRDRepostNativeImageChanged(UIImageView *view);
// Call only after the host's real viewDidAppear. Acceptance confirms a detail
// only with a matching focal post on a visible controller in the same window.
void BHRDRepostControllerDidAppear(id controller);
