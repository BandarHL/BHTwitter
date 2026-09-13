#import "BHRDRepostModel.h"
#import "BHRDModelAccess.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

@interface BHRDRepostInfo ()
@property(nonatomic, copy) NSString *postIdentifier;
@property(nonatomic, copy) NSString *authorIdentifier;
@end
@implementation BHRDRepostInfo
- (instancetype)init {
    if ((self = [super init])) { _author = @"转推作者"; _thumbnails = @[]; }
    return self;
}
@end
static NSCache *BHRDMetadataCache(void) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 600; });
    return cache;
}
static NSCache *BHRDUserCache(void) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 600; });
    return cache;
}
static id Obj(id object, NSString *selectorName) {
    if (!object || object == NSNull.null) return nil;
    SEL sel = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:sel]) return nil;
    NSMethodSignature *sig = [object methodSignatureForSelector:sel];
    if (sig.numberOfArguments != 2 || sig.methodReturnType[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, sel);
}
static NSDictionary *Dict(id value) { return [value isKindOfClass:NSDictionary.class] ? value : nil; }
static id Value(id object, NSString *key) {
    id value = Dict(object) ? object[key] : Obj(object, key);
    return value == NSNull.null ? nil : value;
}
static id Path(id object, NSString *path) {
    for (NSString *key in [path componentsSeparatedByString:@"."]) {
        object = Value(object, key);
        if (!object) break;
    }
    return object;
}
static NSString *Text(id value) {
    if ([value isKindOfClass:NSAttributedString.class]) value = [value string];
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return text.length ? text : nil;
}
static NSString *FirstText(id object, NSArray<NSString *> *paths) {
    for (NSString *path in paths) { NSString *text = Text(Path(object, path)); if (text) return text; }
    return nil;
}
static NSString *IDText(id value) {
    if (Text(value)) return Text(value);
    return [value isKindOfClass:NSNumber.class] && [value unsignedLongLongValue] ? [value stringValue] : nil;
}
static NSString *IDValue(id object, NSString *key) {
    NSString *text = IDText(Value(object, key));
    if (text) return text;
    SEL sel = NSSelectorFromString(key);
    if (![object respondsToSelector:sel]) return nil;
    NSMethodSignature *sig = [object methodSignatureForSelector:sel];
    if (sig.numberOfArguments == 2 && strchr("QqLl", sig.methodReturnType[0])) {
        unsigned long long value = ((unsigned long long (*)(id, SEL))objc_msgSend)(object, sel);
        if (value) return [NSString stringWithFormat:@"%llu", value];
    }
    return nil;
}
static BOOL Flag(id object, NSString *name) {
    SEL sel = NSSelectorFromString(name);
    if (![object respondsToSelector:sel]) return NO;
    NSMethodSignature *sig = [object methodSignatureForSelector:sel];
    if (sig.numberOfArguments != 2) return NO;
    if (strchr("Bc", sig.methodReturnType[0])) return ((BOOL (*)(id, SEL))objc_msgSend)(object, sel);
    return NO;
}
BOOL BHRDIsRepostModel(id model) {
    model = BHRDUnwrapModel(model);
    // Inspect structural flags, never body text, quotedStatus or a nested quoted tweet.
    return Flag(model, @"isRetweet") || Flag(model, @"isRepost") ||
           Flag(Obj(model, @"status"), @"isRetweet") || Flag(Obj(model, @"status"), @"isRepost");
}
static NSString *Identifier(id object) {
    for (NSString *name in @[@"statusID", @"tweetID", @"statusIDString", @"restID", @"rest_id", @"id_str"]) {
        NSString *identifier = IDValue(object, name); if (identifier) return identifier;
    }
    return IDValue(Value(object, @"legacy"), @"id_str");
}
static char BHRDModelIdentityKey;
NSString *BHRDRepostIdentity(id model) {
    model = BHRDUnwrapModel(model);
    if (!model) return nil;
    NSString *identifier = Identifier(model) ?: Identifier(Obj(model, @"status"));
    if (identifier) return identifier;
    @synchronized (model) {
        identifier = objc_getAssociatedObject(model, &BHRDModelIdentityKey);
        if (!identifier) {
            identifier = [@"model:" stringByAppendingString:NSUUID.UUID.UUIDString];
            objc_setAssociatedObject(model, &BHRDModelIdentityKey, identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
    }
    return identifier;
}
NSURL *BHRDSafeThumbnailURL(id value) {
    NSURL *url = [value isKindOfClass:NSURL.class] ? value : (Text(value) ? [NSURL URLWithString:Text(value)] : nil);
    if (![url.scheme.lowercaseString isEqualToString:@"https"] || ![url.host.lowercaseString isEqualToString:@"pbs.twimg.com"]) return nil;
    NSURLComponents *parts = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if ([url.path containsString:@"/media/"] || [url.path containsString:@"_thumb/"]) {
        // A legacy :thumb suffix requests a cropped square even when name=small is appended.
        NSRange suffix = [parts.path rangeOfString:@":" options:NSBackwardsSearch];
        if (suffix.location != NSNotFound &&
            [@[@"thumb", @"small", @"medium", @"large", @"orig", @"4096x4096"] containsObject:[[parts.path substringFromIndex:suffix.location + 1] lowercaseString]]) {
            parts.path = [parts.path substringToIndex:suffix.location];
        }
        NSMutableArray *query = [NSMutableArray array];
        for (NSURLQueryItem *item in parts.queryItems) if (![item.name isEqualToString:@"name"]) [query addObject:item];
        [query addObject:[NSURLQueryItem queryItemWithName:@"name" value:@"small"]];
        parts.queryItems = query;
    }
    return parts.URL;
}
static NSDictionary *Unwrap(NSDictionary *result) {
    for (NSUInteger i = 0; i < 8; i++) {
        NSDictionary *child = Dict(result[@"tweet"]) ?: Dict(result[@"result"]);
        if (!child || child == result) break;
        result = child;
    }
    return result;
}
static NSString *FirstHandle(id object, NSArray<NSString *> *paths) {
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"] invertedSet];
    for (NSString *path in paths) {
        NSString *handle = [Text(Path(object, path)) stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@ "]];
        if (handle.length && handle.length <= 15 && [handle rangeOfCharacterFromSet:invalid].location == NSNotFound) return handle;
    }
    return nil;
}
static NSURL *FirstURL(id object, NSArray<NSString *> *paths) {
    for (NSString *path in paths) { NSURL *url = BHRDSafeThumbnailURL(Path(object, path)); if (url) return url; }
    return nil;
}
static void UpdateAuthor(BHRDRepostInfo *info) {
    NSString *handle = info.authorHandle.length ? [@"@" stringByAppendingString:info.authorHandle] : nil;
    info.author = info.authorName.length && handle ? [NSString stringWithFormat:@"%@ · %@", info.authorName, handle] : info.authorName ?: handle ?: @"转推作者";
}
static void MergeInfo(BHRDRepostInfo *target, BHRDRepostInfo *additional) {
    if (!additional) return;
    if (target.postIdentifier && additional.postIdentifier && ![target.postIdentifier isEqual:additional.postIdentifier]) return;
    if (!target.postIdentifier) target.postIdentifier = additional.postIdentifier;
    // Never combine one account's name with a different account's avatar.
    BOOL compatible = target.authorIdentifier.length && additional.authorIdentifier.length
        ? [target.authorIdentifier isEqual:additional.authorIdentifier]
        : (!target.authorHandle.length || !additional.authorHandle.length || [target.authorHandle caseInsensitiveCompare:additional.authorHandle] == NSOrderedSame);
    if (compatible) {
        if (!target.authorIdentifier) target.authorIdentifier = additional.authorIdentifier;
        if (!target.authorName) target.authorName = additional.authorName;
        if (!target.authorHandle) target.authorHandle = additional.authorHandle;
        if (!target.avatar) target.avatar = additional.avatar;
    }
    NSMutableOrderedSet *urls = [NSMutableOrderedSet orderedSetWithArray:target.thumbnails];
    [urls addObjectsFromArray:additional.thumbnails];
    target.thumbnails = [urls.array subarrayWithRange:NSMakeRange(0, MIN(4, urls.count))];
    UpdateAuthor(target);
}
static BHRDRepostInfo *CopyInfo(BHRDRepostInfo *info) {
    BHRDRepostInfo *copy = [BHRDRepostInfo new]; MergeInfo(copy, info); return copy;
}
static BHRDRepostInfo *Profile(id user) {
    if (Dict(user)) user = Unwrap(user);
    BHRDRepostInfo *info = [BHRDRepostInfo new];
    info.authorIdentifier = IDValue(user, @"rest_id") ?: IDValue(user, @"id_str") ?: IDValue(user, @"userID");
    // X can split a profile between legacy, core and avatar in the same response.
    info.authorName = FirstText(user, @[@"legacy.name", @"core.name", @"name", @"displayName", @"displayFullName", @"fullName"]);
    info.authorHandle = FirstHandle(user, @[@"legacy.screen_name", @"core.screen_name", @"screen_name", @"screenName", @"username", @"displayUsername"]);
    info.avatar = FirstURL(user, @[@"legacy.profile_image_url_https", @"profile_image_url_https", @"avatar.image_url", @"core.profile_image_url_https", @"profileImageURL", @"profileImageUrl", @"profileImageURLString", @"avatarURL", @"avatarImageURL"]);
    UpdateAuthor(info);
    return info;
}
static NSArray<NSURL *> *Thumbnails(id object) {
    NSMutableOrderedSet *urls = [NSMutableOrderedSet orderedSet];
    for (NSString *path in @[@"legacy.extended_entities.media", @"extended_entities.media", @"extendedEntities.media", @"legacy.entities.media", @"entities.media", @"representedMediaEntities", @"mediaEntities"]) {
        id media = Path(object, path);
        if (![media isKindOfClass:NSArray.class]) continue;
        for (id entity in media) {
            NSURL *url = FirstURL(entity, @[@"media_url_https", @"mediaURL", @"mediaURLString", @"imageURL"]);
            if (url) [urls addObject:url];
            if (urls.count == 4) return urls.array;
        }
    }
    return urls.array;
}
static void HydrateProfile(BHRDRepostInfo *info) {
    if (info.authorIdentifier) MergeInfo(info, [BHRDUserCache() objectForKey:info.authorIdentifier]);
}
static BHRDRepostInfo *DirectInfo(id object) {
    BHRDRepostInfo *info = [BHRDRepostInfo new]; info.postIdentifier = Identifier(object);
    for (NSString *path in @[@"core.user_results.result", @"user_results.result", @"user", @"authorUser", @"statusUser", @"author", @"userViewModel", @"authorViewModel", @"userInfo"]) {
        id user = Path(object, path);
        if (!user) continue;
        BHRDRepostInfo *profile = Profile(user);
        if ([path isEqual:@"author"] && Text(user)) profile.authorName = Text(user);
        MergeInfo(info, profile);
        for (NSString *key in @[@"user", @"userModel", @"profile"]) MergeInfo(info, Profile(Value(user, key)));
    }
    if (!info.authorName) info.authorName = FirstText(object, @[@"authorName", @"authorDisplayName", @"userFullName", @"displayFullName"]);
    if (!info.authorHandle) info.authorHandle = FirstHandle(object, @[@"authorScreenName", @"userScreenName", @"screenName", @"username"]);
    if (!info.avatar) info.avatar = FirstURL(object, @[@"authorProfileImageURL", @"userProfileImageURL", @"authorAvatarURL", @"profileImageURL", @"profileImageURLString"]);
    if (!info.authorIdentifier) info.authorIdentifier = IDValue(Value(object, @"legacy"), @"user_id_str") ?: IDValue(object, @"user_id_str") ?: IDValue(object, @"authorID") ?: IDValue(object, @"userID") ?: IDText(Value(object, @"user"));
    info.thumbnails = Thumbnails(object);
    HydrateProfile(info); UpdateAuthor(info);
    return info;
}
static id Original(id object) {
    for (NSString *path in @[@"legacy.retweeted_status_result.result", @"retweeted_status_result.result", @"legacy.retweeted_status", @"retweeted_status", @"retweetedStatus", @"retweetedTweet", @"originalStatus"]) {
        id original = Path(object, path);
        if (original && original != object && ![original isKindOfClass:NSString.class] && ![original isKindOfClass:NSNumber.class]) return original;
    }
    return nil;
}
static NSString *OriginalReference(id object) {
    return IDValue(Value(object, @"legacy"), @"retweeted_status_id_str") ?: IDValue(object, @"retweeted_status_id_str") ?:
           IDValue(Value(object, @"legacy"), @"retweeted_status_id") ?: IDValue(object, @"retweeted_status_id") ?:
           IDValue(object, @"retweetedStatusID") ?: IDValue(object, @"retweetedStatusIDString");
}
static BHRDRepostInfo *CachedInfo(NSString *key) {
    if (!key) return nil;
    BHRDRepostInfo *info = [BHRDMetadataCache() objectForKey:key];
    // A later standalone original response must also update previews keyed by its repost ID.
    if (info.postIdentifier && ![info.postIdentifier isEqual:key]) return [BHRDMetadataCache() objectForKey:info.postIdentifier] ?: info;
    return info;
}
static BHRDRepostInfo *StoreInfo(BHRDRepostInfo *info, NSString *key) {
    BHRDRepostInfo *merged = CopyInfo(info);
    MergeInfo(merged, CachedInfo(key));
    MergeInfo(merged, CachedInfo(merged.postIdentifier));
    HydrateProfile(merged);
    if (key) [BHRDMetadataCache() setObject:merged forKey:key];
    if (merged.postIdentifier) [BHRDMetadataCache() setObject:merged forKey:merged.postIdentifier];
    return merged;
}
static BHRDRepostInfo *CacheTweet(NSDictionary *outer, NSUInteger depth) {
    if (depth > 8) return nil;
    outer = Unwrap(outer);
    NSDictionary *original = Dict(Original(outer));
    NSString *reference = OriginalReference(outer);
    BHRDRepostInfo *info;
    if (original) info = CopyInfo(CacheTweet(original, depth + 1));
    else if (reference) { info = CopyInfo(CachedInfo(reference)); info.postIdentifier = reference; }
    else info = DirectInfo(outer);
    if (!info.thumbnails.count) info.thumbnails = Thumbnails(outer);
    return StoreInfo(info, Identifier(outer));
}
static void CacheUser(id user, NSString *fallbackID) {
    BHRDRepostInfo *profile = Profile(user);
    if (!profile.authorIdentifier) profile.authorIdentifier = fallbackID;
    if (!profile.authorIdentifier) return;
    MergeInfo(profile, [BHRDUserCache() objectForKey:profile.authorIdentifier]);
    [BHRDUserCache() setObject:profile forKey:profile.authorIdentifier];
}
static void Collect(id object, NSUInteger depth, NSUInteger *remaining, BOOL usersOnly) {
    if (depth > 40 || *remaining == 0) return;
    (*remaining)--;
    if ([object isKindOfClass:NSArray.class]) {
        for (id item in object) Collect(item, depth + 1, remaining, usersOnly);
    } else if (Dict(object)) {
        if (usersOnly) {
            if (Path(object, @"legacy.screen_name") || Path(object, @"core.screen_name") || Value(object, @"screen_name") || [Value(object, @"__typename") isEqual:@"User"]) CacheUser(object, nil);
            id user = Path(object, @"user_results.result"); if (user) CacheUser(user, nil);
            NSDictionary *users = Dict(Path(object, @"globalObjects.users"));
            for (id key in users) CacheUser(users[key], IDText(key));
        } else {
            BOOL isTweet = Original(object) || OriginalReference(object) || Value(object, @"full_text") || Path(object, @"legacy.full_text") || Path(object, @"core.user_results") || Path(object, @"extended_entities.media") || Path(object, @"legacy.extended_entities.media");
            if (isTweet && Identifier(object)) CacheTweet(object, 0);
        }
        for (id key in object) {
            if ([key isEqual:@"quoted_status_result"] || [key isEqual:@"quoted_status"]) continue;
            if (!usersOnly && [key isEqual:@"legacy"]) continue; // Already consumed with its parent tweet and ID.
            Collect(object[key], depth + 1, remaining, usersOnly);
        }
    }
}
BOOL BHRDDataMayContainRepostMetadata(NSData *data) {
    if (!data.length) return NO;
    static NSArray<NSData *> *markers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *values = [NSMutableArray array];
        for (NSString *key in @[@"retweeted_status_result", @"retweeted_status", @"retweeted_status_id", @"retweeted_status_id_str", @"user_results", @"globalObjects", @"screen_name"]) {
            [values addObject:[[NSString stringWithFormat:@"\"%@\"", key] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        markers = [values copy];
    });
    for (NSData *marker in markers) if ([data rangeOfData:marker options:0 range:NSMakeRange(0, data.length)].location != NSNotFound) return YES;
    return NO;
}
void BHRDCacheRepostMetadata(id object) {
    @synchronized (BHRDMetadataCache()) {
        // Normalized timelines return users separately from tweets, sometimes in a later response.
        NSUInteger budget = 30000; Collect(object, 0, &budget, YES);
        budget = 30000; Collect(object, 0, &budget, NO);
    }
}
static NSArray *MainSources(id object) {
    NSMutableArray *sources = [NSMutableArray array], *pending = [NSMutableArray array];
    if (object) [pending addObject:object];
    NSMutableSet *visited = [NSMutableSet set];
    while (pending.count && visited.count < 48) {
        id source = pending.firstObject; [pending removeObjectAtIndex:0];
        NSValue *address = [NSValue valueWithNonretainedObject:source];
        if ([visited containsObject:address]) continue;
        [visited addObject:address]; [sources addObject:source];
        // These are wrappers of the same main tweet. Quoted tweets and reposter profiles are excluded.
        for (NSString *path in @[@"tweet_results.result", @"result", @"tweet", @"viewModel", @"status", @"coreStatus", @"statusModel", @"representedStatus"]) {
            id child = Path(source, path); if (child && child != source) [pending addObject:child];
        }
    }
    return sources;
}
BHRDRepostInfo *BHRDInfoForRepostModel(id model) {
    model = BHRDUnwrapModel(model);
    NSArray *outerSources = MainSources(model), *sources = outerSources;
    BOOL explicitOriginal = NO;
    NSMutableSet *visited = [NSMutableSet set];
    for (NSUInteger depth = 0; depth < 8; depth++) {
        id original = nil;
        for (id source in sources) if ((original = Original(source))) break;
        if (!original) break;
        NSValue *address = [NSValue valueWithNonretainedObject:original];
        if ([visited containsObject:address]) break;
        [visited addObject:address]; explicitOriginal = YES; sources = MainSources(original);
    }
    @synchronized (BHRDMetadataCache()) {
        BHRDRepostInfo *info = [BHRDRepostInfo new];
        BOOL cachedOriginal = NO;
        for (id source in sources.reverseObjectEnumerator) {
            NSString *identifier = Identifier(source);
            BHRDRepostInfo *cached = CachedInfo(identifier);
            if (cached.postIdentifier && ![cached.postIdentifier isEqual:identifier]) cachedOriginal = YES;
            MergeInfo(info, cached);
        }
        // The outer repost ID is an alias for the original; never hydrate it from the reposter's user.
        if (explicitOriginal) {
            if (!info.postIdentifier) for (id source in sources.reverseObjectEnumerator) if ((info.postIdentifier = Identifier(source))) break;
            for (id source in outerSources) MergeInfo(info, CachedInfo(Identifier(source)));
        }
        for (id source in sources.reverseObjectEnumerator) {
            NSString *identifier = Identifier(source);
            if (cachedOriginal && !explicitOriginal && ![identifier isEqual:info.postIdentifier]) continue;
            MergeInfo(info, DirectInfo(source));
        }
        if (!info.thumbnails.count) for (id source in outerSources) {
            NSArray *urls = Thumbnails(source); if (urls.count) { info.thumbnails = urls; break; }
        }
        HydrateProfile(info);
        return info; // Snapshot: later network cache updates cannot mutate an on-screen cell's data.
    }
}
NSArray *BHRDSectionsByRemovingReposts(NSArray *sections) {
    if (![sections isKindOfClass:NSArray.class]) return sections;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:sections.count];
    BOOL changed = NO;
    for (id section in sections) {
        if (![section isKindOfClass:NSArray.class]) { [result addObject:section]; continue; }
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:[section count]];
        for (id item in section) {
            if (BHRDIsRepostModel(item)) changed = YES;
            else [items addObject:item];
        }
        [result addObject:items.count == [section count] ? section : [items copy]];
    }
    return changed ? [result copy] : sections;
}
