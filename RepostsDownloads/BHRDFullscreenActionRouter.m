#import "BHRDFullscreenActionRouter.h"
#if BHRD_AVATAR_DIAGNOSTICS
#import "BHRDAcceptance.h"
#endif
@interface BHRDFullscreenActionRouter ()
@property(nonatomic) BOOL activationPending;
@property(nonatomic) BOOL selectionCaptured;
@property(nonatomic,readwrite,copy) NSString *activationIdentity;
@property(nonatomic,readwrite,copy) NSString *activationAttempt;
@property(nonatomic,readwrite,copy) NSString *acceptanceSession;
@end
@implementation BHRDFullscreenActionRouter
- (void)attemptWithRetries:(NSUInteger)remaining {
    if (!self.isEnabled || !self.isEnabled()) {
        if (self.observeResolution) self.observeResolution(@"cancelled",@{@"reason":@"viewer_inactive"},self.activationAttempt,self.acceptanceSession);
        self.activationPending = NO; return;
    }
    NSDictionary *context=self.resolveSelection ? self.resolveSelection() : nil;
    if (![context isKindOfClass:NSDictionary.class]) context=@{};
    NSString *identity=[context[@"identity"] isKindOfClass:NSString.class] ? context[@"identity"] : @"";
    if (!self.selectionCaptured) {
        self.selectionCaptured=YES; self.activationIdentity=identity;
        if (self.observeResolution) self.observeResolution(@"started",context,self.activationAttempt,self.acceptanceSession);
    } else if (self.resolveSelection && ![self.activationIdentity isEqual:identity]) {
        if (self.observeResolution) self.observeResolution(@"cancelled",@{@"reason":@"selection_changed"},self.activationAttempt,self.acceptanceSession);
        self.activationPending=NO; return;
    }
    // Without an initial selection token, a later hydrated page could be a
    // different video. Retry only a verifiable selection.
    if (self.resolveSelection && !identity.length) remaining=0;
    NSArray *media=self.resolveSelection ? context[@"media"] : (self.resolveMedia ? self.resolveMedia() : nil);
    if ([media isKindOfClass:NSArray.class] && media.count) {
        if (self.observeResolution) self.observeResolution(@"resolved",context,self.activationAttempt,self.acceptanceSession);
        if (self.showDownloads) self.showDownloads(media);
    } else if (remaining) {
        __weak BHRDFullscreenActionRouter *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf attemptWithRetries:remaining - 1]; });
        return;
    } else if (self.showUnavailable) {
        if (self.observeResolution) self.observeResolution(@"unavailable",context,self.activationAttempt,self.acceptanceSession);
        self.showUnavailable();
    }
    __weak BHRDFullscreenActionRouter *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ weakSelf.activationPending = NO; });
}
- (BOOL)activate {
    if (!self.isEnabled || !self.isEnabled()) return NO;
    if (self.activationPending) return YES;
    self.activationPending = YES;
    self.selectionCaptured=NO; self.activationIdentity=nil;
    self.activationAttempt=NSUUID.UUID.UUIDString;
#if BHRD_AVATAR_DIAGNOSTICS
    self.acceptanceSession=BHRDAcceptanceCurrentSessionIdentifier();
#else
    self.acceptanceSession=@"";
#endif
    [self attemptWithRetries:self.retryOnUnavailable ? 3 : 0];
    return YES;
}
@end
