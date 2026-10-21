#import "BHRDConfirmationGate.h"
@implementation BHRDConfirmationGate
- (BOOL)begin { if (self.pending) return NO; self.pending = YES; return YES; }
- (void)cancel { self.pending = NO; }
- (void)approve:(void (^)(void))action {
    if (!self.pending) return;
    self.pending = NO; self.depth++;
    @try { if (action) action(); } @finally { self.depth--; }
}
@end
