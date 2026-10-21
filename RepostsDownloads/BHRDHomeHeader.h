#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, BHRDHomeTabRole) { BHRDHomeTabNone, BHRDHomeTabForYou, BHRDHomeTabFollowing, BHRDHomeTabAdd };
BHRDHomeTabRole BHRDHomeHeaderRole(NSString *text);
BOOL BHRDHomeHeaderHasPrimaryTabs(NSArray<NSDictionary *> *labels, double y);
NSArray *BHRDHomeFirstTwoPages(NSArray *pages);
NSInteger BHRDHomeSelectedPage(NSInteger proposed);
double BHRDHomeMaximumOffset(double viewportWidth, double contentWidth);

NSArray *BHRDHomeSelectPrimaryPages(NSArray *pages, NSArray<NSNumber *> *roles);
