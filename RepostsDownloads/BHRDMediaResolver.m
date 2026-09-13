#import "BHRDMediaResolver.h"
#import <objc/message.h>
#import <string.h>

id BHRDMediaObject(id source, NSString *name) {
    if (!source || source == NSNull.null) return nil;
    SEL selector = NSSelectorFromString(name);
    if (![source respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [source methodSignatureForSelector:selector];
    if (signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(source, selector);
}
static NSString *DirectIdentity(id source) {
    for (NSString *name in @[@"statusID", @"statusIDString", @"tweetID", @"restID"]) {
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
    }
    return nil;
}
NSString *BHRDMediaStatusIdentity(id source) {
    NSString *identity = DirectIdentity(source);
    if (identity) return identity;
    id model = BHRDMediaObject(source, @"viewModel");
    return DirectIdentity(model) ?: DirectIdentity(BHRDMediaObject(source, @"status")) ?: DirectIdentity(BHRDMediaObject(model, @"status"));
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
    if (Fresh(record)) return record.media.firstObject;
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
