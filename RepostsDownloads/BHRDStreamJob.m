#import "BHRDStreamJob.h"
#import "BHRDTaskState.h"
#import "BHRDDownloadProgress.h"
#import "BHRDManager.h"
#import "BHRDStreamArguments.h"
#import "BHRDDownloadStore.h"
#import "../ffmpeg/FFmpegKit.h"
#import "../ffmpeg/FFprobeKit.h"
#import "../ffmpeg/MediaInformationSession.h"

@interface BHRDStreamJob ()
@property(nonatomic, strong) BHRDTaskState *state;
@property(nonatomic, strong) JGProgressHUD *hud;
@property(nonatomic, strong) NSTimer *watchdog;
@property(nonatomic) NSTimeInterval lastProgress;
@property(nonatomic) long lastSize;
@property(nonatomic) double lastMediaTime;
@property(nonatomic, copy) void (^downloadCompletion)(void);
@property(nonatomic, copy) void (^probeCompletion)(MediaInformation *, NSError *);
@end
@implementation BHRDStreamJob
- (instancetype)init {
    if ((self = [super init])) _state = [BHRDTaskState new];
    return self;
}
- (void)beginProgress:(NSString *)title timeout:(NSTimeInterval)timeout {
    __weak BHRDStreamJob *weakSelf = self;
    self.hud = BHRDShowDownloadProgress(title, ^{ [weakSelf cancel]; });
    self.lastProgress = NSProcessInfo.processInfo.systemUptime;
    self.watchdog = [NSTimer timerWithTimeInterval:5 repeats:YES block:^(__unused NSTimer *timer) {
        BHRDStreamJob *job = weakSelf;
        if (job && !job.state.finished && NSProcessInfo.processInfo.systemUptime - job.lastProgress >= timeout) {
            [job stopWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]];
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:self.watchdog forMode:NSRunLoopCommonModes];
}
- (void)clearProgress {
    BHRDEndTransfer(self);
    [self.watchdog invalidate]; self.watchdog = nil;
    BHRDDismissDownloadProgress(self.hud); self.hud = nil;
}
- (void)stopWithError:(NSError *)error {
    if (![self.state cancel]) return;
    [self clearProgress];
    void (^completion)(MediaInformation *, NSError *) = self.probeCompletion;
    self.probeCompletion = nil;
    void (^downloadDone)(void) = self.downloadCompletion; self.downloadCompletion = nil;
    if (downloadDone) downloadDone();
    if (completion) completion(nil, error);
    else if (error.code != NSURLErrorCancelled) BHRDShowError(@"流媒体长时间没有进度，已停止下载。请检查网络后重试。");
}
- (void)cancel { [self stopWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]]; }
- (void)bindSessionID:(long)sessionID {
    // Registration after a cancellation still cancels this exact session. Never
    // call the parameterless API: it would cancel unrelated FFmpeg jobs too.
    self.state.cancelHandler = ^{ if (sessionID > 0) [FFmpegKit cancel:sessionID]; };
}
+ (instancetype)probeURL:(NSURL *)url completion:(void (^)(MediaInformation *, NSError *))completion {
    BHRDStreamJob *job = [BHRDStreamJob new];
    job.probeCompletion = completion;
    if (!BHRDTryBeginTransfer(job)) {
        dispatch_async(dispatch_get_main_queue(), ^{ job.probeCompletion = nil; completion(nil, [NSError errorWithDomain:@"BHRDBusy" code:1 userInfo:nil]); });
        return job;
    }
    [job beginProgress:@"正在读取清晰度…" timeout:45];
    MediaInformationSession *session = [FFprobeKit getMediaInformationAsync:url.absoluteString withCompleteCallback:^(MediaInformationSession *finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![job.state finish]) return;
            [job clearProgress];
            void (^callback)(MediaInformation *, NSError *) = job.probeCompletion;
            job.probeCompletion = nil;
            MediaInformation *info = [finished getMediaInformation];
            if (callback) callback(info, info ? nil : [NSError errorWithDomain:@"BHRDStream" code:1 userInfo:nil]);
        });
    }];
    [job bindSessionID:[session getSessionId]];
    return job;
}
+ (instancetype)downloadURL:(NSURL *)url streamIndex:(NSNumber *)index completion:(void (^)(void))completion {
    BHRDStreamJob *job = [BHRDStreamJob new];
    job.downloadCompletion = completion;
    if (!BHRDTryBeginTransfer(job)) {
        dispatch_async(dispatch_get_main_queue(), ^{ job.downloadCompletion = nil; if (completion) completion(); BHRDShowError(@"已有下载任务进行中，请等待完成或点击进度提示取消。"); });
        return job;
    }
    [job beginProgress:@"正在下载流媒体…" timeout:60];
    NSURL *output = BHRDNewDownloadURL(YES);
    NSArray *args = BHRDStreamArguments(url, index, output);
    if (!args) { BHRDDiscardDownload(output); dispatch_async(dispatch_get_main_queue(), ^{ [job stopWithError:[NSError errorWithDomain:@"BHRDStream" code:1 userInfo:nil]]; }); return job; }
    FFmpegSession *session = [FFmpegKit executeWithArgumentsAsync:args withCompleteCallback:^(FFmpegSession *finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![job.state finish]) {
                BHRDDiscardDownload(output);
                return;
            }
            [job clearProgress];
            void (^done)(void) = job.downloadCompletion; job.downloadCompletion = nil;
            if (done) done();
            if ([ReturnCode isSuccess:[finished getReturnCode]]) {
                NSURL *ready = BHRDCompleteDownload(output);
                if (!ready) { BHRDShowError(@"无法整理下载文件，请检查存储空间。"); return; }
                if ([BHRDManager DirectSave]) [BHRDManager save:ready]; else [BHRDManager showSaveVC:ready];
            } else {
                BHRDDiscardDownload(output);
                BHRDShowError(@"流媒体下载失败，请检查网络或选择普通视频下载后重试。");
            }
        });
    } withLogCallback:nil withStatisticsCallback:^(Statistics *stats) {
        long size = [stats getSize];
        double time = [stats getTime];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (job.state.finished) return;
            if (size > job.lastSize || time > job.lastMediaTime) {
                job.lastProgress = NSProcessInfo.processInfo.systemUptime;
                job.lastSize = size; job.lastMediaTime = time;
            }
            BHRDUpdateDownloadProgress(job.hud, [NSString stringWithFormat:@"已处理 %.0f 秒", time / 1000.0]);
        });
    }];
    [job bindSessionID:[session getSessionId]];
    return job;
}
@end
