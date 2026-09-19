#import <UIKit/UIKit.h>
#import "BHRDRepostModel.h"
void BHRDConfigureRepostCell(UITableViewCell *cell, id model, id controller);
void BHRDLayoutRepostCell(UITableViewCell *cell);
void BHRDRestoreRepostCell(UITableViewCell *cell);
double BHRDRepostRowHeight(id controller, id model, double originalHeight);
void BHRDScheduleTimelineRefresh(id controller);
void BHRDResetExpandedReposts(void);
void BHRDRepostPreferencesChanged(void);
void BHRDRepostMetadataChanged(void);
void BHRDRepostNativeImageChanged(UIImageView *view);
