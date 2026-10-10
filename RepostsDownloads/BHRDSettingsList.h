#import <Foundation/Foundation.h>
// Insert a real backing-store item, so the host owns row counts and index paths.
BOOL BHRDInsertSettingsListItem(id controller, id item, NSUInteger expectedSections);
id BHRDSettingsItemAtIndexPath(id controller, NSIndexPath *indexPath);
