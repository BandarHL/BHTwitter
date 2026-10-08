#import "BHRDAcceptance.h"
#import "BHRDBuildInfo.h"
#import <math.h>

static NSMutableDictionary *State;
static NSDictionary *CurrentBoot;
static NSString *ProcessIdentity;
static char QueueKey;
static dispatch_queue_t Queue(void) {
    static dispatch_queue_t queue; static dispatch_once_t once;
    dispatch_once(&once,^{ queue=dispatch_queue_create("com.caun.xsuixin.acceptance",DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(queue,&QueueKey,&QueueKey,NULL); });
    return queue;
}
static NSString *BasePath(void) {
#if BHRD_ACCEPTANCE_TEST
    NSString *base=NSProcessInfo.processInfo.environment[@"BHRD_ACCEPTANCE_TEST_DIR"];
#else
    NSString *base=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/XSuixinAcceptance"];
#endif
    return base;
}
static NSDictionary *Build(void) {
    return @{@"version":BHRD_BUILD_VERSION,@"revision":BHRD_BUILD_REVISION,@"commit":BHRD_BUILD_COMMIT};
}
static NSArray *Definitions(void) {
    return @[@[@"photo_permission",@"照片添加权限"],@[@"photo_save",@"照片保存结果"],
        @[@"recovery_gesture",@"三指长按恢复菜单"],@[@"pause_restart",@"暂停后重启"],
        @[@"resume_restart",@"恢复后重启"],@[@"repost_detail",@"隐藏转推详情与返回"],
        @[@"video_resolution",@"全屏视频读取与菜单"],
        @[@"performance",@"连续使用与性能"],@[@"log_export",@"验收报告导出"]];
}
static NSNumber *Number(id value) {
    return [value isKindOfClass:NSNumber.class] && isfinite([value doubleValue]) ? value : nil;
}
static NSString *SafeDomain(id value) {
    if (![value isKindOfClass:NSString.class] || ![value length] || [value length]>128) return @"";
    NSCharacterSet *safe=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"];
    return [value rangeOfCharacterFromSet:safe.invertedSet].location==NSNotFound ? value : @"redacted";
}
static NSString *UUID(id value) {
    return [value isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:value] ? value : nil;
}
static NSDictionary *Environment(void) {
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    for (NSArray *field in @[@[@"appVersion",@"CFBundleShortVersionString"],@[@"appBuild",@"CFBundleVersion"]]) {
        id value=[NSBundle.mainBundle objectForInfoDictionaryKey:field[1]];
        result[field[0]]=[value isKindOfClass:NSString.class] && [value length]<=64 ? value : @"unknown";
    }
    result[@"os"]=NSProcessInfo.processInfo.operatingSystemVersionString;
    return result;
}
static NSDictionary *StageDetails(void) {
    return @{@"not_observed":@"尚未观察到实际操作",@"restart_result_unconfirmed":@"进程已重新启动，上一操作最终结果未观察到，请实际核对。",
        @"boot_confirmed":@"下一次启动的暂停标记与功能注入状态已确认符合预期。",@"boot_mismatch":@"重启后的暂停标记或注入状态与预期不一致。",
        @"source_selection":@"已开始保存，正在取得选中的图片。",@"original_fetch_failed":@"原图请求失败，等待当前图回退或最终结果。",
        @"image_downloaded":@"已取得图片数据，等待校验与权限检查。",@"payload_validated":@"图片格式已验证，等待照片权限。",
        @"displayed_fallback_pending":@"原图不可保存，等待当前图回退确认或取消。",@"payload_invalid":@"图片数据无效或格式不受支持，尚未提交写入。",
        @"add_only_authorized":@"运行时已获得添加照片权限。",@"permission_pending":@"等待照片添加权限结果。",
        @"permission_denied":@"添加照片权限未获得，请在系统设置允许 X 添加照片后重试。",@"permission_granted":@"添加照片权限已获得，等待提交。",
        @"photos_commit":@"已提交 Photos 写入，尚未收到系统完成回调。",@"photos_completed":@"Photos 系统回调确认写入成功，图片内容正确仍需实际核对。",
        @"selection_cancelled":@"提交前切换图片或退出全屏，本次操作已取消。",@"usage_description_missing":@"宿主缺少照片权限说明，已阻止请求。",
        @"photos_failed":@"保存未完成，请结合错误域、错误码及日志排查。",@"gesture_received":@"已收到三指长按，并已展示恢复菜单。",
        @"menu_presentation_failed":@"已收到三指长按，但恢复菜单没有成功展示。",@"automatic_menu":@"恢复菜单自动打开，仍需亲自确认手势。",
        @"restart_pending":@"标记已保存，等待彻底退出并重开 X 验证。",@"flag_write_failed":@"暂停/恢复标记保存失败。",
        @"return_row_unavailable":@"返回时目标行不可见，尚无法核对隐藏状态，请滚回该行或人工确认。",
        @"native_selection_sent":@"已交给 X 原生选择回调，等待详情实际出现。",@"navigation_unavailable":@"当前行已复用或 X 原生选择入口不可用。",
        @"detail_visible":@"同一次点击对应的详情页面已确认，等待返回验证隐藏状态。",@"detail_identity_unavailable":@"详情身份无法与本次点击对应，请人工核对。",
        @"detail_identity_mismatch":@"详情页面的帖子身份与本次点击请求不一致，请导出日志。",@"confirmation_timeout":@"等待详情确认超过 15 秒，尚未取得可匹配证据，请核对实际页面并导出日志。",
        @"navigation_unconfirmed":@"已观察返回，但详情身份或返回身份未确认，请人工核对。",@"return_hidden_preserved":@"已确认对应详情并返回，转推仍保持隐藏缩略图。",
        @"return_expanded":@"返回后未保持隐藏状态，请导出日志。",@"runtime_warning":@"已观察到卡顿阈值或内存警告，请结合样本排查。",
        @"video_resolution_started":@"已点击全屏视频按钮，正在读取当前可见视频的播放器和媒体资料。",
        @"video_media_resolved":@"已读取到当前视频的可下载媒体，正在等待质量菜单实际呈现；尚未开始传输。",
        @"video_menu_presented":@"当前视频的下载质量菜单已经实际呈现；此结果不表示视频传输完成或已保存到照片。",
        @"video_host_unverified":@"没有确认当前页面是全屏媒体页面，已停止读取以避免选择错误视频。",
        @"video_host_detached":@"全屏页面已经离屏、隐藏或没有有效显示区域，无法读取当前视频。",
        @"video_source_missing":@"当前可见区域没有找到有效的视频播放器或媒体模型；视频播放正常时请导出日志排查入口。",
        @"video_player_unresolved":@"已经找到当前可见播放器，但未取得其当前视频资源；请等待视频加载后重试并导出日志。",
        @"video_model_unresolved":@"已经找到当前视频模型，但模型尚未提供可下载媒体资料；请导出日志排查缺失字段。",
        @"video_inline_mismatch":@"当前原生操作栏的媒体与播放来源不一致，已阻止借用其他帖子的下载参数。",
        @"video_bound_unavailable":@"当前操作栏已绑定帖子，但下载参数尚未加载；悬浮入口仍保留，可再次点击。",
        @"video_sources_conflict":@"可见区域中出现了互相冲突的视频资源，已停止读取以避免下载其他视频。",
        @"video_current_item_unavailable":@"已经找到绑定的播放器项目，但当前项目的资源地址尚不可读取；不会使用旧帖子的资料替代当前视频。",
        @"video_asset_unsupported":@"已经找到当前资源，但资源来源或格式不在当前支持范围；请导出日志核对实际播放资源。",
        @"video_assets_ambiguous":@"当前播放来源给出了多个不同的资源地址，无法确认正在播放哪一个，已停止读取。",
        @"video_media_ambiguous":@"当前媒体模型给出了多个不同的视频，无法确定当前选中的视频，已停止读取。",
        @"video_current_source_missing":@"读取时当前播放来源已经不存在，可能正在切换或回收，请停止滑动后重试。",
        @"video_resource_missing":@"当前可见播放来源和媒体模型均没有提供可下载的视频资源；请导出日志排查模型字段。",
        @"video_pager_unsettled":@"当前视频分页仍在滑动过渡，无法稳定确认当前页；请停止滑动后重新点击。",
        @"video_layer_scan_limited":@"读取当前播放器图层时达到扫描数量限制，尚不能确定当前资源；请导出日志排查视图结构。",
        @"video_source_scan_limited":@"读取可见视频视图时达到扫描数量限制，尚不能确定当前来源；请导出日志排查视图结构。",
        @"video_resource_scan_limited":@"读取当前播放包装时达到节点或深度限制，尚不能排除资源冲突；请导出日志排查包装结构。",
        @"video_scan_thread_invalid":@"视频视图读取未在主线程执行，已停止读取；请导出日志排查调用入口。",
        @"video_source_unavailable":@"最终仍未读取到可下载的当前视频；请核对播放状态并导出日志定位读取阶段。",
        @"video_menu_failed":@"当前视频资料已读取，但下载菜单没有成功呈现；请导出日志定位菜单显示阶段。",
        @"video_context_cancelled":@"读取期间已切换视频、离开全屏或取消操作，本次没有继续打开下载菜单。",
        @"video_selection_changed":@"读取期间当前视频已改变，本次请求已取消，以避免为其他视频打开下载菜单。",
        @"video_viewer_inactive":@"读取期间已经离开全屏或关闭下载功能，本次请求已取消，没有继续打开菜单。",
        @"samples_observed":@"正在收集实际使用样本，仍需你确认实际体验。",@"sampling_finished":@"采样已结束，已有样本待你确认实际体验。",
        @"report_generated":@"已生成脱敏报告，等待系统分享结果。",@"share_presented":@"系统分享面板已打开，等待操作完成。",
        @"share_completed":@"系统分享活动已完成，接收端是否收到仍需人工确认。",@"share_cancelled":@"本次分享已取消，可重新导出。",
        @"share_failed":@"报告生成或系统分享失败，请查看错误域和码。",@"user_confirmed":@"你已确认实际操作和结果符合预期（人工确认）。",
        @"user_reported_failure":@"你已报告实际结果未通过（人工记录），请导出报告和日志。"};
}
static NSString *PersistedDomain(id value) {
    static NSSet *known; static dispatch_once_t once;
    dispatch_once(&once,^{ known=[NSSet setWithArray:@[@"NSCocoaErrorDomain",@"NSURLErrorDomain",@"PHPhotosErrorDomain",
        @"com.caun.xsuixin.photo-save",@"XSuixinSafety",@"PhotosError",@"redacted"]]; });
    return [value isKindOfClass:NSString.class] && [known containsObject:value] ? value : @"redacted";
}
static NSDictionary *CleanError(id value) {
    if (![value isKindOfClass:NSDictionary.class]) return nil;
    return @{@"domain":PersistedDomain(value[@"domain"]),@"code":Number(value[@"code"]) ?: @0};
}
static NSString *MappedItem(NSString *event);
static NSMutableDictionary *EventEntry(NSString *event,NSDictionary *fields,NSNumber *time);
static NSDictionary *VideoReasonStages(void) {
    return @{@"unverified_fullscreen_host":@"video_host_unverified",@"detached_or_hidden_host":@"video_host_detached",
        @"no_visible_video_source":@"video_source_missing",@"visible_player_unresolved":@"video_player_unresolved",
        @"current_model_unresolved":@"video_model_unresolved",@"conflicting_visible_resources":@"video_sources_conflict",
        @"current_item_resource_unavailable":@"video_current_item_unavailable",@"unsupported_current_asset":@"video_asset_unsupported",
        @"ambiguous_current_assets":@"video_assets_ambiguous",@"ambiguous_current_media":@"video_media_ambiguous",
        @"no_current_source":@"video_current_source_missing",@"no_current_video_resource":@"video_resource_missing",
        @"pager_transition_unsettled":@"video_pager_unsettled",@"layer_scan_budget_exceeded":@"video_layer_scan_limited",
        @"source_scan_budget_exceeded":@"video_source_scan_limited",
        @"resource_scan_budget_exceeded":@"video_resource_scan_limited",@"fullscreen_scan_requires_main_thread":@"video_scan_thread_invalid",
        @"inline_identity_mismatch":@"video_inline_mismatch",@"bound_media_unavailable":@"video_bound_unavailable",
        @"menu_presentation_failed":@"video_menu_failed"};
}
static NSDictionary *VideoCancellationStages(void) {
    return @{@"selection_changed":@"video_selection_changed",@"viewer_inactive":@"video_viewer_inactive"};
}
static NSMutableDictionary *NewItem(NSString *key,NSString *title) {
    return [@{@"id":key,@"title":title,@"status":@"pending",@"stage":@"not_observed",
        @"detail":@"尚未观察到实际操作",@"attempts":@0,@"successCount":@0,@"failureCount":@0,
        @"cancelledCount":@0,@"lastOutcome":@"none",@"manualConfirmed":@NO} mutableCopy];
}
static NSMutableDictionary *NewState(NSString *mode) {
    NSMutableArray *items=[NSMutableArray array];
    for (NSArray *definition in Definitions()) [items addObject:NewItem(definition[0],definition[1])];
    return [@{@"schema":@1,@"sessionID":NSUUID.UUID.UUIDString,@"mode":mode,
        @"startedAt":@(NSDate.date.timeIntervalSince1970),@"build":Build(),@"environment":Environment(),@"items":items,
        @"launches":[NSMutableArray array],@"events":[NSMutableArray array],@"observationCount":@0} mutableCopy];
}
static id Clone(id object) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    return data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL] : nil;
}
static void Save(void) {
    NSString *base=BasePath(); if (!base.length) return;
    NSError *error=nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:base withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) {
        State[@"storageError"]=@{@"domain":PersistedDomain(error.domain),@"code":@(error.code)}; return;
    }
    [State removeObjectForKey:@"storageError"];
    NSData *data=[NSJSONSerialization dataWithJSONObject:State options:0 error:&error];
    NSString *path=[base stringByAppendingPathComponent:@"acceptance.json"];
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        State[@"storageError"]=@{@"domain":PersistedDomain(error.domain),@"code":@(error.code)}; return;
    }
    [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:path error:NULL];
    [State removeObjectForKey:@"storageError"];
}
static void Initialize(void) {
    if (State) return;
    NSString *path=[BasePath() stringByAppendingPathComponent:@"acceptance.json"];
    unsigned long long size=[[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL][NSFileSize] unsignedLongLongValue];
    NSData *data=size && size<256*1024 ? [NSData dataWithContentsOfFile:path] : nil;
    NSDictionary *saved=data.length && data.length<256*1024 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    // The file is private, but decode only our known shape before trusting it.
    if ([saved isKindOfClass:NSDictionary.class] && [saved[@"schema"] isEqual:@1] &&
        [saved[@"mode"] isEqual:@"session"] && UUID(saved[@"sessionID"]) && Number(saved[@"startedAt"]) &&
        [saved[@"build"] isEqual:Build()] &&
        [saved[@"items"] isKindOfClass:NSArray.class] && [saved[@"items"] count]==Definitions().count) {
        State=NewState(@"session"); State[@"sessionID"]=saved[@"sessionID"]; State[@"startedAt"]=saved[@"startedAt"];
        State[@"observationCount"]=@((NSUInteger)MAX(0,MIN([Number(saved[@"observationCount"]) doubleValue],1000000)));
        for (NSUInteger i=0;i<Definitions().count;i++) {
            id input=saved[@"items"][i]; NSArray *definition=Definitions()[i]; NSMutableDictionary *item=State[@"items"][i];
            if (![input isKindOfClass:NSDictionary.class] || ![input[@"id"] isEqual:definition[0]]) continue;
            NSString *status=[input[@"status"] isKindOfClass:NSString.class] ? input[@"status"] : nil;
            NSString *stage=[input[@"stage"] isKindOfClass:NSString.class] ? input[@"stage"] : nil;
            if (!status || !stage || ![@[@"pending",@"running",@"success",@"failed",@"cancelled",@"unsupported"] containsObject:status] || !StageDetails()[stage]) continue;
            item[@"status"]=status; item[@"stage"]=stage; item[@"detail"]=StageDetails()[stage];
            for (NSString *key in @[@"attempts",@"successCount",@"failureCount",@"cancelledCount"]) item[key]=@((NSUInteger)MAX(0,MIN([Number(input[key]) doubleValue],1000000)));
            for (NSString *key in @[@"updatedAt",@"lastSuccessAt",@"manualRecordedAt",@"observedSeconds",@"lastMemoryBytes",@"lastLagMs",@"memoryWarnings",@"frameIntervals",@"slowIntervalRatio",@"maxIntervalMs",@"currentFootprintMB",@"memoryMB",@"peakMemoryMB",@"playerCount",@"modelCount",@"visibleSourceCount"]) {
                NSNumber *number=Number(input[key]); if (number && number.doubleValue>=0) item[key]=number;
            }
            for (NSString *key in @[@"manualConfirmed",@"detailConfirmed",@"running",@"warningObserved",@"resolutionResolved",@"resolutionTerminal"]) if (Number(input[key])) item[key]=@([Number(input[key]) boolValue]);
            for (NSString *key in @[@"pendingAttempt",@"pendingBootID"]) if (UUID(input[key])) item[key]=input[key];
            NSString *outcome=[input[@"lastOutcome"] isKindOfClass:NSString.class] ? input[@"lastOutcome"] : @"none";
            if ([@[@"none",@"pending",@"running",@"success",@"failed",@"cancelled",@"unsupported",@"interrupted"] containsObject:outcome]) item[@"lastOutcome"]=outcome;
            if (CleanError(input[@"error"])) item[@"error"]=CleanError(input[@"error"]);
            if ([item[@"status"] isEqual:@"success"] && ![item[@"successCount"] unsignedIntegerValue]) { item[@"status"]=@"pending"; item[@"stage"]=@"not_observed"; item[@"detail"]=StageDetails()[@"not_observed"]; item[@"manualConfirmed"]=@NO; }
            if ([item[@"lastOutcome"] isEqual:@"cancelled"] && [item[@"successCount"] unsignedIntegerValue]) item[@"detail"]=[@"此前已有成功证据；本次操作已取消。" stringByAppendingString:item[@"detail"]];
            if ([item[@"lastOutcome"] isEqual:@"interrupted"] && [item[@"successCount"] unsignedIntegerValue]) item[@"detail"]=[@"此前已有成功证据；本次操作结果未确认。" stringByAppendingString:item[@"detail"]];
        }
        if ([saved[@"events"] isKindOfClass:NSArray.class]) for (id entry in saved[@"events"]) {
            if (![entry isKindOfClass:NSDictionary.class] || ![entry[@"event"] isKindOfClass:NSString.class]) continue;
            NSString *event=entry[@"event"];
            if (!MappedItem(event) && ![@[@"manual_pass",@"manual_fail"] containsObject:event]) continue;
            NSMutableDictionary *clean=EventEntry(event,entry,Number(entry[@"time"]) ?: @0);
            if (clean[@"errorDomain"]) clean[@"errorDomain"]=PersistedDomain(clean[@"errorDomain"]);
            [State[@"events"] addObject:clean]; if ([State[@"events"] count]>120) [State[@"events"] removeObjectAtIndex:0];
        }
        if ([saved[@"launches"] isKindOfClass:NSArray.class]) for (id launch in saved[@"launches"]) {
            if (![launch isKindOfClass:NSDictionary.class] || !UUID(launch[@"processID"]) || !Number(launch[@"paused"]) || !Number(launch[@"hooksEnabled"])) continue;
            [State[@"launches"] addObject:@{@"processID":launch[@"processID"],@"time":Number(launch[@"time"]) ?: @0,
                @"paused":@([Number(launch[@"paused"]) boolValue]),@"hooksEnabled":@([Number(launch[@"hooksEnabled"]) boolValue]),@"build":Build()}];
            if ([State[@"launches"] count]>20) [State[@"launches"] removeObjectAtIndex:0];
        }
        if (CleanError(saved[@"storageError"])) State[@"storageError"]=CleanError(saved[@"storageError"]);
    }
    if (!State) State=NewState(@"recent");
}
static void Sync(void (^operation)(void)) {
    dispatch_queue_t queue=Queue();
    if (dispatch_get_specific(&QueueKey)) { Initialize(); operation(); }
    else dispatch_sync(queue,^{ Initialize(); operation(); });
}
static NSMutableDictionary *Item(NSString *key) {
    for (NSMutableDictionary *item in State[@"items"]) if ([item[@"id"] isEqual:key]) return item;
    return nil;
}
static void Increment(NSMutableDictionary *item,NSString *key) {
    NSUInteger value=[Number(item[key]) unsignedIntegerValue]; item[key]=@(MIN(value+1,(NSUInteger)1000000));
}
static void Update(NSString *key,NSString *status,NSString *stage,NSString *detail,NSDictionary *fields) {
    NSMutableDictionary *item=Item(key); if (!item) return;
    NSString *outcome=status;
    if ([status isEqual:@"success"]) Increment(item,@"successCount");
    if ([status isEqual:@"failed"]) Increment(item,@"failureCount");
    if ([status isEqual:@"cancelled"]) {
        Increment(item,@"cancelledCount");
        if ([item[@"successCount"] unsignedIntegerValue]>0) { status=@"success"; detail=[@"此前已有成功证据；本次操作已取消。" stringByAppendingString:detail]; }
    }
    item[@"status"]=status; item[@"stage"]=stage; item[@"detail"]=detail;
    item[@"lastOutcome"]=outcome; item[@"updatedAt"]=@(NSDate.date.timeIntervalSince1970);
    if ([outcome isEqual:@"success"]) item[@"lastSuccessAt"]=item[@"updatedAt"];
    if ([fields[@"errorDomain"] isKindOfClass:NSString.class] && [fields[@"errorDomain"] length]) {
        item[@"error"]=@{@"domain":PersistedDomain(fields[@"errorDomain"]),@"code":Number(fields[@"errorCode"]) ?: @0};
    } else [item removeObjectForKey:@"error"];
}
static NSString *MappedItem(NSString *event) {
    static NSSet *supported; static dispatch_once_t once;
    dispatch_once(&once,^{ supported=[NSSet setWithArray:@[@"photo_save_start",@"photo_save_fetch",@"photo_save_prepare",
        @"photo_save_authorization",@"photo_save_committed",@"photo_save_result",@"recovery_invoked",
        @"safety_pause_changed",@"acceptance_boot",@"resume_pending",@"repost_detail_navigation",
        @"repost_detail_visible",@"repost_detail_return",@"repost_detail_confirmation_timeout",@"performance_started",@"performance_sample",
        @"performance_finished",@"performance_result",@"performance_memory_warning",@"acceptance_export",@"fullscreen_video_resolution"]]; });
    if (![supported containsObject:event]) return nil;
    if ([event hasPrefix:@"photo_save_"]) return @"photo_save";
    if ([event hasPrefix:@"repost_detail_"]) return @"repost_detail";
    if ([event isEqual:@"recovery_invoked"]) return @"recovery_gesture";
    if ([event hasPrefix:@"performance_"]) return @"performance";
    if ([event isEqual:@"safety_pause_changed"] || [event isEqual:@"acceptance_boot"] || [event isEqual:@"resume_pending"]) return @"safety";
    if ([event isEqual:@"acceptance_export"]) return @"log_export";
    if ([event isEqual:@"fullscreen_video_resolution"]) return @"video_resolution";
    return nil;
}
static NSMutableDictionary *EventEntry(NSString *event,NSDictionary *fields,NSNumber *time) {
    NSMutableDictionary *entry=[@{@"event":event,@"time":time} mutableCopy];
    for (NSString *key in @[@"bytes",@"width",@"height",@"status",@"success",@"committed",@"valid",
        @"paused",@"hooksEnabled",@"hooksEnabledAtLaunch",@"hiddenPreserved",@"durationSeconds",
        @"memoryBytes",@"lagMs",@"memoryWarnings",@"thresholdExceeded",@"visibleSeconds",@"frameIntervals",
        @"slowIntervalRatio",@"maxIntervalMs",@"currentFootprintMB",@"memoryMB",@"peakMemoryMB",@"presented",@"confirmed",@"observable",@"playerCount",@"modelCount",@"visibleSourceCount"]) {
        if (Number(fields[key])) entry[key]=fields[key];
    }
    if (Number(fields[@"errorCode"])) entry[@"errorCode"]=fields[@"errorCode"];
    if ([fields[@"errorDomain"] isKindOfClass:NSString.class] && [fields[@"errorDomain"] length]) entry[@"errorDomain"]=PersistedDomain(fields[@"errorDomain"]);
    if (UUID(fields[@"attempt"])) entry[@"attempt"]=fields[@"attempt"];
    NSDictionary *enums=@{@"phase":@[@"generated",@"presented",@"completed",@"cancelled",@"failed",@"started",@"resolved",@"unavailable",@"menu_presented"],
        @"source":@[@"original",@"displayed",@"three_finger",@"paused_boot"],
        @"result":@[@"native_row_selection",@"stale_or_unavailable_row",@"native_selection_unavailable",@"return_row_not_observable",@"detail_identity_mismatch",@"detail_identity_unavailable"]};
    for (NSString *key in enums) if ([enums[key] containsObject:fields[key] ?: NSNull.null]) entry[key]=fields[key];
    id reason=fields[@"reason"] ?: NSNull.null;
    if ([VideoReasonStages().allKeys containsObject:reason] || [VideoCancellationStages().allKeys containsObject:reason] || [@[@"resolved_current_asset",@"resolved_current_media",@"resolved_inline_model",@"resolved_bound_media"] containsObject:reason]) entry[@"reason"]=reason;
    return entry;
}
static void AddEvent(NSString *event,NSDictionary *fields) {
    NSMutableDictionary *entry=EventEntry(event,fields,@(NSDate.date.timeIntervalSince1970));
    NSMutableArray *events=State[@"events"]; [events addObject:entry];
    while (events.count>120) [events removeObjectAtIndex:0];
    NSUInteger count=[Number(State[@"observationCount"]) unsignedIntegerValue]; State[@"observationCount"]=@(MIN(count+1,(NSUInteger)1000000));
}
static void HandleBoot(NSDictionary *fields) {
    BOOL paused=[Number(fields[@"paused"]) boolValue], hooks=[Number(fields[@"hooksEnabled"]) boolValue];
    if (!ProcessIdentity) ProcessIdentity=NSUUID.UUID.UUIDString;
    if ([CurrentBoot[@"processID"] isEqual:ProcessIdentity]) return;
    CurrentBoot=@{@"time":@(NSDate.date.timeIntervalSince1970),@"processID":ProcessIdentity,
        @"paused":@(paused),@"hooksEnabled":@(hooks),@"build":Build()};
    NSMutableArray *launches=State[@"launches"]; [launches addObject:CurrentBoot];
    while (launches.count>20) [launches removeObjectAtIndex:0];
    for (NSString *key in @[@"photo_save",@"repost_detail",@"video_resolution",@"performance",@"log_export"]) {
        NSMutableDictionary *item=Item(key);
        if ([item[@"status"] isEqual:@"running"]) {
            BOOL priorSuccess=[item[@"successCount"] unsignedIntegerValue]>0;
            Update(key,@"pending",@"restart_result_unconfirmed",
                @"进程已重新启动，上一操作的最终结果未观察到；请实际核对或重新操作。",@{});
            if (priorSuccess) { item[@"status"]=@"success"; item[@"detail"]=[@"此前已有成功证据；本次操作结果未确认。" stringByAppendingString:item[@"detail"]]; }
            item[@"lastOutcome"]=@"interrupted";
            if ([key isEqual:@"repost_detail"]) { [item removeObjectForKey:@"pendingAttempt"]; item[@"detailConfirmed"]=@NO; }
            if ([key isEqual:@"video_resolution"]) { [item removeObjectForKey:@"pendingAttempt"]; item[@"resolutionResolved"]=@NO; item[@"resolutionTerminal"]=@YES; }
            if ([key isEqual:@"performance"]) item[@"running"]=@NO;
        }
    }
    for (NSString *key in @[@"pause_restart",@"resume_restart"]) {
        NSMutableDictionary *item=Item(key);
        if (![item[@"status"] isEqual:@"running"] || ![item[@"stage"] isEqual:@"restart_pending"]) continue;
        if ([item[@"pendingBootID"] isEqual:ProcessIdentity]) continue;
        BOOL expectedPaused=[key isEqual:@"pause_restart"];
        BOOL valid=paused==expectedPaused && hooks!=expectedPaused;
        Update(key,valid ? @"success" : @"failed",valid ? @"boot_confirmed" : @"boot_mismatch",
            valid ? (expectedPaused ? @"下一次启动已确认暂停标记生效，功能注入被跳过。" : @"下一次启动已确认恢复标记生效，功能注入已启用。") : @"重启后的暂停标记或注入状态与预期不一致。",fields);
    }
}
static void HandleObservation(NSString *event,NSDictionary *fields) {
    if ([event isEqual:@"acceptance_boot"]) { HandleBoot(fields); return; }
    if ([event isEqual:@"fullscreen_video_resolution"]) {
        NSMutableDictionary *item=Item(@"video_resolution"); NSString *attempt=UUID(fields[@"attempt"]);
        id phase=fields[@"phase"]; if (!attempt) return;
        if ([phase isEqual:@"started"]) {
            if ([item[@"pendingAttempt"] isEqual:attempt]) return;
            item[@"pendingAttempt"]=attempt; item[@"resolutionResolved"]=@NO; item[@"resolutionTerminal"]=@NO; item[@"manualConfirmed"]=@NO;
            for (NSString *key in @[@"playerCount",@"modelCount",@"visibleSourceCount"]) item[key]=@0;
            Increment(item,@"attempts");
            Update(@"video_resolution",@"running",@"video_resolution_started",StageDetails()[@"video_resolution_started"],fields);
        } else if (![item[@"pendingAttempt"] isEqual:attempt] || [item[@"resolutionTerminal"] boolValue]) return;
        for (NSString *key in @[@"playerCount",@"modelCount",@"visibleSourceCount"]) {
            NSNumber *number=Number(fields[key]); if (number) item[key]=@((NSUInteger)MAX(0,MIN(number.doubleValue,1000000)));
        }
        if ([phase isEqual:@"resolved"]) {
            item[@"resolutionResolved"]=@YES;
            Update(@"video_resolution",@"running",@"video_media_resolved",StageDetails()[@"video_media_resolved"],fields);
        } else if ([phase isEqual:@"unavailable"]) {
            NSString *reason=[fields[@"reason"] isKindOfClass:NSString.class] ? fields[@"reason"] : @"";
            NSString *stage=VideoReasonStages()[reason] ?: @"video_source_unavailable";
            item[@"resolutionTerminal"]=@YES;
            Update(@"video_resolution",@"failed",stage,StageDetails()[stage],fields);
        } else if ([phase isEqual:@"menu_presented"] && [item[@"resolutionResolved"] boolValue]) {
            item[@"resolutionTerminal"]=@YES;
            Update(@"video_resolution",@"success",@"video_menu_presented",StageDetails()[@"video_menu_presented"],fields);
        } else if ([phase isEqual:@"cancelled"]) {
            NSString *reason=[fields[@"reason"] isKindOfClass:NSString.class] ? fields[@"reason"] : @"";
            NSString *stage=VideoCancellationStages()[reason] ?: @"video_context_cancelled";
            item[@"resolutionTerminal"]=@YES;
            Update(@"video_resolution",@"cancelled",stage,StageDetails()[stage],fields);
        }
    } else if ([event isEqual:@"photo_save_start"]) {
        Increment(Item(@"photo_save"),@"attempts");
        Update(@"photo_save",@"running",@"source_selection",@"已开始保存，正在取得选中的图片。",fields);
    } else if ([event isEqual:@"photo_save_fetch"]) {
        BOOL failed=[Number(fields[@"errorCode"]) integerValue]!=0;
        Update(@"photo_save",@"running",failed ? @"original_fetch_failed" : @"image_downloaded",
            failed ? @"原图请求失败，等待当前图回退或最终结果。" : @"已取得图片数据，等待校验与权限检查。",fields);
    } else if ([event isEqual:@"photo_save_prepare"]) {
        BOOL valid=[Number(fields[@"valid"]) boolValue];
        BOOL fallback=!valid && [fields[@"source"] isEqual:@"original"];
        Update(@"photo_save",valid || fallback ? @"running" : @"failed",valid ? @"payload_validated" : (fallback ? @"displayed_fallback_pending" : @"payload_invalid"),
            valid ? @"图片格式已验证，正在等待照片添加权限。" : (fallback ? @"原图数据不可保存，等待你确认当前图回退或取消。" : @"图片数据无效或格式不受支持，尚未提交照片写入。"),fields);
    } else if ([event isEqual:@"photo_save_authorization"]) {
        NSInteger status=[Number(fields[@"status"]) integerValue]; BOOL authorized=status==3 || status==4;
        Update(@"photo_permission",authorized ? @"success" : (status==0 ? @"running" : @"unsupported"),
            authorized ? @"add_only_authorized" : (status==0 ? @"permission_pending" : @"permission_denied"),
            authorized ? @"运行时已获得添加照片权限。" : @"添加照片权限未获得，请在系统设置允许 X 添加照片后重试。",fields);
        Update(@"photo_save",authorized ? @"running" : @"unsupported",authorized ? @"permission_granted" : @"permission_denied",
            authorized ? @"照片添加权限已获得，等待提交。" : @"操作受照片权限限制，未提交写入。",fields);
    } else if ([event isEqual:@"photo_save_committed"]) {
        Update(@"photo_save",@"running",@"photos_commit",@"已提交 Photos 写入，尚未收到系统完成回调。",fields);
    } else if ([event isEqual:@"photo_save_result"]) {
        BOOL success=[Number(fields[@"success"]) boolValue];
        NSInteger code=[Number(fields[@"errorCode"]) integerValue]; NSString *domain=SafeDomain(fields[@"errorDomain"]);
        BOOL own=[domain isEqual:@"com.caun.xsuixin.photo-save"];
        BOOL cancelled=own && code==4;
        NSString *status=success ? @"success" : (cancelled ? @"cancelled" : (own && (code==2 || code==3) ? @"unsupported" : @"failed"));
        NSString *stage=success ? @"photos_completed" : (cancelled ? @"selection_cancelled" : (own && code==2 ? @"usage_description_missing" : (own && code==3 ? @"permission_denied" : @"photos_failed")));
        NSString *detail=success ? @"Photos 系统回调确认写入成功；请到照片中核对实际图片。" :
            (cancelled ? @"提交前已切换图片或退出全屏，本次未写入。" :
             (own && code==2 ? @"宿主缺少照片权限说明，已阻止请求。" : (own && code==3 ? @"照片添加权限被拒绝，本次未写入。" : @"保存未完成，请结合错误域、错误码及导出的诊断日志排查。")));
        Update(@"photo_save",status,stage,detail,fields);
        if (own && (code==2 || code==3)) Update(@"photo_permission",@"unsupported",stage,detail,fields);
    } else if ([event isEqual:@"recovery_invoked"]) {
        BOOL gesture=[fields[@"source"] isEqual:@"three_finger"], presented=[Number(fields[@"presented"]) boolValue];
        NSMutableDictionary *item=Item(@"recovery_gesture");
        if (gesture) {
            Increment(item,@"attempts");
            Update(@"recovery_gesture",presented ? @"success" : @"failed",presented ? @"gesture_received" : @"menu_presentation_failed",
                presented ? @"运行时收到三指长按，并已展示恢复菜单。" : @"已收到三指长按，但恢复菜单没有成功展示。",fields);
        } else if (![item[@"successCount"] unsignedIntegerValue]) Update(@"recovery_gesture",@"running",@"automatic_menu",
            @"恢复菜单自动打开，仍需亲自三指长按确认手势。",fields);
    } else if ([event isEqual:@"safety_pause_changed"] || [event isEqual:@"resume_pending"]) {
        BOOL paused=[Number(fields[@"paused"]) boolValue]; NSString *key=paused ? @"pause_restart" : @"resume_restart";
        BOOL success=![event isEqual:@"safety_pause_changed"] || [Number(fields[@"success"]) boolValue];
        Increment(Item(key),@"attempts");
        if (!ProcessIdentity) ProcessIdentity=NSUUID.UUID.UUIDString;
        Item(key)[@"pendingBootID"]=ProcessIdentity;
        Update(key,success ? @"running" : @"failed",success ? @"restart_pending" : @"flag_write_failed",
            success ? @"标记已保存，等待彻底退出并重开 X 验证下一次启动。" : @"暂停/恢复标记保存失败，重启前请检查存储或错误信息。",fields);
    } else if ([event isEqual:@"repost_detail_navigation"]) {
        NSMutableDictionary *item=Item(@"repost_detail");
        if ([fields[@"result"] isEqual:@"return_row_not_observable"]) {
            if ([item[@"pendingAttempt"] isKindOfClass:NSString.class] && [fields[@"attempt"] isKindOfClass:NSString.class] && ![item[@"pendingAttempt"] isEqual:fields[@"attempt"]]) return;
            Update(@"repost_detail",@"pending",@"return_row_unavailable",@"返回时目标行不在可见区域，尚无法核对隐藏状态；请滚动回该行后再验收。",fields); return;
        }
        Increment(item,@"attempts");
        [item removeObjectForKey:@"pendingAttempt"]; item[@"detailConfirmed"]=@NO;
        if ([fields[@"attempt"] isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:fields[@"attempt"]]) item[@"pendingAttempt"]=fields[@"attempt"];
        BOOL selected=[fields[@"result"] isEqual:@"native_row_selection"];
        Update(@"repost_detail",selected ? @"running" : @"failed",selected ? @"native_selection_sent" : @"navigation_unavailable",
            selected ? @"已交给 X 原生帖子选择回调，等待详情实际出现。" : @"当前行已复用或 X 原生选择入口不可用。",fields);
    } else if ([event isEqual:@"repost_detail_visible"]) {
        NSMutableDictionary *item=Item(@"repost_detail");
        if ([item[@"pendingAttempt"] isKindOfClass:NSString.class] && [fields[@"attempt"] isKindOfClass:NSString.class] && ![item[@"pendingAttempt"] isEqual:fields[@"attempt"]]) return;
        BOOL matches=[item[@"pendingAttempt"] isKindOfClass:NSString.class] && [item[@"pendingAttempt"] isEqual:fields[@"attempt"]];
        BOOL confirmed=matches && [Number(fields[@"confirmed"]) boolValue];
        if (!confirmed && [item[@"detailConfirmed"] boolValue]) return;
        item[@"detailConfirmed"]=@(confirmed);
        if (matches && !confirmed && [fields[@"result"] isEqual:@"detail_identity_mismatch"]) {
            Update(@"repost_detail",@"failed",@"detail_identity_mismatch",@"详情页面的帖子身份与本次点击请求不一致，请导出日志。",fields); return;
        }
        Update(@"repost_detail",confirmed ? @"running" : @"pending",confirmed ? @"detail_visible" : @"detail_identity_unavailable",
            confirmed ? @"已观察到同一次点击对应的详情页面，等待返回时间线验证隐藏状态。" : @"已出现详情页面，但无法确认与本次隐藏转推对应；需人工核对。",fields);
    } else if ([event isEqual:@"repost_detail_confirmation_timeout"]) {
        NSMutableDictionary *item=Item(@"repost_detail");
        if (![item[@"pendingAttempt"] isEqual:fields[@"attempt"]] || [item[@"detailConfirmed"] boolValue]) return;
        Update(@"repost_detail",@"pending",@"confirmation_timeout",@"等待详情确认超过 15 秒，尚未取得可匹配证据；请核对实际页面并导出日志。",fields);
    } else if ([event isEqual:@"repost_detail_return"]) {
        NSMutableDictionary *item=Item(@"repost_detail");
        if ([item[@"pendingAttempt"] isKindOfClass:NSString.class] && [fields[@"attempt"] isKindOfClass:NSString.class] && ![item[@"pendingAttempt"] isEqual:fields[@"attempt"]]) return;
        BOOL matches=[item[@"pendingAttempt"] isKindOfClass:NSString.class] && [item[@"pendingAttempt"] isEqual:fields[@"attempt"]];
        if (![Number(fields[@"observable"]) boolValue] || [fields[@"result"] isEqual:@"return_row_not_observable"]) {
            Update(@"repost_detail",@"pending",@"return_row_unavailable",@"返回时目标行不可观察，尚无法核对隐藏状态；请滚回该行或人工确认。",fields); return;
        }
        if (!matches || ![item[@"detailConfirmed"] boolValue] || ![Number(fields[@"confirmed"]) boolValue]) {
            Update(@"repost_detail",@"pending",@"navigation_unconfirmed",@"返回状态已观察到，但本次详情身份未能确认，请人工核对。",fields); return;
        }
        if (!Number(fields[@"hiddenPreserved"])) {
            Update(@"repost_detail",@"pending",@"navigation_unconfirmed",@"返回状态已观察到，但隐藏状态没有确认结果，请人工核对。",fields); return;
        }
        BOOL hidden=[Number(fields[@"hiddenPreserved"]) boolValue];
        Update(@"repost_detail",hidden ? @"success" : @"failed",hidden ? @"return_hidden_preserved" : @"return_expanded",
            hidden ? @"实际返回时间线后，该转推仍保持隐藏缩略图。" : @"返回后未保持隐藏状态，请导出日志。",fields);
    } else if ([event hasPrefix:@"performance_"]) {
        NSMutableDictionary *item=Item(@"performance");
        if ([event isEqual:@"performance_started"]) { Increment(item,@"attempts"); item[@"running"]=@YES; item[@"manualConfirmed"]=@NO; item[@"warningObserved"]=@NO; }
        if ([event isEqual:@"performance_finished"]) item[@"running"]=@NO;
        if (Number(fields[@"durationSeconds"])) item[@"observedSeconds"]=fields[@"durationSeconds"];
        if (Number(fields[@"visibleSeconds"])) item[@"observedSeconds"]=fields[@"visibleSeconds"];
        if (Number(fields[@"memoryBytes"])) item[@"lastMemoryBytes"]=fields[@"memoryBytes"];
        for (NSString *key in @[@"frameIntervals",@"slowIntervalRatio",@"maxIntervalMs",@"currentFootprintMB",@"memoryMB",@"peakMemoryMB"])
            if (Number(fields[key])) item[key]=fields[key];
        if (Number(fields[@"lagMs"])) item[@"lastLagMs"]=fields[@"lagMs"];
        if (Number(fields[@"memoryWarnings"])) item[@"memoryWarnings"]=fields[@"memoryWarnings"];
        BOOL concern=[event isEqual:@"performance_memory_warning"] || [Number(fields[@"thresholdExceeded"]) boolValue] || [Number(fields[@"memoryWarnings"]) unsignedIntegerValue]>0;
        if (concern) { item[@"warningObserved"]=@YES; Update(@"performance",@"failed",@"runtime_warning",@"已观察到卡顿阈值或内存警告，请结合采样及实际体验排查。",fields); }
        else if (![item[@"manualConfirmed"] boolValue] && ![item[@"warningObserved"] boolValue]) Update(@"performance",@"running",[item[@"running"] boolValue] ? @"samples_observed" : @"sampling_finished",
            [item[@"running"] boolValue] ? @"正在收集实际使用样本；样本正常仍需你确认连续使用体验。" : @"本次采样已结束，已有样本待你确认实际连续使用体验。",fields);
    } else if ([event isEqual:@"acceptance_export"]) {
        NSString *phase=fields[@"phase"];
        if ([phase isEqual:@"generated"]) {
            Increment(Item(@"log_export"),@"attempts");
            Update(@"log_export",@"running",@"report_generated",@"已生成脱敏验收报告，等待系统分享结果。",fields);
        } else if ([phase isEqual:@"presented"]) Update(@"log_export",@"running",@"share_presented",@"系统分享面板已打开，等待操作完成。",fields);
        else if ([phase isEqual:@"completed"]) Update(@"log_export",@"success",@"share_completed",@"系统分享活动已完成；接收端是否收到仍需人工确认。",fields);
        else if ([phase isEqual:@"cancelled"]) Update(@"log_export",@"cancelled",@"share_cancelled",@"本次系统分享已取消，报告可重新导出。",fields);
        else if ([phase isEqual:@"failed"]) Update(@"log_export",@"failed",@"share_failed",@"报告生成或系统分享失败，请查看错误域和错误码。",fields);
    }
}
NSDictionary *BHRDAcceptanceBeginSession(void) {
    Sync(^{ State=NewState(@"session"); if (CurrentBoot) [State[@"launches"] addObject:CurrentBoot]; Save(); });
    return BHRDAcceptanceSnapshot();
}
NSDictionary *BHRDAcceptanceSnapshot(void) { __block NSDictionary *snapshot; Sync(^{ snapshot=Clone(State); }); return snapshot; }
NSArray<NSDictionary *> *BHRDAcceptanceItems(void) { return BHRDAcceptanceSnapshot()[@"items"]; }
NSString *BHRDAcceptanceCurrentSessionIdentifier(void) { __block NSString *identity; Sync(^{ identity=[State[@"sessionID"] copy]; }); return identity; }
void BHRDAcceptanceObserveEvent(NSString *event,NSDictionary *fields) {
    if (![event isKindOfClass:NSString.class] || !MappedItem(event)) return;
    if (![fields isKindOfClass:NSDictionary.class]) fields=@{};
    NSString *name=[event copy]; NSDictionary *input=[fields copy];
    dispatch_async(Queue(),^{ Initialize();
        id session=input[@"acceptanceSession"]; if ([session isKindOfClass:NSString.class] && ![session isEqual:State[@"sessionID"]]) return;
        AddEvent(name,input); HandleObservation(name,input); Save();
    });
}
void BHRDAcceptanceObserveLaunch(BOOL paused,BOOL hooksEnabled) { BHRDAcceptanceObserveEvent(@"acceptance_boot",@{@"paused":@(paused),@"hooksEnabled":@(hooksEnabled)}); }
void BHRDAcceptanceRecordManualResult(NSString *key,BOOL passed) {
    Sync(^{ NSMutableDictionary *item=Item(key); if (!item) return;
        item[@"manualConfirmed"]=@(passed); item[@"manualRecordedAt"]=@(NSDate.date.timeIntervalSince1970);
        // Manual assertions remain explicitly distinct from automated evidence.
        Update(key,passed ? @"success" : @"failed",passed ? @"user_confirmed" : @"user_reported_failure",
            passed ? @"你已确认实际操作和结果符合预期（人工确认）。" : @"你已报告实际结果未通过（人工记录），请导出报告和日志。",@{});
        AddEvent(passed ? @"manual_pass" : @"manual_fail",@{}); Save();
    });
}
void BHRDAcceptanceFlush(void) { Sync(^{}); }
NSURL *BHRDAcceptanceExportReport(NSError **error) {
    NSMutableDictionary *snapshot=[BHRDAcceptanceSnapshot() mutableCopy];
    snapshot[@"exportedAt"]=@(NSDate.date.timeIntervalSince1970); snapshot[@"currentBuild"]=Build();
    snapshot[@"privacy"]=@"仅固定验收阶段和数值，不含账号、帖子标识、图片链接或错误正文。";
    NSData *data=[NSJSONSerialization dataWithJSONObject:snapshot options:NSJSONWritingPrettyPrinted error:error];
    if (!data) return nil;
    NSString *folder=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"XSuixinAcceptance-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    if (![NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error]) return nil;
    NSURL *url=[NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"XSuixin-实机验收报告.json"]];
    if (![data writeToURL:url options:NSDataWritingAtomic error:error]) { [NSFileManager.defaultManager removeItemAtPath:folder error:NULL]; return nil; }
    [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:url.path error:NULL]; return url;
}
void BHRDAcceptanceRemoveExport(NSURL *url) {
    if (!url.isFileURL || ![url.lastPathComponent isEqual:@"XSuixin-实机验收报告.json"]) return;
    NSString *parent=url.path.stringByDeletingLastPathComponent;
    if (![parent.lastPathComponent hasPrefix:@"XSuixinAcceptance-"] || ![parent.stringByDeletingLastPathComponent isEqual:NSTemporaryDirectory().stringByStandardizingPath]) return;
    [NSFileManager.defaultManager removeItemAtPath:parent error:NULL];
}
#if BHRD_ACCEPTANCE_TEST
void BHRDAcceptanceTestReload(void) { Sync(^{ State=nil; CurrentBoot=nil; ProcessIdentity=NSUUID.UUID.UUIDString; Initialize(); }); }
#endif
