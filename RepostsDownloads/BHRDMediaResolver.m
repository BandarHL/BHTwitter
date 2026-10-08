#import "BHRDMediaResolver.h"
#import <objc/message.h>
#import <string.h>

id BHRDMediaObject(id source, NSString *name) {
    if (!source || source == NSNull.null) return nil;
    @try {
        if ([source isKindOfClass:NSDictionary.class]) {
            id value = source[name]; return value == NSNull.null ? nil : value;
        }
        SEL selector = NSSelectorFromString(name);
        if (![source respondsToSelector:selector]) return nil;
        NSMethodSignature *signature = [source methodSignatureForSelector:selector];
        if (signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return nil;
        return ((id (*)(id, SEL))objc_msgSend)(source, selector);
    }
    @catch (__unused NSException *exception) { return nil; }
}
static NSString *DirectIdentity(id source) {
    for (NSString *name in @[@"statusID", @"statusIDString", @"tweetID", @"restID"]) {
        @try {
        if ([source isKindOfClass:NSDictionary.class]) {
            id value = BHRDMediaObject(source, name);
            if ([value isKindOfClass:NSString.class] && [value length]) return value;
            if ([value isKindOfClass:NSNumber.class] && [value unsignedLongLongValue]) return [value stringValue];
            continue;
        }
        SEL selector = NSSelectorFromString(name);
        if (![source respondsToSelector:selector]) continue;
        NSMethodSignature *signature = [source methodSignatureForSelector:selector];
        if (signature.numberOfArguments != 2) continue;
        if (signature.methodReturnType[0] == '@') {
            id value = BHRDMediaObject(source, name);
            if ([value isKindOfClass:NSString.class] && [value length]) return value;
            if ([value isKindOfClass:NSNumber.class] && [value unsignedLongLongValue]) return [value stringValue];
        } else if (strchr("qQlL", signature.methodReturnType[0])) {
            unsigned long long value = ((unsigned long long (*)(id, SEL))objc_msgSend)(source, selector);
            if (value) return [NSString stringWithFormat:@"%llu", value];
        }
        } @catch (__unused NSException *exception) { continue; }
    }
    return nil;
}
NSString *BHRDMediaStatusIdentity(id source) {
    if (!source || source == NSNull.null) return nil;
    NSMutableArray *pending = [NSMutableArray arrayWithObject:source];
    NSMutableSet *visited = [NSMutableSet set];
    for (NSUInteger index = 0; index < pending.count && visited.count < 32; index++) {
        id object = pending[index]; NSValue *address = [NSValue valueWithNonretainedObject:object];
        if ([visited containsObject:address]) continue;
        [visited addObject:address];
        NSString *identity = DirectIdentity(object); if (identity) return identity;
        for (NSString *key in @[@"viewModel", @"currentViewModel", @"mediaViewModel", @"representedStatus", @"status", @"tweet"])
            { id child = BHRDMediaObject(object, key); if (child) [pending addObject:child]; }
    }
    return nil;
}
@interface BHRDMediaRecord : NSObject
@property(nonatomic, copy) NSString *identity;
@property(nonatomic, copy) NSArray *media;
@property(nonatomic) NSTimeInterval captured;
@end
@implementation BHRDMediaRecord @end
static NSCache *ByID(void) {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 256; });
    return cache;
}
static NSCache *ByAsset(void) {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 256; });
    return cache;
}
static NSString *AssetKey(id value) {
    NSURL *url = [value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
    if (![url.scheme.lowercaseString isEqual:@"https"] || ![url.host.lowercaseString isEqual:@"video.twimg.com"]) return nil;
    NSArray *parts = url.path.pathComponents;
    if (parts.count >= 3 && [@[@"ext_tw_video", @"amplify_video"] containsObject:parts[1]]) return [NSString stringWithFormat:@"%@/%@", parts[1], parts[2]];
    if (parts.count == 3 && [parts[1] isEqual:@"tweet_video"]) return [@"tweet_video/" stringByAppendingString:[parts[2] stringByDeletingPathExtension]];
    return nil;
}
static BOOL Fresh(BHRDMediaRecord *record) { return record && NSProcessInfo.processInfo.systemUptime - record.captured < 300; }
static BOOL MediaMatchesAsset(id media, NSString *assetKey) {
    id variants = BHRDMediaObject(BHRDMediaObject(media, @"videoInfo"), @"variants");
    if (![variants isKindOfClass:NSArray.class] || ![variants count] || !assetKey.length) return NO;
    BOOL matched = NO;
    for (id variant in variants) {
        NSString *key = AssetKey(BHRDMediaObject(variant, @"url"));
        if (!key || ![key isEqualToString:assetKey]) return NO;
        matched = YES;
    }
    return matched;
}
static void Remember(id source, NSArray *media) {
    if (!source || !media.count) return;
    BHRDMediaRecord *record = [BHRDMediaRecord new];
    record.identity = BHRDMediaStatusIdentity(source);
    record.media = media;
    record.captured = NSProcessInfo.processInfo.systemUptime;
    if (record.identity) [ByID() setObject:record forKey:record.identity];
    for (id entity in media) {
        id variants = BHRDMediaObject(BHRDMediaObject(entity, @"videoInfo"), @"variants");
        if (![variants isKindOfClass:NSArray.class]) continue;
        BHRDMediaRecord *assetRecord = [BHRDMediaRecord new];
        assetRecord.media = @[entity]; assetRecord.captured = record.captured;
        for (id variant in variants) {
            NSString *key = AssetKey(BHRDMediaObject(variant, @"url"));
            if (key) [ByAsset() setObject:assetRecord forKey:key];
        }
    }
}
static NSArray *Cached(id source) {
    if (!source) return nil;
    NSString *identity = BHRDMediaStatusIdentity(source);
    if (!identity) return nil; // Player/controller objects may be reused for another video.
    BHRDMediaRecord *record = [ByID() objectForKey:identity];
    return Fresh(record) ? record.media : nil;
}
// Adapt a directly observed playing asset to the same interface as native variants.
@interface BHRDAssetVariant : NSObject
@property(nonatomic, copy) NSString *url;
@property(nonatomic, copy) NSString *contentType;
@end
@implementation BHRDAssetVariant @end
@interface BHRDAssetInfo : NSObject
@property(nonatomic, copy) NSArray *variants;
@end
@implementation BHRDAssetInfo @end
@interface BHRDAssetMedia : NSObject
@property(nonatomic, strong) BHRDAssetInfo *videoInfo;
@end
@implementation BHRDAssetMedia @end
static id AssetMedia(id source) {
    id value = BHRDMediaObject(source, @"URL");
    NSURL *url = [value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
    if (![url.scheme.lowercaseString isEqual:@"https"] || ![url.host.lowercaseString isEqual:@"video.twimg.com"]) return nil;
    NSString *assetKey = AssetKey(url);
    BHRDMediaRecord *record = assetKey ? [ByAsset() objectForKey:assetKey] : nil;
    // Native media objects can themselves be recycled. Verify their current
    // variants still belong to this exact observed asset before using qualities.
    if (Fresh(record) && MediaMatchesAsset(record.media.firstObject, assetKey)) return record.media.firstObject;
    NSString *ext = url.pathExtension.lowercaseString;
    if (![@[@"mp4", @"m3u8"] containsObject:ext]) return nil;
    BHRDAssetVariant *variant = [BHRDAssetVariant new];
    variant.url = url.absoluteString; variant.contentType = [ext isEqual:@"mp4"] ? @"video/mp4" : @"application/x-mpegURL";
    BHRDAssetMedia *media = [BHRDAssetMedia new]; media.videoInfo = [BHRDAssetInfo new]; media.videoInfo.variants = @[variant];
    return media;
}
static void Collect(id source, NSMutableArray *result, NSMutableSet *visited, BOOL useCache, BOOL assets) {
    if (!source || source == NSNull.null || visited.count >= 160) return;
    NSValue *address = [NSValue valueWithNonretainedObject:source];
    if ([visited containsObject:address]) return;
    [visited addObject:address];
    if ([source isKindOfClass:NSArray.class]) {
        for (id value in source) Collect(value, result, visited, useCache, assets);
        return;
    }
    id info = BHRDMediaObject(source, @"videoInfo");
    id variants = BHRDMediaObject(info, @"variants");
    if ([variants isKindOfClass:NSArray.class] && [variants count]) {
        if (![result containsObject:source]) [result addObject:source];
        return;
    }
    if (useCache) {
        NSArray *cached = Cached(source);
        if (cached.count) { for (id media in cached) if (![result containsObject:media]) [result addObject:media]; return; }
    }
    if (assets) {
        id media = AssetMedia(source);
        if (media) { [result addObject:media]; return; }
    }
    for (NSString *name in @[@"currentMediaEntity", @"mediaEntity", @"representedMediaEntities", @"inlineMediaInfos",
                             @"viewModel", @"mediaViewModel", @"currentViewModel", @"status", @"media", @"currentMedia",
                             @"extendedEntities", @"entities", @"playerSessionProducer", @"sessionProducible",
                             @"playerSession", @"player", @"currentItem", @"asset", @"delegate"]) {
        Collect(BHRDMediaObject(source, name), result, visited, useCache, assets);
    }
}
NSArray *BHRDResolveMedia(id source) {
    NSMutableArray *result = [NSMutableArray array];
    // Prefer all native variants (the working inline-button path) over a single
    // playing-asset URL, and live data over cached metadata.
    Collect(source, result, [NSMutableSet set], NO, NO);
    if (result.count) { Remember(source, result); return [result copy]; }
    Collect(source, result, [NSMutableSet set], YES, NO);
    if (!result.count) Collect(source, result, [NSMutableSet set], NO, YES);
    return [result copy];
}
void BHRDRememberMedia(id source) { (void)BHRDResolveMedia(source); }

#pragma mark - Current visible playback source

static NSURL *VideoResourceURL(id value) {
    NSURL *url = [value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
    if (![url.scheme.lowercaseString isEqualToString:@"https"] || ![url.host.lowercaseString isEqualToString:@"video.twimg.com"]) return nil;
    return [@[@"mp4", @"m3u8"] containsObject:url.pathExtension.lowercaseString] ? url : nil;
}
static NSString *URLFingerprint(NSArray<NSURL *> *urls) {
    NSMutableArray *resources = [NSMutableArray array];
    for (NSURL *url in urls) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        components.query = nil; components.fragment = nil;
        if (components.string) [resources addObject:components.string];
    }
    [resources sortUsingSelector:@selector(compare:)];
    NSData *bytes = [[resources componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    uint64_t hash = UINT64_C(14695981039346656037);
    const unsigned char *cursor = bytes.bytes;
    for (NSUInteger index = 0; index < bytes.length; index++) { hash ^= cursor[index]; hash *= UINT64_C(1099511628211); }
    return [NSString stringWithFormat:@"url-%016llx", (unsigned long long)hash];
}
static NSString *ResourceIdentity(NSArray<NSURL *> *urls) {
    NSString *key = nil; BOOL unkeyed = NO;
    for (NSURL *url in urls) {
        NSString *candidate = AssetKey(url);
        if (!candidate) { unkeyed = YES; continue; }
        if (key && ![key isEqualToString:candidate]) return nil;
        key = candidate;
    }
    // A mixture of identified and unrelated unkeyed URLs cannot establish one
    // native video identity. A wholly unkeyed current resource uses a digest.
    if (unkeyed && key) return nil;
    return unkeyed ? URLFingerprint(urls) : key;
}
static NSDictionary *LiveResult(id source, NSArray *media, NSString *assetIdentity, NSString *reason, NSString *stage, NSString *path) {
    NSString *statusIdentity = BHRDMediaStatusIdentity(source) ?: @"";
    return @{@"media":media ?: @[], @"identity":assetIdentity.length ? [@"asset:" stringByAppendingString:assetIdentity] : @"",
        @"statusIdentity":statusIdentity, @"assetIdentity":assetIdentity ?: @"", @"reason":reason,
        @"stage":stage, @"sourcePath":path ?: @"source", @"sourceClass":source ? NSStringFromClass([source class]) : @"nil"};
}
static NSArray<NSString *> *PlaybackKeys(void) {
    // These describe one currently bound playback session. Never inspect a
    // delegate, data source, pager items, prefetched players or neighboring posts.
    return @[@"currentPlayer", @"player", @"currentItem", @"playerItem", @"asset", @"currentAsset", @"videoAsset",
        @"currentPlayerSession", @"playerSession", @"playerSessionProducer", @"sessionProducible", @"playbackSession",
        @"playbackItem", @"playbackResource", @"mediaResource", @"resource", @"playerView", @"playerViewModel",
        @"currentViewModel", @"viewModel", @"mediaViewModel", @"currentMediaEntity", @"representedMediaEntity", @"mediaEntity", @"currentMedia"];
}
static NSArray<NSString *> *ResourceURLKeys(void) {
    return @[@"URL", @"url", @"assetURL", @"playbackURL", @"videoURL", @"resourceURL", @"contentURL", @"streamURL"];
}
static BOOL DeclaresObjectGetter(id object, NSString *key) {
    @try {
        if ([object isKindOfClass:NSDictionary.class]) return object[key] != nil;
        SEL selector = NSSelectorFromString(key);
        if (![object respondsToSelector:selector]) return NO;
        NSMethodSignature *signature = [object methodSignatureForSelector:selector];
        return signature.numberOfArguments == 2 && signature.methodReturnType[0] == '@';
    } @catch (__unused NSException *exception) { return NO; }
}
static NSDictionary *CurrentAssets(id source) {
    NSMutableArray *pending = [NSMutableArray arrayWithObject:@{@"object":source, @"path":@"source", @"depth":@0, @"binding":@0}];
    NSMutableSet *visited = [NSMutableSet set];
    NSMutableDictionary *assets = [NSMutableDictionary dictionary];
    BOOL unsupported = NO, playbackBound = NO, itemDeclared = NO, truncated = NO;
    NSUInteger index = 0;
    for (; index < pending.count && visited.count < 160; index++) {
        NSDictionary *node = pending[index]; id object = node[@"object"];
        NSUInteger binding = [node[@"binding"] unsignedIntegerValue];
        NSString *address = [NSString stringWithFormat:@"%p:%lu",(__bridge void *)object,(unsigned long)binding];
        if ([visited containsObject:address]) continue;
        [visited addObject:address];
        NSMutableArray *values = [NSMutableArray array];
        if ([object isKindOfClass:NSURL.class] || [object isKindOfClass:NSString.class]) [values addObject:@{@"value":object, @"key":@"URL"}];
        else for (NSString *key in ResourceURLKeys()) {
            id value = BHRDMediaObject(object, key);
            if ([value isKindOfClass:NSURL.class] || [value isKindOfClass:NSString.class]) [values addObject:@{@"value":value, @"key":key}];
        }
        for (NSDictionary *entry in values) {
            NSURL *url = VideoResourceURL(entry[@"value"]);
            if (!url) { unsupported = YES; continue; }
            NSString *key = ResourceIdentity(@[url]);
            // Prefer the direct current asset's exact ID, not a cached status ID.
            if (!assets[key] || [assets[key][@"binding"] unsignedIntegerValue] < binding)
                assets[key] = @{@"url":url, @"path":[node[@"path"] stringByAppendingFormat:@".%@",entry[@"key"]], @"binding":@(binding)};
        }
        NSUInteger depth = [node[@"depth"] unsignedIntegerValue];
        if ([object isKindOfClass:NSArray.class]) continue;
        for (NSString *key in PlaybackKeys()) {
            BOOL isItem = [@[@"currentItem", @"playerItem", @"playbackItem"] containsObject:key];
            if (isItem && DeclaresObjectGetter(object,key)) { playbackBound = YES; itemDeclared = YES; }
            id child = BHRDMediaObject(object, key);
            if (!child || [child isKindOfClass:NSArray.class]) continue;
            BOOL isAsset = [@[@"asset", @"currentAsset", @"videoAsset"] containsObject:key];
            if (isAsset) playbackBound = YES;
            NSUInteger childBinding = isItem ? 2 : (isAsset ? MAX(binding,1) : binding);
            if (depth >= 12) {
                NSString *childAddress = [NSString stringWithFormat:@"%p:%lu",(__bridge void *)child,(unsigned long)childBinding];
                if (![visited containsObject:childAddress]) truncated = YES;
                continue;
            }
            [pending addObject:@{@"object":child, @"path":[node[@"path"] stringByAppendingFormat:@".%@",key], @"depth":@(depth+1), @"binding":@(childBinding)}];
        }
    }
    for (; index < pending.count; index++) {
        NSDictionary *node = pending[index];
        NSString *address = [NSString stringWithFormat:@"%p:%lu",(__bridge void *)node[@"object"],(unsigned long)[node[@"binding"] unsignedIntegerValue]];
        if (![visited containsObject:address]) { truncated = YES; break; }
    }
    // If a currently bound item exists, URL fields on its parent or retained
    // post model cannot rescue an unreadable new item after a swipe.
    NSUInteger requiredBinding = itemDeclared ? 2 : (playbackBound ? 1 : 0);
    for (NSString *key in [assets.allKeys copy])
        if ([assets[key][@"binding"] unsignedIntegerValue] < requiredBinding) [assets removeObjectForKey:key];
    return @{@"assets":assets, @"unsupported":@(unsupported), @"playbackBound":@(playbackBound), @"truncated":@(truncated)};
}
static NSDictionary *NativeVideo(id object, NSString *path) {
    id info = BHRDMediaObject(object, @"videoInfo");
    id values = BHRDMediaObject(info, @"variants");
    NSMutableArray *variants = [NSMutableArray array];
    NSMutableArray *urls = [NSMutableArray array];
    NSString *resourcePath = [path stringByAppendingString:@".videoInfo.variants"];
    if ([values isKindOfClass:NSArray.class]) {
        for (id value in values) {
            NSURL *url = VideoResourceURL(BHRDMediaObject(value, @"url") ?: BHRDMediaObject(value, @"URL"));
            if (!url) continue;
            NSString *contentType = BHRDMediaObject(value, @"contentType");
            if (![contentType isKindOfClass:NSString.class]) contentType = nil;
            NSString *type = contentType.lowercaseString;
            if (type.length && ![@[@"video/mp4", @"application/x-mpegurl", @"application/vnd.apple.mpegurl"] containsObject:type]) continue;
            BHRDAssetVariant *variant = [BHRDAssetVariant new];
            variant.url = url.absoluteString;
            variant.contentType = [url.pathExtension.lowercaseString isEqualToString:@"mp4"] ? @"video/mp4" : @"application/x-mpegURL";
            [variants addObject:variant]; [urls addObject:url];
        }
    }
    if (!variants.count) {
        NSURL *url = VideoResourceURL(BHRDMediaObject(info, @"primaryUrl") ?: BHRDMediaObject(info, @"primaryURL"));
        if (url) {
            BHRDAssetVariant *variant = [BHRDAssetVariant new]; variant.url = url.absoluteString;
            variant.contentType = [url.pathExtension.lowercaseString isEqualToString:@"mp4"] ? @"video/mp4" : @"application/x-mpegURL";
            [variants addObject:variant]; [urls addObject:url];
            resourcePath = [path stringByAppendingString:@".videoInfo.primaryUrl"];
        }
    }
    if (!variants.count) return nil;
    NSString *identity = ResourceIdentity(urls);
    if (!identity) return @{@"ambiguous":@YES};
    BHRDAssetMedia *media = [BHRDAssetMedia new]; media.videoInfo = [BHRDAssetInfo new]; media.videoInfo.variants = variants;
    return @{@"media":media, @"assetIdentity":identity, @"path":resourcePath, @"count":@(variants.count)};
}
static NSDictionary *CurrentNativeMedia(id source, BOOL allowPostMedia) {
    NSMutableArray *pending = [NSMutableArray arrayWithObject:@{@"object":source, @"path":@"source", @"depth":@0}];
    NSMutableSet *visited = [NSMutableSet set];
    NSMutableDictionary *candidates = [NSMutableDictionary dictionary];
    BOOL ambiguous = NO, truncated = NO;
    NSMutableArray *keys = [PlaybackKeys() mutableCopy];
    if (allowPostMedia) [keys addObjectsFromArray:@[@"representedStatus", @"tweet", @"status", @"representedMediaEntities", @"inlineMediaInfos", @"extendedEntities", @"entities", @"media"]];
    NSUInteger index = 0;
    for (; index < pending.count && visited.count < 160; index++) {
        NSDictionary *node = pending[index]; id object = node[@"object"];
        NSValue *address = [NSValue valueWithNonretainedObject:object];
        if ([visited containsObject:address]) continue;
        [visited addObject:address];
        NSDictionary *video = NativeVideo(object, node[@"path"]);
        if ([video[@"ambiguous"] boolValue]) { ambiguous = YES; continue; }
        if (video) {
            NSString *identity = video[@"assetIdentity"];
            if (!candidates[identity] || [video[@"count"] unsignedIntegerValue] > [candidates[identity][@"count"] unsignedIntegerValue]) candidates[identity] = video;
            continue;
        }
        NSUInteger depth = [node[@"depth"] unsignedIntegerValue];
        if ([object isKindOfClass:NSArray.class]) {
            NSUInteger indexInArray = 0;
            for (id child in object) {
                if (indexInArray >= 16) { truncated = YES; break; }
                if (child && child != NSNull.null) {
                    if (depth >= 12) { if (![visited containsObject:[NSValue valueWithNonretainedObject:child]]) truncated = YES; }
                    else [pending addObject:@{@"object":child, @"path":[node[@"path"] stringByAppendingFormat:@"[%lu]",(unsigned long)indexInArray], @"depth":@(depth+1)}];
                }
                indexInArray++;
            }
        } else for (NSString *key in keys) {
            id child = BHRDMediaObject(object, key); if (!child) continue;
            if (depth >= 12) { if (![visited containsObject:[NSValue valueWithNonretainedObject:child]]) truncated = YES; continue; }
            [pending addObject:@{@"object":child, @"path":[node[@"path"] stringByAppendingFormat:@".%@",key], @"depth":@(depth+1)}];
        }
    }
    for (; index < pending.count; index++)
        if (![visited containsObject:[NSValue valueWithNonretainedObject:pending[index][@"object"]]]) { truncated = YES; break; }
    return @{@"candidates":candidates, @"ambiguous":@(ambiguous), @"truncated":@(truncated)};
}
NSDictionary *BHRDResolveLiveVideoSource(id source) {
    if (!source || source == NSNull.null) return LiveResult(nil,nil,nil,@"no_current_source",@"source_probe",nil);
    NSDictionary *assets = CurrentAssets(source); NSDictionary *resources = assets[@"assets"];
    if ([assets[@"truncated"] boolValue]) return LiveResult(source,nil,nil,@"resource_scan_budget_exceeded",@"resource_probe",nil);
    if (resources.count > 1) return LiveResult(source,nil,nil,@"ambiguous_current_assets",@"identity_validation",nil);
    if (resources.count == 1) {
        NSString *key = resources.allKeys.firstObject; NSDictionary *resource = resources[key];
        // Adapt the currently observed URL; exact asset-key qualities may be
        // recovered, but an old status cache can never override the playing URL.
        id media = AssetMedia(@{@"URL":resource[@"url"]});
        return LiveResult(source,media ? @[media] : nil,key,@"resolved_current_asset",@"live_asset",resource[@"path"]);
    }
    if ([assets[@"playbackBound"] boolValue]) {
        // A recycled player can retain the old tweet model while its new item is
        // buffering or opaque. Only its current resource can authorize fallback.
        return LiveResult(source,nil,nil,[assets[@"unsupported"] boolValue] ? @"unsupported_current_asset" : @"current_item_resource_unavailable",@"playback_resource_probe",nil);
    }
    NSDictionary *native = CurrentNativeMedia(source,NO);
    if (![native[@"candidates"] count] && ![native[@"ambiguous"] boolValue] && ![native[@"truncated"] boolValue]) native = CurrentNativeMedia(source,YES);
    if ([native[@"truncated"] boolValue]) return LiveResult(source,nil,nil,@"resource_scan_budget_exceeded",@"resource_probe",nil);
    NSDictionary *candidates = native[@"candidates"];
    if (candidates.count > 1 || [native[@"ambiguous"] boolValue]) return LiveResult(source,nil,nil,@"ambiguous_current_media",@"identity_validation",nil);
    if (candidates.count == 1) {
        NSString *key = candidates.allKeys.firstObject; NSDictionary *candidate = candidates[key];
        return LiveResult(source,@[candidate[@"media"]],key,@"resolved_current_media",@"native_variants",candidate[@"path"]);
    }
    return LiveResult(source,nil,nil,[assets[@"unsupported"] boolValue] ? @"unsupported_current_asset" : @"no_current_video_resource",@"resource_probe",nil);
}
