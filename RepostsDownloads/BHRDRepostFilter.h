#import <Foundation/Foundation.h>

BOOL BHRDDataMayContainReposts(NSData *data);
id BHRDJSONObjectByFilteringReposts(id object, BOOL *changed);
