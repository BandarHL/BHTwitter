#import <Foundation/Foundation.h>

// Routes one activation. No media is cached: a reused full-screen control must use
// the currently displayed video, not the video from its previous layout pass.
@interface BHRDFullscreenActionRouter : NSObject
@property(nonatomic, copy) BOOL (^isEnabled)(void);
@property(nonatomic, copy) NSArray *(^resolveMedia)(void);
@property(nonatomic, copy) void (^showDownloads)(NSArray *media);
@property(nonatomic, copy) void (^showUnavailable)(void);
@property(nonatomic) BOOL retryOnUnavailable;
- (BOOL)activate;
@end
