#import <Foundation/Foundation.h>
// A single terminal transition prevents late callbacks from saving cancelled files.
@interface BHRDTaskState : NSObject
@property(nonatomic, readonly) BOOL cancelled;
@property(nonatomic, readonly) BOOL finished;
@property(nonatomic, copy) void (^cancelHandler)(void);
- (BOOL)finish;
- (BOOL)cancel;
@end

BOOL BHRDTryBeginTransfer(id owner);
void BHRDEndTransfer(id owner);
