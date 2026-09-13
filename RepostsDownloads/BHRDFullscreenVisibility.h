#import <Foundation/Foundation.h>
@interface BHRDFullscreenVisibility : NSObject
- (void)observeMedia:(BOOL)found;
- (void)didAppear;
- (void)didDisappear;
- (BOOL)shouldDisplayEnabled:(BOOL)enabled attached:(BOOL)attached;
@end
