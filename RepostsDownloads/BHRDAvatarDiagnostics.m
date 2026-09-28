#import "BHRDAvatarDiagnostics.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static dispatch_queue_t Queue(void) {
    static dispatch_queue_t queue; static dispatch_once_t once;
    dispatch_once(&once,^{ queue=dispatch_queue_create("com.caun.xsuixin.avatar-diagnostics",DISPATCH_QUEUE_SERIAL); });
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
void BHRDAvatarLog(NSString *event, NSDictionary *fields) {
    // Bound queued work as well as disk use. No post bodies, image bytes,
    // request headers, cookies or credentials are recorded.
    static NSUInteger pending;
    @synchronized(Queue()) { if (pending>=128) return; pending++; }
    dispatch_async(Queue(),^{ @autoreleasepool {
        @try {
            NSString *path=BHRDAvatarDiagnosticPath();
            NSFileManager *fm=NSFileManager.defaultManager;
            [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
            if ([[fm attributesOfItemAtPath:path error:NULL] fileSize]>2*1024*1024) {
                NSString *previous=[path stringByAppendingString:@".1"];
                [fm removeItemAtPath:previous error:NULL]; [fm moveItemAtPath:path toPath:previous error:NULL];
            }
            if (![fm fileExistsAtPath:path]) [fm createFileAtPath:path contents:nil attributes:@{NSFilePosixPermissions:@0600}];
            NSMutableDictionary *record=[fields mutableCopy] ?: [NSMutableDictionary dictionary];
            record[@"event"]=event; record[@"time"]=@([NSDate.date timeIntervalSince1970]);
            record[@"build"]=@"2.4.3+diag.1";
            NSData *json=[NSJSONSerialization dataWithJSONObject:record options:0 error:NULL];
            if (json && json.length<=32768) {
                NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];
                [file seekToEndOfFile]; [file writeData:json]; [file writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile];
            }
        } @catch (__unused NSException *exception) { /* Diagnostics must not interrupt X. */ }
        @synchronized(Queue()) { pending--; }
    }});
}
void BHRDAvatarDiagnosticFlush(void) { dispatch_sync(Queue(),^{}); }
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
static NSArray *Shape(id object) {
    NSMutableOrderedSet *names=[NSMutableOrderedSet orderedSet];
    if ([object isKindOfClass:NSDictionary.class]) {
        for (id key in object) if ([key isKindOfClass:NSString.class] && Relevant(key)) [names addObject:key];
    } else {
        for (Class cls=[object class]; cls && cls!=NSObject.class && cls!=UIView.class && cls!=UIImageView.class && names.count<80; cls=class_getSuperclass(cls)) {
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
void BHRDAvatarInspectModel(id model, NSString *row) {
    if (!model) return;
    // Three samples per row capture initial and later hydration without logging
    // on every layout pass. Keep at most 80 rows in a launch.
    static NSMutableDictionary *counts;
    @synchronized(Queue()) {
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
        BHRDAvatarLog(@"model_shape",@{@"row":row ?: @"",@"path":path,@"class":NSStringFromClass([source class]),@"getters":Shape(source)});
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
    if (!view) return;
    NSMutableArray *pending=[NSMutableArray arrayWithObject:view]; NSUInteger budget=120;
    while (pending.count && budget--) {
        UIView *node=pending.firstObject; [pending removeObjectAtIndex:0];
        NSString *name=NSStringFromClass(node.class);
        if ([name isEqual:@"BHRDRepostOverlay"]) continue;
        if (Relevant(name) || [node isKindOfClass:UIImageView.class]) {
            CGRect frame=node.frame;
            NSMutableDictionary *fields=[@{@"row":row ?: @"",@"class":name,@"hidden":@(node.hidden),@"alpha":@(node.alpha),@"frame":@[@(frame.origin.x),@(frame.origin.y),@(frame.size.width),@(frame.size.height)],@"hasImage":@([Read(node,@"image") isKindOfClass:UIImage.class]),@"hasLayerContents":@(node.layer.contents!=nil),@"getters":Shape(node)} mutableCopy];
            for (NSString *key in @[@"profileImageURL",@"imageURL",@"URL",@"url"]) {
                id value=Read(node,key); NSURL *url=[value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
                if (url.host.length) fields[key]=BHRDAvatarDiagnosticURL(url);
            }
            BHRDAvatarLog(@"native_image_view",fields);
        }
        if (pending.count<120) [pending addObjectsFromArray:node.subviews];
    }
}
__attribute__((constructor)) static void StartAvatarDiagnostics(void) {
    @autoreleasepool {
    BHRDAvatarLog(@"session_start",@{@"appVersion":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",@"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"pid":@(NSProcessInfo.processInfo.processIdentifier)});
    }
}
