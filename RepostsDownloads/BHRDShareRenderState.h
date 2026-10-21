#import <Foundation/Foundation.h>
@interface BHRDShareRenderState : NSObject
@property(nonatomic, readonly) BOOL rendering;
- (NSUInteger)invalidate;
- (BOOL)scheduleImageRender;
- (void)clearImageRenderSchedule;
- (BOOL)isCurrent:(NSUInteger)generation;
- (BOOL)accept:(NSUInteger)generation;
- (BOOL)canExportPNG:(BOOL)hasPNG pendingImages:(NSUInteger)pending exporting:(BOOL)exporting;
@end
