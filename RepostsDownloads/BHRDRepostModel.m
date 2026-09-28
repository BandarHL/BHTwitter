#import "BHRDRepostModel.h"
#import "BHRDModelAccess.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

@implementation BHRDRepostInfo
- (instancetype)init {
    if ((self = [super init])) { _author = @"转推作者"; _thumbnails = @[]; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    BHRDRepostInfo *copy=[BHRDRepostInfo new];
    copy.postIdentifier=self.postIdentifier; copy.authorIdentifier=self.authorIdentifier;
    copy.authorPriority=self.authorPriority; copy.author=self.author;
    copy.authorName=self.authorName; copy.authorHandle=self.authorHandle;
    copy.avatar=self.avatar; copy.thumbnails=self.thumbnails;
    return copy;
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
    if (Text(value)) return [Text(value) isEqual:@"0"] ? nil : Text(value);
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
        NSString *value=Text(Path(object,path));
        NSCharacterSet *directions=[NSCharacterSet characterSetWithCharactersInString:@"\u061C\u200E\u200F\u202A\u202B\u202C\u202D\u202E\u2066\u2067\u2068\u2069"];
        value=[[value componentsSeparatedByCharactersInSet:directions] componentsJoinedByString:@""];
        NSString *handle = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@ "]];
        if (handle.length && handle.length <= 15 && [handle rangeOfCharacterFromSet:invalid].location == NSNotFound) return handle;
    }
    return nil;
}
static NSURL *FirstURL(id object, NSArray<NSString *> *paths) {
    for (NSString *path in paths) { NSURL *url = BHRDSafeThumbnailURL(Path(object, path)); if (url) return url; }
    return nil;
}
// Avatar resources may be URL strings or native image-request wrappers. Never
// use a nearby UIImageView: its pixels can still belong to a reused row.
static NSURL *AvatarURL(id value, NSUInteger depth) {
    if (!value || depth > 4) return nil;
    NSURL *url=[value isKindOfClass:NSURL.class] ? value : (Text(value) ? [NSURL URLWithString:Text(value)] : nil);
    if (url) {
        NSURLComponents *parts=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        BOOL trusted=([parts.host.lowercaseString isEqual:@"pbs.twimg.com"] && [parts.path hasPrefix:@"/profile_images/"]) ||
            ([parts.host.lowercaseString isEqual:@"abs.twimg.com"] && [parts.path hasPrefix:@"/sticky/default_profile_images/"]);
        if (!trusted || parts.user || parts.password || parts.port ||
            ![@[@"http",@"https"] containsObject:parts.scheme.lowercaseString]) return nil;
        parts.scheme=@"https";
        return parts.URL;
    }
    for (NSString *key in @[@"URL",@"url",@"imageURL",@"image_url",@"URLString",@"urlString",@"request",@"imageRequest"]) {
        id child=Value(value,key);
        if (child==value) continue;
        NSURL *resolved=AvatarURL(child,depth+1); if (resolved) return resolved;
    }
    return nil;
}
static NSURL *FirstAvatar(id object, NSArray<NSString *> *paths) {
    for (NSString *path in paths) { NSURL *url=AvatarURL(Path(object,path),0); if (url) return url; }
    return nil;
}
static BOOL SameAuthor(BHRDRepostInfo *a, BHRDRepostInfo *b) {
    if (a.authorIdentifier.length && b.authorIdentifier.length) return [a.authorIdentifier isEqual:b.authorIdentifier];
    return a.authorHandle.length && b.authorHandle.length && [a.authorHandle caseInsensitiveCompare:b.authorHandle]==NSOrderedSame;
}
static void UpdateAuthor(BHRDRepostInfo *info) {
    NSString *handle = info.authorHandle.length ? [@"@" stringByAppendingString:info.authorHandle] : nil;
    info.author = info.authorName.length && handle ? [NSString stringWithFormat:@"%@ · %@", info.authorName, handle] : info.authorName.length ? info.authorName : handle ?: @"转推作者";
}
NSString *BHRDRepostAuthorKey(BHRDRepostInfo *info) {
    if (info.authorIdentifier.length) return [@"id:" stringByAppendingString:info.authorIdentifier];
    if (info.authorHandle.length) return [@"handle:" stringByAppendingString:info.authorHandle.lowercaseString];
    return nil;
}
static void MergeInfo(BHRDRepostInfo *target, BHRDRepostInfo *additional) {
    if (!additional) return;
    if (target.postIdentifier && additional.postIdentifier && ![target.postIdentifier isEqual:additional.postIdentifier]) return;
    if (!target.postIdentifier) target.postIdentifier = additional.postIdentifier;
    // Never combine one account's name with a different account's avatar.
    BOOL compatible = target.authorIdentifier.length && additional.authorIdentifier.length
        ? [target.authorIdentifier isEqual:additional.authorIdentifier]
        : (!target.authorHandle.length || !additional.authorHandle.length || [target.authorHandle caseInsensitiveCompare:additional.authorHandle] == NSOrderedSame);
    BOOL identityArrived=!BHRDRepostAuthorKey(target) && BHRDRepostAuthorKey(additional);
    BOOL replace=(!compatible && additional.authorPriority>target.authorPriority) ||
        (identityArrived && additional.authorPriority>=target.authorPriority);
    if (replace) {
        target.authorIdentifier=additional.authorIdentifier; target.authorName=additional.authorName;
        target.authorHandle=additional.authorHandle; target.avatar=additional.avatar;
        target.authorPriority=additional.authorPriority;
    } else if (compatible) {
        if (!target.authorIdentifier.length) target.authorIdentifier = additional.authorIdentifier;
        if (!target.authorName.length) target.authorName = additional.authorName;
        if (!target.authorHandle.length) target.authorHandle = additional.authorHandle;
        if (!target.avatar) target.avatar = additional.avatar;
        target.authorPriority=MAX(target.authorPriority,additional.authorPriority);
    }
    NSMutableOrderedSet *urls = [NSMutableOrderedSet orderedSetWithArray:target.thumbnails];
    [urls addObjectsFromArray:additional.thumbnails];
    target.thumbnails = [urls.array subarrayWithRange:NSMakeRange(0, MIN(4, urls.count))];
    UpdateAuthor(target);
}
static BHRDRepostInfo *CopyInfo(BHRDRepostInfo *info) {
    return info ? [info copy] : [BHRDRepostInfo new];
}
static BHRDRepostInfo *Profile(id user) {
    if (Dict(user)) user = Unwrap(user);
    BHRDRepostInfo *info = [BHRDRepostInfo new];
    info.authorIdentifier = IDValue(user, @"rest_id") ?: IDValue(user, @"id_str") ?: IDValue(user, @"userID");
    // X can split a profile between legacy, core and avatar in the same response.
    info.authorName = FirstText(user, @[@"legacy.name", @"core.name", @"name", @"displayName", @"displayFullName", @"fullName"]);
    info.authorHandle = FirstHandle(user, @[@"legacy.screen_name", @"core.screen_name", @"screen_name", @"screenName", @"username", @"displayUsername"]);
    info.avatar = FirstAvatar(user, @[@"legacy.profile_image_url_https", @"profile_image_url_https", @"avatar", @"core.profile_image_url_https", @"profileImageURL", @"profileImageUrl", @"profileImageURLString", @"avatarURL", @"avatarImageURL", @"profileImage", @"profileImageRequest", @"avatarImageRequest", @"legacy.profile_image_url", @"profile_image_url", @"core.profile_image_url"]);
    info.authorPriority=(info.authorIdentifier.length || info.authorHandle.length || info.authorName.length || info.avatar) ? 1 : 0;
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
    if (info.authorHandle.length) {
        BHRDRepostInfo *cached=[BHRDUserCache() objectForKey:[@"handle:" stringByAppendingString:info.authorHandle.lowercaseString]];
        if (SameAuthor(info,cached)) MergeInfo(info,cached);
    }
}
static BHRDRepostInfo *NativeProfile(id object, BOOL represented) {
    BHRDRepostInfo *profile=Profile(Value(object,represented ? @"representedFromUser" : @"fromUser"));
    if (!profile.authorIdentifier.length) profile.authorIdentifier=IDValue(object,represented ? @"representedFromUserID" : @"fromUserID");
    if (!profile.authorHandle.length) profile.authorHandle=FirstHandle(object,represented ? @[@"representedFromUserName"] : @[@"fromUserName"]);
    if (!profile.avatar && BHRDRepostAuthorKey(profile)) profile.avatar=FirstAvatar(object,represented
        ? @[@"representedFromUserProfileImageURL",@"representedFromUserProfileImageURLString",@"representedFromUserAvatarURL"]
        : @[@"fromUserProfileImageURL",@"fromUserProfileImageURLString",@"fromUserAvatarURL"]);
    HydrateProfile(profile);
    profile.authorPriority=(BHRDRepostAuthorKey(profile) || profile.authorName.length || profile.avatar) ? (represented ? 3 : 2) : 0;
    UpdateAuthor(profile); return profile;
}
static BHRDRepostInfo *DirectInfo(id object) {
    BHRDRepostInfo *info = [BHRDRepostInfo new]; info.postIdentifier = Identifier(object);
    BHRDRepostInfo *represented=NativeProfile(object,YES);
    BHRDRepostInfo *raw=NativeProfile(object,NO);
    BOOL repost=Flag(object,@"isRetweet") || Flag(object,@"isRepost");
    BOOL reposterOnly=!represented.authorPriority && repost && raw.authorPriority;
    if (represented.authorPriority) MergeInfo(info,represented);
    // Some statuses expose a thin represented user and a complete fromUser for
    // the SAME original. This is safe only with a matching ID or handle.
    if (represented.authorPriority && SameAuthor(represented,raw)) MergeInfo(info,raw);
    // fromUser on an outer repost belongs to the reposter. Read it only on
    // ordinary/original status objects; representedFromUser is the display author.
    if (!represented.authorPriority && !repost) MergeInfo(info,raw);
    for (NSString *path in @[@"core.user_results.result", @"user_results.result", @"user", @"authorUser", @"statusUser", @"author", @"userViewModel", @"authorViewModel", @"userInfo"]) {
        if (reposterOnly) break;
        id user = Path(object, path);
        if (!user) continue;
        BHRDRepostInfo *profile = Profile(user);
        for (NSString *key in @[@"user",@"userModel",@"profile"]) {
            BHRDRepostInfo *child=Profile(Value(user,key));
            if (!profile.authorPriority || SameAuthor(profile,child)) MergeInfo(profile,child);
        }
        if ([path isEqual:@"author"] && Text(user)) profile.authorName = Text(user);
        if (info.authorPriority>=2) {
            if (!SameAuthor(info,profile)) continue;
        }
        MergeInfo(info, profile);
    }
    if (info.authorPriority<2 && !reposterOnly) {
        if (!info.authorName.length) info.authorName = FirstText(object, @[@"authorName", @"authorDisplayName", @"userFullName", @"displayFullName"]);
        if (!info.authorHandle.length) info.authorHandle = FirstHandle(object, @[@"authorScreenName", @"userScreenName", @"screenName", @"username"]);
        if (!info.avatar) info.avatar = FirstAvatar(object, @[@"authorProfileImageURL", @"userProfileImageURL", @"authorAvatarURL", @"profileImageURL", @"profileImageURLString"]);
        if (!info.authorIdentifier.length) info.authorIdentifier = IDValue(Value(object, @"legacy"), @"user_id_str") ?: IDValue(object, @"user_id_str") ?: IDValue(object, @"authorID") ?: IDValue(object, @"userID") ?: IDText(Value(object, @"user"));
        if (info.authorName.length || BHRDRepostAuthorKey(info) || info.avatar) info.authorPriority=MAX(info.authorPriority,1);
    }
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
    else { info = DirectInfo(outer); if (info.authorPriority) info.authorPriority=4; }
    if (!info.thumbnails.count) info.thumbnails = Thumbnails(outer);
    return StoreInfo(info, Identifier(outer));
}
static void CacheUser(id user, NSString *fallbackID) {
    BHRDRepostInfo *profile = Profile(user);
    if (!profile.authorIdentifier) profile.authorIdentifier = fallbackID;
    if (profile.authorIdentifier) {
        MergeInfo(profile, [BHRDUserCache() objectForKey:profile.authorIdentifier]);
        [BHRDUserCache() setObject:profile forKey:profile.authorIdentifier];
    }
    if (profile.authorHandle.length) {
        NSString *key=[@"handle:" stringByAppendingString:profile.authorHandle.lowercaseString];
        BHRDRepostInfo *old=[BHRDUserCache() objectForKey:key];
        if (SameAuthor(profile,old)) MergeInfo(profile,old);
        [BHRDUserCache() setObject:profile forKey:key];
    }
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
static char NativeSnapshotKey;
BHRDRepostInfo *BHRDInfoForRepostModel(id model) {
    model = BHRDUnwrapModel(model);
    NSArray *outerSources = MainSources(model), *sources = outerSources;
    BOOL explicitOriginal = NO;
    NSString *reference=nil;
    for (id source in outerSources) if ((reference=OriginalReference(source))) break;
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
        NSString *rowIdentity=BHRDRepostIdentity(model);
        NSString *canonical=explicitOriginal ? nil : reference;
        if (!canonical) for (id source in sources.reverseObjectEnumerator) if ((canonical=Identifier(source))) break;
        BHRDRepostInfo *rowCache=CachedInfo(rowIdentity);
        if (!explicitOriginal && !reference && rowCache.postIdentifier.length && (!canonical || [canonical isEqual:rowIdentity])) canonical=rowCache.postIdentifier;
        info.postIdentifier=canonical;
        BOOL knownOriginal=explicitOriginal || reference.length || (rowCache.postIdentifier.length && ![rowCache.postIdentifier isEqual:rowIdentity]);
        // Live original data comes first. Cache is a supplement, not a reason to
        // ignore a corrected native identity. An outer reposter never wins.
        for (id source in sources.reverseObjectEnumerator) {
            NSString *identifier = Identifier(source);
            if (knownOriginal && !explicitOriginal && ![identifier isEqual:canonical]) continue;
            BHRDRepostInfo *direct=DirectInfo(source);
            if (explicitOriginal && direct.authorPriority) direct.authorPriority=4;
            MergeInfo(info,direct);
        }
        for (id source in outerSources) MergeInfo(info,NativeProfile(source,YES));
        MergeInfo(info,CachedInfo(canonical));
        MergeInfo(info,rowCache);
        NSDictionary *saved=objc_getAssociatedObject(model,&NativeSnapshotKey);
        if ([saved[@"row"] isEqual:rowIdentity]) MergeInfo(info,saved[@"info"]);
        if (!info.thumbnails.count) for (id source in outerSources) {
            NSArray *urls = Thumbnails(source); if (urls.count) { info.thumbnails = urls; break; }
        }
        HydrateProfile(info);
        UpdateAuthor(info);
        // Preserve recovered native fields across cell teardown, navigation and
        // rebuilt list wrappers. No UIView/UIImage is stored in this metadata.
        if (rowIdentity && model) {
            objc_setAssociatedObject(model,&NativeSnapshotKey,@{@"row":rowIdentity,@"info":[info copy]},OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (info.authorPriority || info.thumbnails.count) StoreInfo(info,rowIdentity);
        }
        return [info copy];
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
