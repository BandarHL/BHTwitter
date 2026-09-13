#import "BHRDFullscreenVisibility.h"
@implementation BHRDFullscreenVisibility {
    BOOL _verifiedVideo;
    BOOL _departed;
}
- (void)observeMedia:(BOOL)found { if (found) _verifiedVideo = YES; }
- (void)didAppear { _departed = NO; }
- (void)didDisappear { _departed = YES; }
- (BOOL)shouldDisplayEnabled:(BOOL)enabled attached:(BOOL)attached { return enabled && attached && !_departed && _verifiedVideo; }
@end
