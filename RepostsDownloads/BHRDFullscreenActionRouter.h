#import <Foundation/Foundation.h>

// Routes one activation. No media is cached: a reused full-screen control must use
// the currently displayed video, not the video from its previous layout pass.
@interface BHRDFullscreenActionRouter : NSObject
@property(nonatomic, copy) BOOL (^isEnabled)(void);
@property(nonatomic, copy) NSArray *(^resolveMedia)(void);
// Fullscreen selection snapshots must carry a stable live source identity.
@property(nonatomic, copy) NSDictionary *(^resolveSelection)(void);
@property(nonatomic, copy) void (^observeResolution)(NSString *phase,NSDictionary *context,NSString *attempt,NSString *session);
@property(nonatomic,readonly,copy) NSString *activationIdentity;
@property(nonatomic,readonly,copy) NSString *activationAttempt;
@property(nonatomic,readonly,copy) NSString *acceptanceSession;
@property(nonatomic, copy) void (^showDownloads)(NSArray *media);
@property(nonatomic, copy) void (^showUnavailable)(void);
@property(nonatomic) BOOL retryOnUnavailable;
- (BOOL)activate;
@end
