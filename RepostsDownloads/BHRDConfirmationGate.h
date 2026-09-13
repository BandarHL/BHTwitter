#import <Foundation/Foundation.h>
@interface BHRDConfirmationGate : NSObject
@property(nonatomic) BOOL pending;
@property(nonatomic) NSUInteger depth;
- (BOOL)begin;
- (void)cancel;
- (void)approve:(void (^)(void))action;
@end
