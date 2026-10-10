#import "BHRDStreamJob.h"
#import "BHRDTaskState.h"
#import "BHRDDownloadProgress.h"
#import "BHRDManager.h"
#import "BHRDStreamArguments.h"
#import "BHRDDownloadStore.h"
#import "BHRDAvatarDiagnostics.h"
#import "BHRDAcceptance.h"
#import "../ffmpeg/FFmpegKit.h"
#import "../ffmpeg/FFprobeKit.h"
#import "../ffmpeg/MediaInformationSession.h"
#import "../ffmpeg/StreamInformation.h"

static NSDictionary *EngineFields(id<Session> session) {
    if (!session) return @{@"engineState":@"not_bound"};
    NSString *state=@[@"created",@"running",@"failed",@"completed"][MIN((NSUInteger)[session getState],(NSUInteger)3)];
    NSMutableDictionary *fields=[@{@"engineState":state,@"sessionID":@([session getSessionId]),@"engineDurationMs":@([session getDuration])} mutableCopy];
    if ([session getReturnCode]) fields[@"returnCode"]=@([[session getReturnCode] getValue]);
    return fields;
}
static dispatch_queue_t ProbeQueue(void) {
    static dispatch_queue_t queue; static dispatch_once_t once;
    dispatch_once(&once,^{ queue=dispatch_queue_create("com.caun.xsuixin.stream-probe",DISPATCH_QUEUE_SERIAL); }); return queue;
}
@interface BHRDStreamJob ()
@property(nonatomic,strong) BHRDTaskState *state;
@property(nonatomic,strong) JGProgressHUD *hud;
@property(nonatomic,strong) NSTimer *watchdog;
@property(nonatomic,strong) id<Session> engineSession;
@property(nonatomic) NSTimeInterval started,lastProgress,lastLoggedProgress;
@property(nonatomic) long lastSize;
@property(nonatomic) double lastMediaTime;
@property(nonatomic,copy) NSString *phase,*jobID,*acceptanceSession;
@property(nonatomic,strong) NSMutableOrderedSet *diagnosticCategories;
@property(nonatomic,copy) void (^downloadCompletion)(void);
@property(nonatomic,copy) void (^probeCompletion)(MediaInformation *,NSError *);
@end
@implementation BHRDStreamJob
- (instancetype)init {
    if ((self=[super init])) {
        _state=[BHRDTaskState new]; _started=NSProcessInfo.processInfo.systemUptime; _jobID=NSUUID.UUID.UUIDString;
        _acceptanceSession=BHRDAcceptanceCurrentSessionIdentifier(); _diagnosticCategories=[NSMutableOrderedSet orderedSet];
    } return self;
}
- (void)log:(NSString *)event extra:(NSDictionary *)extra {
    NSMutableDictionary *fields=[@{@"job":self.jobID,@"acceptanceSession":self.acceptanceSession,@"phase":self.phase ?: @"",
        @"elapsedMs":@(MAX(0,NSProcessInfo.processInfo.systemUptime-self.started)*1000)} mutableCopy];
    [fields addEntriesFromDictionary:EngineFields(self.engineSession)];
    NSDate *engineStart=[self.engineSession getStartTime];
    if (engineStart) fields[@"engineStarted"]=@YES;
    else if (self.engineSession) fields[@"engineStarted"]=@NO;
    @synchronized(self) { fields[@"diagnosticTail"]=[self.diagnosticCategories.array copy]; }
    [fields addEntriesFromDictionary:extra ?: @{}]; BHRDAvatarLog(event,fields);
}
- (void)receiveLog:(Log *)entry {
    int level=[entry getLevel]; if (level<0 || level>16) return; // FFmpeg panic/fatal/error only; never JSON/progress output.
    NSString *category=BHRDStreamDiagnosticCategory([entry getMessage]); if (!category) return;
    @synchronized(self) { if (self.diagnosticCategories.count<8) [self.diagnosticCategories addObject:category]; }
}
- (void)beginProgress:(NSString *)title timeout:(NSTimeInterval)timeout {
    __weak BHRDStreamJob *weakSelf=self;
    self.hud=BHRDShowDownloadProgress(title,^{ [weakSelf cancel]; }); self.lastProgress=NSProcessInfo.processInfo.systemUptime;
    self.watchdog=[NSTimer timerWithTimeInterval:5 repeats:YES block:^(__unused NSTimer *timer) {
        BHRDStreamJob *job=weakSelf; if (!job || job.state.finished) return;
        NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
        if ([job.phase isEqual:@"probe"]) {
            BOOL queued=job.engineSession && [job.engineSession getState]==SessionStateCreated;
            BHRDUpdateDownloadProgress(job.hud,[NSString stringWithFormat:queued ? @"等待探测启动… %.0f 秒" : @"读取流媒体清晰度… %.0f 秒",now-job.started]);
            [job log:@"stream_probe_wait" extra:nil];
        }
        if (now-job.lastProgress>=timeout) {
            [job log:@"stream_job_timeout" extra:@{@"watchdogSeconds":@(timeout)}];
            [job stopWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]];
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:self.watchdog forMode:NSRunLoopCommonModes];
}
- (void)clearProgress {
    BHRDEndTransfer(self); [self.watchdog invalidate]; self.watchdog=nil;
    BHRDDismissDownloadProgress(self.hud); self.hud=nil; self.engineSession=nil;
}
- (void)stopWithError:(NSError *)error {
    if (![self.state cancel]) return;
    NSString *result=error.code==NSURLErrorCancelled ? @"cancelled" : error.code==NSURLErrorTimedOut ? @"timeout" : @"failed";
    [self log:[@"stream_" stringByAppendingFormat:@"%@_result",self.phase] extra:@{@"result":result,@"success":@NO,@"errorDomain":error.domain ?: @"",@"errorCode":@(error.code)}];
    [self clearProgress];
    void (^completion)(MediaInformation *,NSError *)=self.probeCompletion; self.probeCompletion=nil;
    void (^done)(void)=self.downloadCompletion; self.downloadCompletion=nil; if (done) done();
    if (completion) completion(nil,error);
    else if (error.code!=NSURLErrorCancelled) BHRDShowError(@"流媒体长时间没有进度，已停止下载。可选择原生 MP4 清晰度或导出诊断排查网络。");
}
- (void)cancel {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{ [self cancel]; }); return; }
    if (!self.state.finished) [self log:@"stream_job_cancel" extra:nil];
    [self stopWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
}
- (void)bindSession:(id<Session>)session {
    self.engineSession=session; long sessionID=[session getSessionId];
    self.state.cancelHandler=^{ if (sessionID>0) [FFmpegKit cancel:sessionID]; };
    [self log:[@"stream_" stringByAppendingFormat:@"%@_bound",self.phase] extra:nil];
    if (self.state.finished) self.engineSession=nil;
}
+ (instancetype)probeURL:(NSURL *)url completion:(void (^)(MediaInformation *,NSError *))completion {
    BHRDStreamJob *job=[self new]; job.phase=@"probe"; job.probeCompletion=completion;
    [job log:@"stream_probe_start" extra:@{@"readTimeoutMs":@15000,@"watchdogSeconds":@45}];
    if (!BHRDTryBeginTransfer(job)) {
        dispatch_async(dispatch_get_main_queue(),^{
            if (![job.state finish]) return;
            job.probeCompletion=nil; [job log:@"stream_probe_result" extra:@{@"result":@"busy",@"success":@NO,@"errorDomain":@"BHRDBusy",@"errorCode":@1}];
            completion(nil,[NSError errorWithDomain:@"BHRDBusy" code:1 userInfo:nil]);
        }); return job;
    }
    NSArray *args=BHRDStreamProbeArguments(url);
    if (!args) { dispatch_async(dispatch_get_main_queue(),^{ [job stopWithError:[NSError errorWithDomain:@"BHRDStream" code:1 userInfo:nil]]; }); return job; }
    [job beginProgress:@"正在读取流媒体清晰度…" timeout:45];
    MediaInformationSession *session=[FFprobeKit getMediaInformationFromCommandArgumentsAsync:args withCompleteCallback:^(MediaInformationSession *finished) {
        dispatch_async(dispatch_get_main_queue(),^{
            NSMutableDictionary *fields=[EngineFields(finished) mutableCopy]; fields[@"late"]=@(job.state.finished); [job log:@"stream_probe_callback" extra:fields];
            if (![job.state finish]) return;
            MediaInformation *info=[finished getMediaInformation]; NSUInteger videos=0;
            for (StreamInformation *stream in [info getStreams])
                if ([[stream getType] isEqual:@"video"] && [stream getIndex] && [[stream getIndex] integerValue]>=0 && [[stream getWidth] integerValue]>0 && [[stream getHeight] integerValue]>0) videos++;
            BOOL success=info!=nil && videos>0 && [ReturnCode isSuccess:[finished getReturnCode]];
            if (!success) @synchronized(job) { if (!job.diagnosticCategories.count) [job.diagnosticCategories addObject:@"unclassified_error_output"]; }
            fields[@"success"]=@(success); fields[@"result"]=success ? @"success" : @"failed";
            fields[@"streamCount"]=@([[info getStreams] count]); fields[@"videoStreamCount"]=@(videos);
            if (!videos) fields[@"reason"]=@"missing_video_dimensions";
            fields[@"errorDomain"]=success ? @"" : @"BHRDStream"; fields[@"errorCode"]=success ? @0 : @1;
            [job log:@"stream_probe_result" extra:fields];
            void (^callback)(MediaInformation *,NSError *)=job.probeCompletion; job.probeCompletion=nil; [job clearProgress];
            if (callback) callback(success ? info : nil,success ? nil : [NSError errorWithDomain:@"BHRDStream" code:1 userInfo:nil]);
        });
    } withLogCallback:^(Log *entry) { [job receiveLog:entry]; } onDispatchQueue:ProbeQueue() withTimeout:1000];
    // withTimeout controls FFmpegKit message delivery, not network execution.
    [job bindSession:session]; return job;
}
+ (instancetype)downloadURL:(NSURL *)url streamIndex:(NSNumber *)index completion:(void (^)(void))completion {
    BHRDStreamJob *job=[self new]; job.phase=@"download"; job.downloadCompletion=completion; [job log:@"stream_download_start" extra:nil];
    if (!BHRDTryBeginTransfer(job)) {
        dispatch_async(dispatch_get_main_queue(),^{ if (![job.state finish]) return; job.downloadCompletion=nil;
            [job log:@"stream_download_result" extra:@{@"result":@"busy",@"success":@NO,@"errorDomain":@"BHRDBusy",@"errorCode":@1}];
            if (completion) completion(); BHRDShowError(@"已有下载任务进行中，请等待完成或点击进度提示取消。");
        }); return job;
    }
    [job beginProgress:@"正在下载流媒体…" timeout:60]; NSURL *output=BHRDNewDownloadURL(YES); NSArray *args=BHRDStreamArguments(url,index,output);
    if (!args) { BHRDDiscardDownload(output); dispatch_async(dispatch_get_main_queue(),^{ [job stopWithError:[NSError errorWithDomain:@"BHRDStream" code:1 userInfo:nil]]; }); return job; }
    FFmpegSession *session=[FFmpegKit executeWithArgumentsAsync:args withCompleteCallback:^(FFmpegSession *finished) {
        dispatch_async(dispatch_get_main_queue(),^{
            NSMutableDictionary *fields=[EngineFields(finished) mutableCopy]; fields[@"late"]=@(job.state.finished); [job log:@"stream_download_callback" extra:fields];
            if (![job.state finish]) { BHRDDiscardDownload(output); return; }
            unsigned long long fileBytes=[[NSFileManager.defaultManager attributesOfItemAtPath:output.path error:NULL][NSFileSize] unsignedLongLongValue];
            NSURL *ready=[ReturnCode isSuccess:[finished getReturnCode]] && fileBytes>0 ? BHRDCompleteDownload(output) : nil;
            BOOL success=ready!=nil; fields[@"success"]=@(success); fields[@"result"]=success ? @"success" : @"failed"; fields[@"bytes"]=@(fileBytes);
            if (!success) @synchronized(job) { if (!job.diagnosticCategories.count) [job.diagnosticCategories addObject:@"unclassified_error_output"]; }
            fields[@"errorDomain"]=success ? @"" : @"BHRDStream"; fields[@"errorCode"]=success ? @0 : @2;
            [job log:@"stream_download_result" extra:fields]; void (^done)(void)=job.downloadCompletion; job.downloadCompletion=nil; [job clearProgress]; if (done) done();
            if (ready) { if ([BHRDManager DirectSave]) [BHRDManager save:ready]; else [BHRDManager showSaveVC:ready]; }
            else { BHRDDiscardDownload(output); BHRDShowError(@"流媒体下载失败，请检查网络或选择原生 MP4 清晰度，诊断日志已记录失败阶段。"); }
        });
    } withLogCallback:^(Log *entry) { [job receiveLog:entry]; } withStatisticsCallback:^(Statistics *stats) {
        long size=[stats getSize]; double time=[stats getTime];
        dispatch_async(dispatch_get_main_queue(),^{
            if (job.state.finished) return;
            NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
            if (size>job.lastSize || time>job.lastMediaTime) { job.lastProgress=now; job.lastSize=size; job.lastMediaTime=time; }
            if (now-job.lastLoggedProgress>=5) { job.lastLoggedProgress=now; [job log:@"stream_download_progress" extra:@{@"bytes":@(size),@"mediaTimeMs":@(time)}]; }
            BHRDUpdateDownloadProgress(job.hud,[NSString stringWithFormat:@"已处理 %.0f 秒",time/1000]);
        });
    }]; [job bindSession:session]; return job;
}
@end
