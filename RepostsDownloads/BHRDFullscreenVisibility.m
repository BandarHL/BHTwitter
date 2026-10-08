#import "BHRDFullscreenVisibility.h"
@implementation BHRDFullscreenVisibility {
    BOOL _videoPresent;
    BOOL _departed;
}
- (void)observeVideoPresence:(BOOL)found { if (found) _videoPresent = YES; }
- (void)observePhotoPresence { _videoPresent = NO; }
- (void)observeMedia:(BOOL)found { [self observeVideoPresence:found]; }
- (void)didAppear { _departed = NO; }
- (void)didDisappear { _departed = YES; }
- (BOOL)shouldDisplayEnabled:(BOOL)enabled attached:(BOOL)attached { return enabled && attached && !_departed && _videoPresent; }
@end
