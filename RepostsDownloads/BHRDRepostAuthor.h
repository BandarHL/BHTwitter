#import <Foundation/Foundation.h>
#import "BHRDRepostModel.h"
@class UIView, UIImage;

// Geometry/text selection is independent of UIKit so real selection rules can
// be regression-tested on macOS. Rows are confined to one native tweet header.
NSDictionary *BHRDSelectRepostAuthor(NSArray<NSDictionary *> *rows, NSString *expectedHandle);
NSString *BHRDRepostHeaderText(id source);
UIImage *BHRDCaptureRepostAuthor(UIView *cell, UIView *excludedOverlay,
                               NSMapTable *hiddenViews, BHRDRepostInfo *info);
