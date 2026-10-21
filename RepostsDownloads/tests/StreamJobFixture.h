// Only native FFmpegKit execution and UIKit presentation are substituted. The
// production StreamJob, argument builder, task state and transfer slot run intact.
#pragma once
#import <Foundation/Foundation.h>
#import "../../ffmpeg/FFmpegKit.h"
#import "../../ffmpeg/FFprobeKit.h"
#import "../../ffmpeg/MediaInformationSession.h"
#import "../BHRDStreamJob.h"

@interface JGProgressHUD : NSObject
@property(nonatomic) BOOL visible;
@property(nonatomic,copy) void (^cancel)(void);
@end
JGProgressHUD *BHRDShowDownloadProgress(NSString *title, void (^cancel)(void));
void BHRDUpdateDownloadProgress(JGProgressHUD *hud, NSString *detail);
void BHRDDismissDownloadProgress(JGProgressHUD *hud);
void BHRDShowError(NSString *message);
@interface BHRDManager : NSObject
+ (BOOL)DirectSave;
+ (void)save:(NSURL *)url;
+ (void)showSaveVC:(NSURL *)url;
@end

@interface BHRDFixtureSession : NSObject
@property(nonatomic) long identifier;
@property(nonatomic) NSUInteger cancels;
@property(nonatomic) SessionState state;
@property(nonatomic,copy) void (^completion)(id session);
- (void)deliverCompletion;
@end
extern NSMutableArray<BHRDFixtureSession *> *BHRDFixtureSessions;
extern NSMutableArray<JGProgressHUD *> *BHRDFixtureHUDs;
extern NSMutableArray<NSDictionary *> *BHRDFixtureEvents;
extern void (^BHRDFixtureBeforeBinding)(void);
extern NSUInteger BHRDFixtureAlerts;
