#import <Foundation/Foundation.h>
BOOL BHRDContentPolicy(NSString *className, NSString *bannerClass, NSDictionary *scribe, NSString *location, NSSet *enabled);
BOOL BHRDShouldHideRecommendation(id model, id controller);
NSArray *BHRDFilterRecommendations(NSArray *sections, id controller);
