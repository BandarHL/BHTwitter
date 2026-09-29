#import <Foundation/Foundation.h>
BOOL BHRDIsPromotedModel(id model);
NSArray *BHRDSectionsByRemovingAds(NSArray *sections);
id BHRDFilterAdResponse(id object, NSData *data, BOOL enabled, BOOL *changed);
