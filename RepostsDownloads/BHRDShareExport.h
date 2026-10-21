#import <Foundation/Foundation.h>
typedef NS_ENUM(NSUInteger, BHRDShareExportOutcome) {
    BHRDShareExportNone, BHRDShareExportCopied, BHRDShareExportSaved,
    BHRDShareExportShared, BHRDShareExportCancelled, BHRDShareExportFailed
};
// Production export orchestration, independent of presentation. close cancels
// work only before Photos accepts it; an accepted write keeps its real result.
@interface BHRDShareExport : NSObject
@property(nonatomic, readonly) BOOL closed;
@property(nonatomic, readonly) BOOL busy;
@property(nonatomic, readonly) BHRDShareExportOutcome lastOutcome;
@property(nonatomic, copy) void (^completion)(BHRDShareExportOutcome outcome, NSError *error);
- (void)copyPNG:(NSData *)png;
- (void)savePNG:(NSData *)png hostInfo:(NSDictionary *)info;
- (NSURL *)prepareSharePNG:(NSData *)png;
- (void)completeShare:(BOOL)completed error:(NSError *)error;
- (void)close;
@end
