#import <Foundation/Foundation.h>
@interface BHRDFullscreenVisibility : NSObject
// Visibility follows a native video surface, not downloadable URL discovery.
- (void)observeVideoPresence:(BOOL)found;
- (void)observePhotoPresence;
// Kept for callers that already have positive media evidence.
- (void)observeMedia:(BOOL)found;
- (void)didAppear;
- (void)didDisappear;
- (BOOL)shouldDisplayEnabled:(BOOL)enabled attached:(BOOL)attached;
@end
