#import "BHRDFullscreenActionRouter.h"
@interface BHRDFullscreenActionRouter ()
@property(nonatomic) BOOL activationPending;
@end
@implementation BHRDFullscreenActionRouter
- (void)attemptWithRetries:(NSUInteger)remaining {
    if (!self.isEnabled || !self.isEnabled()) { self.activationPending = NO; return; }
    NSArray *media = self.resolveMedia ? self.resolveMedia() : nil;
    if ([media isKindOfClass:NSArray.class] && media.count) {
        if (self.showDownloads) self.showDownloads(media);
    } else if (remaining) {
        __weak BHRDFullscreenActionRouter *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf attemptWithRetries:remaining - 1]; });
        return;
    } else if (self.showUnavailable) {
        self.showUnavailable();
    }
    __weak BHRDFullscreenActionRouter *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ weakSelf.activationPending = NO; });
}
- (BOOL)activate {
    if (!self.isEnabled || !self.isEnabled()) return NO;
    if (self.activationPending) return YES;
    self.activationPending = YES;
    [self attemptWithRetries:self.retryOnUnavailable ? 3 : 0];
    return YES;
}
@end
