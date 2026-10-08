#import "BHRDAvatarDiagnostics.h"
#import "BHRDAcceptance.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "BHRDBuildInfo.h"

static const NSUInteger LogLimit=2*1024*1024, PendingLimit=128;
static const NSTimeInterval RetentionInterval=7*24*60*60;
static NSUInteger Pending, Dropped, WriteFailures, InspectionGeneration;
static NSTimeInterval DetailedUntil, NextRetentionCheck;
static char QueueSpecificKey;

static dispatch_queue_t Queue(void) {
    static dispatch_queue_t queue; static dispatch_once_t once;
    dispatch_once(&once,^{ queue=dispatch_queue_create("com.caun.xsuixin.avatar-diagnostics",DISPATCH_QUEUE_SERIAL); dispatch_queue_set_specific(queue,&QueueSpecificKey,&QueueSpecificKey,NULL); });
    return queue;
}
NSString *BHRDAvatarDiagnosticPath(void) {
#if BHRD_AVATAR_DIAGNOSTICS_TEST
    return [NSProcessInfo.processInfo.environment[@"BHRD_AVATAR_TEST_DIR"] stringByAppendingPathComponent:@"avatar-diag.log"];
#endif
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/XSuixinDownloads/avatar-diag.log"];
}
NSString *BHRDAvatarDiagnosticURL(NSURL *url) {
    if (![url isKindOfClass:NSURL.class]) return @"";
    NSURLComponents *parts=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    parts.user=nil; parts.password=nil; parts.query=nil; parts.fragment=nil;
    return parts.string ?: @"";
}
NSTimeInterval BHRDAvatarDetailedCollectionRemaining(void) {
    @synchronized(Queue()) { return MAX(0,DetailedUntil-NSDate.date.timeIntervalSince1970); }
}
void BHRDAvatarSetDetailedCollection(BOOL enabled) {
    @synchronized(Queue()) { DetailedUntil=enabled ? NSDate.date.timeIntervalSince1970+10*60 : 0; InspectionGeneration++; }
    BHRDAvatarLog(@"detailed_collection",@{@"enabled":@(enabled),@"durationSeconds":@(enabled ? 600 : 0)});
}
static NSDictionary *Summary(void) {
    NSFileManager *fm=NSFileManager.defaultManager;
    NSString *path=BHRDAvatarDiagnosticPath();
    NSUInteger dropped,failures,pending;
    @synchronized(Queue()) { dropped=Dropped; failures=WriteFailures; pending=Pending; }
    return @{@"build":BHRD_BUILD_VERSION,@"revision":BHRD_BUILD_REVISION,@"commit":BHRD_BUILD_COMMIT,
        @"droppedRecords":@(dropped),@"writeFailures":@(failures),@"pendingRecords":@(pending),
        @"detailedSecondsRemaining":@(ceil(BHRDAvatarDetailedCollectionRemaining())),@"retentionDays":@7,
        @"currentFile":@"avatar-diag.log",@"previousFile":@"avatar-diag.log.1",
        @"currentBytes":@([[fm attributesOfItemAtPath:path error:NULL] fileSize]),
        @"previousBytes":@([[fm attributesOfItemAtPath:[path stringByAppendingString:@".1"] error:NULL] fileSize])};
}
// Runs only on the writer queue. A file's mtime is checked first; for active
// files individual JSON records are pruned too, so frequent app use cannot keep
// old browsing identifiers forever. Malformed lines are omitted from exports.
static void PruneLogs(void) {
    NSTimeInterval cutoff=NSDate.date.timeIntervalSince1970-RetentionInterval;
    NSFileManager *fm=NSFileManager.defaultManager;
    for (NSString *suffix in @[@"",@".1"]) {
        NSString *path=[BHRDAvatarDiagnosticPath() stringByAppendingString:suffix];
        NSDictionary *attributes=[fm attributesOfItemAtPath:path error:NULL];
        if (!attributes) continue;
        if ([attributes[NSFileModificationDate] timeIntervalSince1970]<cutoff) { [fm removeItemAtPath:path error:NULL]; continue; }
        if ([attributes fileSize]>LogLimit+32768) continue;
        NSString *text=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        NSMutableArray *kept=[NSMutableArray array]; BOOL changed=NO;
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            if (!line.length) continue;
            id value=[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
            NSNumber *time=[value isKindOfClass:NSDictionary.class] ? value[@"time"] : nil;
            if ([time isKindOfClass:NSNumber.class] && time.doubleValue<cutoff) changed=YES;
            else [kept addObject:line];
        }
        if (changed) {
            NSString *newText=kept.count ? [[kept componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"] : @"";
            if ([newText writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL])
                [fm setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:path error:NULL];
        }
    }
    NextRetentionCheck=NSDate.date.timeIntervalSince1970+24*60*60;
}
static void RecordFailure(void) { @synchronized(Queue()) { WriteFailures++; } }
static void WriteRecord(NSString *event,NSDictionary *fields) {
    @try {
        if (NSDate.date.timeIntervalSince1970>=NextRetentionCheck) PruneLogs();
        NSMutableDictionary *record=[fields mutableCopy] ?: [NSMutableDictionary dictionary];
        record[@"event"]=event ?: @"unknown"; record[@"time"]=@(NSDate.date.timeIntervalSince1970);
        record[@"build"]=BHRD_BUILD_VERSION; record[@"revision"]=BHRD_BUILD_REVISION; record[@"commit"]=BHRD_BUILD_COMMIT;
        NSData *json=[NSJSONSerialization dataWithJSONObject:record options:0 error:NULL];
        if (!json || json.length>32768) { RecordFailure(); return; }
        NSString *path=BHRDAvatarDiagnosticPath(); NSFileManager *fm=NSFileManager.defaultManager;
        if (![fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL]) { RecordFailure(); return; }
        if ([[fm attributesOfItemAtPath:path error:NULL] fileSize]+json.length+1>LogLimit) {
            NSString *previous=[path stringByAppendingString:@".1"];
            [fm removeItemAtPath:previous error:NULL];
            if ([fm fileExistsAtPath:path] && ![fm moveItemAtPath:path toPath:previous error:NULL]) { RecordFailure(); return; }
        }
        if (![fm fileExistsAtPath:path] && ![fm createFileAtPath:path contents:nil attributes:@{NSFilePosixPermissions:@0600}]) { RecordFailure(); return; }
        NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];
        if (!file) { RecordFailure(); return; }
        [file seekToEndOfFile]; [file writeData:json]; [file writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile];
    } @catch (__unused NSException *exception) { RecordFailure(); }
}
static BOOL ReserveRecord(void) {
    @synchronized(Queue()) { if (Pending>=PendingLimit) { Dropped++; return NO; } Pending++; return YES; }
}
static void FinishRecord(void) { @synchronized(Queue()) { Pending--; } }
void BHRDAvatarLog(NSString *event, NSDictionary *fields) {
    // Keep critical acceptance observations even if the bounded file queue fills.
    // The acceptance sink never calls this logger, so this cannot recurse.
    BHRDAcceptanceObserveEvent(event,fields);
    if (!ReserveRecord()) return;
    // Snapshot fields before enqueuing so callers may safely reuse dictionaries.
    NSDictionary *snapshot=[fields copy]; NSString *name=[event copy];
    dispatch_async(Queue(),^{ @autoreleasepool { WriteRecord(name,snapshot); FinishRecord(); }});
}
void BHRDAvatarDiagnosticFlush(void) { if (!dispatch_get_specific(&QueueSpecificKey)) dispatch_sync(Queue(),^{}); }
void BHRDAvatarClearLogs(void (^completion)(NSError *)) {
    BHRDAvatarSetDetailedCollection(NO);
    dispatch_async(Queue(),^{
        NSError *error=nil; NSFileManager *fm=NSFileManager.defaultManager;
        for (NSString *suffix in @[@"",@".1"]) {
            NSString *path=[BHRDAvatarDiagnosticPath() stringByAppendingString:suffix];
            if ([fm fileExistsAtPath:path] && ![fm removeItemAtPath:path error:&error]) break;
        }
        if (!error) {
            @synchronized(Queue()) { Dropped=0; WriteFailures=0; }
            WriteRecord(@"logs_cleared",@{});
        }
        dispatch_async(dispatch_get_main_queue(),^{ if (completion) completion(error); });
    });
}
void BHRDAvatarReadLog(void (^completion)(NSString *)) {
    dispatch_async(Queue(),^{
        PruneLogs(); NSDictionary *summary=Summary();
        NSString *text=[NSString stringWithContentsOfFile:BHRDAvatarDiagnosticPath() encoding:NSUTF8StringEncoding error:NULL];
        NSArray *lines=[text componentsSeparatedByString:@"\n"];
        if (lines.count>300) text=[[lines subarrayWithRange:NSMakeRange(lines.count-300,300)] componentsJoinedByString:@"\n"];
        NSString *header=[NSString stringWithFormat:@"版本 %@ · 构建 %@\n提交 %@\n本次启动丢弃 %@ 条 · 写入失败 %@ 次\n详细采集剩余 %@ 秒（默认关闭）\n当前 avatar-diag.log：%@ 字节\n上一份 avatar-diag.log.1：%@ 字节\n保留最近 7 天，单文件上限 2 MB；当前日志最多显示末尾 300 行。\n日志在本机保存账号和媒体线索；导出自动移除账号、帖子标识及地址。\n\n",summary[@"build"],summary[@"revision"],summary[@"commit"],summary[@"droppedRecords"],summary[@"writeFailures"],summary[@"detailedSecondsRemaining"],summary[@"currentBytes"],summary[@"previousBytes"]];
        NSString *result=[header stringByAppendingString:text.length ? text : @"暂无日志。请返回 X 复现问题，再点击刷新。"];
        dispatch_async(dispatch_get_main_queue(),^{ if (completion) completion(result); });
    });
}
static BOOL SensitiveKey(NSString *key) {
    NSString *name=key.lowercaseString;
    return [name containsString:@"url"] || [name containsString:@"uri"] || [name containsString:@"handle"] ||
        [name containsString:@"author"] || [name containsString:@"userid"] || [name containsString:@"username"] ||
        [name containsString:@"rowid"] || [name containsString:@"postid"] || [name containsString:@"tweetid"] ||
        [name isEqual:@"row"] || [name isEqual:@"post"] || [name isEqual:@"id"] || [name isEqual:@"pid"] ||
        [name isEqual:@"request"] || [name isEqual:@"ownerid"] || [name isEqual:@"screen_name"] ||
        [name isEqual:@"screenname"] || [name isEqual:@"name"] || [name isEqual:@"displayname"] ||
        [name containsString:@"token"] || [name containsString:@"cookie"] || [name containsString:@"password"];
}
static id RedactedValue(id value) {
    if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *safe=[NSMutableDictionary dictionary];
        for (id key in value) if ([key isKindOfClass:NSString.class] && !SensitiveKey(key)) {
            id child=RedactedValue(value[key]); if (child) safe[key]=child;
        }
        return safe;
    }
    if ([value isKindOfClass:NSArray.class]) {
        NSMutableArray *safe=[NSMutableArray array]; for (id child in value) { id item=RedactedValue(child); if (item) [safe addObject:item]; } return safe;
    }
    if ([value isKindOfClass:NSString.class] && ([value containsString:@"://"] || [value hasPrefix:@"@"] || [value hasPrefix:@"/var/"] || [value hasPrefix:@"/private/"])) return @"[已脱敏]";
    return value;
}
void BHRDAvatarExportLogs(void (^completion)(NSArray<NSURL *> *,NSError *)) {
    dispatch_async(Queue(),^{
        PruneLogs(); NSFileManager *fm=NSFileManager.defaultManager;
        NSURL *directory=[[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:[@"XSuixinLogs-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
        NSError *error=nil; NSMutableArray *files=[NSMutableArray array];
        if ([fm createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) {
            for (NSString *suffix in @[@"",@".1"]) {
                NSString *source=[BHRDAvatarDiagnosticPath() stringByAppendingString:suffix];
                if (![fm fileExistsAtPath:source]) continue;
                NSString *text=[NSString stringWithContentsOfFile:source encoding:NSUTF8StringEncoding error:&error]; if (!text) break;
                NSMutableData *redacted=[NSMutableData data];
                for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
                    id value=[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
                    if (![value isKindOfClass:NSDictionary.class]) continue;
                    NSData *json=[NSJSONSerialization dataWithJSONObject:RedactedValue(value) options:0 error:NULL];
                    if (json) { [redacted appendData:json]; [redacted appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]]; }
                }
                NSURL *target=[directory URLByAppendingPathComponent:[@"avatar-diag.log" stringByAppendingString:suffix]];
                if (![redacted writeToURL:target options:NSDataWritingAtomic error:&error]) break;
                [fm setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:target.path error:NULL]; [files addObject:target];
            }
            NSMutableDictionary *summary=[Summary() mutableCopy]; summary[@"redacted"]=@YES;
            summary[@"exportedAt"]=@(NSDate.date.timeIntervalSince1970); summary[@"exportedFiles"]=[files valueForKey:@"lastPathComponent"];
            NSURL *target=[directory URLByAppendingPathComponent:@"diagnostic-summary.json"];
            NSData *json=[NSJSONSerialization dataWithJSONObject:summary options:NSJSONWritingPrettyPrinted error:&error];
            if (json && [json writeToURL:target options:NSDataWritingAtomic error:&error]) { [fm setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:target.path error:NULL]; [files addObject:target]; }
        }
        if (error) { [fm removeItemAtURL:directory error:NULL]; [files removeAllObjects]; }
        dispatch_async(dispatch_get_main_queue(),^{ if (completion) completion([files copy],error); });
    });
}
void BHRDAvatarRemoveExport(NSArray<NSURL *> *files) {
    NSURL *directory=files.firstObject.URLByDeletingLastPathComponent;
    if (![directory.lastPathComponent hasPrefix:@"XSuixinLogs-"] ||
        ![directory.URLByDeletingLastPathComponent.URLByResolvingSymlinksInPath.path isEqual:[NSURL fileURLWithPath:NSTemporaryDirectory()].URLByResolvingSymlinksInPath.path]) return;
    dispatch_async(Queue(),^{ [NSFileManager.defaultManager removeItemAtURL:directory error:NULL]; });
}
static id Read(id object, NSString *key) {
    @try {
        if ([object isKindOfClass:NSDictionary.class]) return object[key];
        SEL selector=NSSelectorFromString(key);
        if (![object respondsToSelector:selector]) return nil;
        NSMethodSignature *sig=[object methodSignatureForSelector:selector];
        if (sig.numberOfArguments!=2 || sig.methodReturnType[0]!='@') return nil;
        return ((id(*)(id,SEL))objc_msgSend)(object,selector);
    } @catch (__unused NSException *exception) { return nil; }
}
static BOOL Relevant(NSString *key) {
    NSString *lower=key.lowercaseString;
    return [lower containsString:@"avatar"] || [lower containsString:@"profile"] || [lower containsString:@"image"] || [lower containsString:@"user"];
}
static NSArray *Shape(Class cls, NSArray *keys) {
    NSMutableOrderedSet *names=[NSMutableOrderedSet orderedSet];
    if (keys) {
        for (id key in keys) if ([key isKindOfClass:NSString.class] && Relevant(key)) [names addObject:key];
    } else {
        for (; cls && cls!=NSObject.class && cls!=UIView.class && cls!=UIImageView.class && names.count<80; cls=class_getSuperclass(cls)) {
            unsigned count=0; Method *methods=class_copyMethodList(cls,&count);
            for (unsigned i=0;i<count && names.count<80;i++) {
                NSString *name=NSStringFromSelector(method_getName(methods[i]));
                // List parameterized accessors too, but never invoke them.
                if (Relevant(name)) [names addObject:name];
            }
            free(methods);
            Ivar *ivars=class_copyIvarList(cls,&count);
            for (unsigned i=0;i<count && names.count<80;i++) {
                NSString *name=@(ivar_getName(ivars[i]));
                if (Relevant(name)) [names addObject:[@"ivar:" stringByAppendingString:name]];
            }
            free(ivars);
        }
    }
    return names.count>80 ? [names.array subarrayWithRange:NSMakeRange(0,80)] : names.array;
}
static void LogShape(NSString *event,NSDictionary *fields,id object) {
    if (!ReserveRecord()) return;
    // UIKit values and model getters are captured on the caller's thread. The
    // expensive runtime method/ivar enumeration runs off the UI thread and is
    // cached per class; no live UIView is inspected on the writer queue.
    Class cls=[object class]; NSArray *keys=[object isKindOfClass:NSDictionary.class] ? [[object allKeys] copy] : nil;
    NSDictionary *snapshot=[fields copy];
    dispatch_async(Queue(),^{ @autoreleasepool {
        static NSMutableDictionary *cache;
        if (!cache) cache=[NSMutableDictionary dictionary];
        NSString *name=NSStringFromClass(cls); NSArray *getters=keys ? Shape(cls,keys) : cache[name];
        if (!getters) { getters=Shape(cls,nil); cache[name]=getters; }
        NSMutableDictionary *record=[snapshot mutableCopy]; record[@"getters"]=getters;
        WriteRecord(event,record); FinishRecord();
    }});
}
void BHRDAvatarInspectModel(id model, NSString *row) {
    if (BHRDAvatarDetailedCollectionRemaining()<=0 || !model) return;
    // Three samples per row capture initial and later hydration without logging
    // on every layout pass. Keep at most 80 rows in a launch.
    static NSMutableDictionary *counts; static NSUInteger generation;
    @synchronized(Queue()) {
        if (generation!=InspectionGeneration) { counts=nil; generation=InspectionGeneration; }
        if (!counts) counts=[NSMutableDictionary dictionary];
        if (counts.count>=80 && !counts[row ?: @""]) return;
        NSUInteger count=[counts[row ?: @""] unsignedIntegerValue]; if (count>=3) return;
        counts[row ?: @""]=@(count+1);
    }
    NSMutableArray *pending=[NSMutableArray arrayWithObject:@[model,@"model",@0]];
    NSMutableSet *seen=[NSMutableSet set];
    while (pending.count && seen.count<24) {
        NSArray *entry=pending.firstObject; [pending removeObjectAtIndex:0];
        id source=entry[0]; NSString *path=entry[1]; NSUInteger depth=[entry[2] unsignedIntegerValue];
        NSValue *address=[NSValue valueWithNonretainedObject:source]; if ([seen containsObject:address]) continue;
        [seen addObject:address];
        LogShape(@"model_shape",@{@"row":row ?: @"",@"path":path,@"class":NSStringFromClass([source class])},source);
        if (depth>=5) continue;
        for (NSString *key in @[@"item",@"tweet",@"status",@"viewModel",@"coreStatus",@"statusModel",@"representedStatus",@"retweetedStatus",@"originalStatus",@"representedFromUser",@"fromUser",@"user",@"userModel",@"userViewModel",@"authorViewModel",@"profile",@"core",@"legacy",@"avatar",@"profileImage",@"profileImageURL",@"profileImageURLString",@"profileImageMediaEntity",@"avatarImage",@"profile_image_url_https",@"profile_image_url",@"avatarURL",@"avatarImageURL",@"profileImageRequest",@"avatarImageRequest",@"representedFromUserProfileImageURL",@"fromUserProfileImageURL",@"imageRequest",@"request",@"URL",@"url",@"imageURL",@"image_url",@"mediaURL",@"media_url_https"]) {
            id value=Read(source,key);
            if ([path hasSuffix:@"representedFromUser"] && (Relevant(key) || [key isEqual:@"avatar"]))
                BHRDAvatarLog(@"avatar_field",@{@"row":row ?: @"",@"path":[path stringByAppendingFormat:@".%@",key],@"present":@(value && value!=NSNull.null),@"valueClass":value ? NSStringFromClass([value class]) : @""});
            if (!value || value==NSNull.null) continue;
            NSString *childPath=[path stringByAppendingFormat:@".%@",key];
            if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSURL.class]) {
                NSURL *url=[value isKindOfClass:NSURL.class] ? value : [NSURL URLWithString:value];
                if (url.host.length) BHRDAvatarLog(@"model_url",@{@"row":row ?: @"",@"path":childPath,@"url":BHRDAvatarDiagnosticURL(url)});
            } else if (![value isKindOfClass:NSNumber.class] && pending.count<64) [pending addObject:@[value,childPath,@(depth+1)]];
        }
    }
}
void BHRDAvatarInspectView(UIView *view, NSString *row) {
    if (BHRDAvatarDetailedCollectionRemaining()<=0 || !view) return;
    NSMutableArray *pending=[NSMutableArray arrayWithObject:view]; NSUInteger budget=120;
    while (pending.count && budget--) {
        UIView *node=pending.firstObject; [pending removeObjectAtIndex:0];
        NSString *name=NSStringFromClass(node.class);
        if ([name isEqual:@"BHRDRepostOverlay"]) continue;
        if (Relevant(name) || [node isKindOfClass:UIImageView.class]) {
            CGRect frame=node.frame;
            NSMutableDictionary *fields=[@{@"row":row ?: @"",@"class":name,@"hidden":@(node.hidden),@"alpha":@(node.alpha),@"frame":@[@(frame.origin.x),@(frame.origin.y),@(frame.size.width),@(frame.size.height)],@"hasImage":@([Read(node,@"image") isKindOfClass:UIImage.class]),@"hasLayerContents":@(node.layer.contents!=nil)} mutableCopy];
            for (NSString *key in @[@"profileImageURL",@"imageURL",@"URL",@"url"]) {
                id value=Read(node,key); NSURL *url=[value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
                if (url.host.length) fields[key]=BHRDAvatarDiagnosticURL(url);
            }
            LogShape(@"native_image_view",fields,node);
        }
        if (pending.count<120) [pending addObjectsFromArray:node.subviews];
    }
}
__attribute__((constructor)) static void StartAvatarDiagnostics(void) {
    @autoreleasepool {
    BHRDAvatarLog(@"session_start",@{@"appVersion":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",@"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"pid":@(NSProcessInfo.processInfo.processIdentifier)});
#if BHRD_AVATAR_DIAGNOSTICS_TEST
    if ([NSProcessInfo.processInfo.environment[@"BHRD_AVATAR_TEST_DETAILED"] boolValue]) BHRDAvatarSetDetailedCollection(YES);
#endif
    }
}
#if BHRD_AVATAR_DIAGNOSTICS_TEST
void BHRDAvatarDiagnosticTestSuspendWriter(BOOL suspended) { if (suspended) dispatch_suspend(Queue()); else dispatch_resume(Queue()); }
void BHRDAvatarDiagnosticTestExpireDetailedCollection(void) { @synchronized(Queue()) { DetailedUntil=NSDate.date.timeIntervalSince1970-1; } }
#endif
