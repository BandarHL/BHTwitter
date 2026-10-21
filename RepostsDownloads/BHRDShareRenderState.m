#import "BHRDShareRenderState.h"
@implementation BHRDShareRenderState {
    NSUInteger _generation;
    BOOL _rendering;
    BOOL _imageRenderScheduled;
}
- (BOOL)rendering { @synchronized(self) { return _rendering; } }
- (NSUInteger)invalidate { @synchronized(self) { _rendering = YES; return ++_generation; } }
- (BOOL)scheduleImageRender {
    @synchronized(self) {
        // Every new image invalidates prior snapshots, including arrivals while
        // a debounce is already scheduled and a theme render completed meanwhile.
        _rendering = YES; ++_generation;
        if (_imageRenderScheduled) return NO;
        _imageRenderScheduled = YES; return YES;
    }
}
- (void)clearImageRenderSchedule { @synchronized(self) { _imageRenderScheduled = NO; } }
- (BOOL)isCurrent:(NSUInteger)generation { @synchronized(self) { return generation == _generation; } }
- (BOOL)accept:(NSUInteger)generation {
    @synchronized(self) { if (generation != _generation) return NO; _rendering = NO; return YES; }
}
- (BOOL)canExportPNG:(BOOL)hasPNG pendingImages:(NSUInteger)pending exporting:(BOOL)exporting {
    @synchronized(self) { return hasPNG && !_rendering && !pending && !exporting; }
}
@end
