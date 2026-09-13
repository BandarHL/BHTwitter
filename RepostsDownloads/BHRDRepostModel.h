#import <Foundation/Foundation.h>
#import "BHRDPreferences.h"

@interface BHRDRepostInfo : NSObject
@property(nonatomic, copy) NSString *author;
@property(nonatomic, copy) NSString *authorName;
@property(nonatomic, copy) NSString *authorHandle;
@property(nonatomic, copy) NSURL *avatar;
@property(nonatomic, copy) NSArray<NSURL *> *thumbnails;
@end
BOOL BHRDIsRepostModel(id model);
NSString *BHRDRepostIdentity(id model);
BHRDRepostInfo *BHRDInfoForRepostModel(id model);
BOOL BHRDDataMayContainRepostMetadata(NSData *data);
void BHRDCacheRepostMetadata(id object);
NSArray *BHRDSectionsByRemovingReposts(NSArray *sections);
NSURL *BHRDSafeThumbnailURL(id value);
