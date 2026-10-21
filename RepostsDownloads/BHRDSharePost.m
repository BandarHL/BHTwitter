#import "BHRDSharePost.h"
#import "BHRDMediaResolver.h"
#import <objc/message.h>
#import <string.h>
@interface BHRDSharePost ()
@property(nonatomic) BOOL authorIsRepresented;
@end
@implementation BHRDSharePost
- (instancetype)init {
    if ((self = [super init])) { _title = @"X 推文"; _author = @""; _handle = @""; _body = @""; _translatedBody = @""; _imageData = @{}; _link = @""; _quote = @""; _images = @[]; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    BHRDSharePost *copy = [BHRDSharePost new];
    copy.identifier = self.identifier; copy.title = self.title; copy.author = self.author; copy.authorIdentifier = self.authorIdentifier; copy.handle = self.handle;
    copy.authorIsRepresented = self.authorIsRepresented;
    copy.bodyPriority = self.bodyPriority; copy.bodyTruncated = self.bodyTruncated;
    copy.body = self.body; copy.translatedBody = self.translatedBody; copy.bodyIsOriginal = self.bodyIsOriginal; copy.imageData = self.imageData; copy.link = self.link; copy.quote = self.quote; copy.avatar = self.avatar; copy.images = self.images; copy.avatarData = self.avatarData;
    copy.quotedPost = [self.quotedPost copy]; copy.quotedIdentifier = self.quotedIdentifier; copy.repostedBy = self.repostedBy;
    copy.replyToIdentifier = self.replyToIdentifier; copy.conversationIdentifier = self.conversationIdentifier; copy.replyContextPost = [self.replyContextPost copy];
    return copy;
}
@end
NSArray<NSDictionary *> *BHRDShareThemes(void) {
    // 配色与 fluxdo ShareImageTheme 一致，站点内容适配为 X。
    return @[@{@"name": @"经典", @"background": @0xF9F1E4, @"card": @0xFFFFFF, @"dark": @NO},
             @{@"name": @"纯白", @"background": @0xFFFFFF, @"card": @0xF5F5F5, @"dark": @NO},
             @{@"name": @"深色", @"background": @0x1E1E1E, @"card": @0x2D2D2D, @"dark": @YES},
             @{@"name": @"纯黑", @"background": @0x000000, @"card": @0x1A1A1A, @"dark": @YES},
             @{@"name": @"蓝调", @"background": @0xE8F4FC, @"card": @0xFFFFFF, @"dark": @NO},
             @{@"name": @"绿野", @"background": @0xE8F5E9, @"card": @0xFFFFFF, @"dark": @NO}];
}
NSArray<NSString *> *BHRDShareOptionKeys(void) { return @[@"logo", @"title", @"author", @"content", @"link", @"bilingual"]; }
NSArray<NSString *> *BHRDShareOptionTitles(void) { return @[@"站点标识", @"标题", @"作者", @"正文", @"链接", @"双语"]; }
void BHRDRestoreShareAuthorOption(NSUserDefaults *defaults) {
    NSString *migration = @"bhrd_share_author_restored_2_2_1";
    if ([defaults boolForKey:migration]) return;
    [defaults setBool:YES forKey:@"bhrd_share_author"];
    [defaults setBool:YES forKey:migration];
}
NSDictionary *BHRDShareOptions(NSUserDefaults *defaults) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *key in BHRDShareOptionKeys()) {
        id value = [defaults objectForKey:[@"bhrd_share_" stringByAppendingString:key]];
        result[key] = @(!value || [value boolValue]);
    }
    return result;
}
static id Value(id source, NSString *key) {
    if ([source isKindOfClass:NSDictionary.class]) { id value = source[key]; return value == NSNull.null ? nil : value; }
    return BHRDMediaObject(source, key);
}
static id Path(id source, NSString *path) {
    for (NSString *key in [path componentsSeparatedByString:@"."]) { source = Value(source, key); if (!source) break; }
    return source;
}
static NSString *ReadText(id value, NSUInteger depth) {
    if (depth > 5) return nil;
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSAttributedString.class]) return [value string];
    for (NSString *key in @[@"attributedString", @"attributedText", @"plainText", @"string", @"text", @"full_text"]) {
        id next = Value(value, key);
        if (next && next != value) { NSString *text = ReadText(next, depth + 1); if (text.length) return text; }
    }
    return nil;
}
NSString *BHRDShareText(id value) { return ReadText(value, 0); }
static NSString *FirstText(id source, NSArray<NSString *> *paths) {
    for (NSString *path in paths) { NSString *text = BHRDShareText(Path(source, path)); if (text.length) return text; }
    return nil;
}
static NSString *FirstHandle(id source, NSArray<NSString *> *paths) {
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"] invertedSet];
    // Native author text surrounds handles with directional controls. Keep ZWJ
    // and other characters intact so validation cannot silently change a handle.
    NSCharacterSet *directional = [NSCharacterSet characterSetWithCharactersInString:@"\u061C\u200E\u200F\u202A\u202B\u202C\u202D\u202E\u2066\u2067\u2068\u2069"];
    for (NSString *path in paths) {
        NSString *value = [[BHRDShareText(Path(source, path)) componentsSeparatedByCharactersInSet:directional] componentsJoinedByString:@""];
        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@ "]];
        if (value.length > 0 && value.length <= 15 && [value rangeOfCharacterFromSet:invalid].location == NSNotFound) return value;
    }
    return nil;
}
static NSString *IDText(id source, NSString *key) {
    id value = Value(source, key);
    if ([value isKindOfClass:NSString.class]) return [value length] && ![value isEqual:@"0"] ? value : nil;
    if ([value isKindOfClass:NSNumber.class]) return [value unsignedLongLongValue] ? [value stringValue] : nil;
    SEL selector = NSSelectorFromString(key);
    if (![source respondsToSelector:selector]) return nil;
    NSMethodSignature *sig = [source methodSignatureForSelector:selector];
    if (sig.numberOfArguments == 2 && strchr("qQlL", sig.methodReturnType[0])) {
        unsigned long long n = ((unsigned long long (*)(id, SEL))objc_msgSend)(source, selector);
        return n ? [NSString stringWithFormat:@"%llu", n] : nil;
    }
    return nil;
}
static NSString *PostID(id source) { return IDText(source, @"rest_id") ?: IDText(source, @"id_str") ?: IDText(Value(source, @"legacy"), @"id_str") ?: BHRDMediaStatusIdentity(source); }
static NSURL *ImageURL(id value) {
    NSURL *url = [value isKindOfClass:NSURL.class] ? value : (BHRDShareText(value).length ? [NSURL URLWithString:BHRDShareText(value)] : nil);
    return [url.scheme.lowercaseString isEqual:@"https"] && [url.host.lowercaseString isEqual:@"pbs.twimg.com"] ? url : nil;
}
static NSCache *Cache(void) {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 256; }); return cache;
}
static NSCache *Users(void) {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 512; }); return cache;
}
static void Author(BHRDSharePost *post, id user) {
    post.authorIdentifier = IDText(user, @"rest_id") ?: IDText(user, @"id_str") ?: IDText(user, @"userID");
    NSString *name = FirstText(user, @[@"legacy.name", @"core.name", @"name", @"displayName", @"displayFullName", @"fullName"]);
    NSString *handle = FirstHandle(user, @[@"legacy.screen_name", @"core.screen_name", @"screen_name", @"screenName", @"username", @"displayUsername"]);
    if (name.length) post.author = name;
    if (handle.length) post.handle = [handle stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@ "]];
    for (NSString *path in @[@"legacy.profile_image_url_https", @"profile_image_url_https", @"avatar.image_url", @"profileImageURL", @"profileImageUrl", @"profileImageURLString", @"avatarURL", @"avatarImageURL"]) {
        NSURL *url = ImageURL(Path(user, path)); if (url) { post.avatar = url; break; }
    }
}
static BOOL AuthorsMatch(BHRDSharePost *a, BHRDSharePost *b) {
    if (a.authorIdentifier.length && b.authorIdentifier.length) return [a.authorIdentifier isEqual:b.authorIdentifier];
    return a.handle.length && b.handle.length && [a.handle caseInsensitiveCompare:b.handle] == NSOrderedSame;
}
static BOOL HasAuthor(BHRDSharePost *post) {
    return post.authorIdentifier.length || post.author.length || post.handle.length || post.avatar || post.avatarData;
}
void BHRDMergeSharePost(BHRDSharePost *target, BHRDSharePost *additional) {
    if (!target || !additional) return;
    if (target.identifier.length && additional.identifier.length && ![target.identifier isEqual:additional.identifier]) return;
    if (!target.identifier.length) target.identifier = additional.identifier;
    BOOL incomingRepresented = additional.authorIsRepresented && !target.authorIsRepresented;
    if (incomingRepresented && target.handle.length && [target.title isEqual:[NSString stringWithFormat:@"@%@ 的推文", target.handle]]) target.title = @"X 推文";
    if (incomingRepresented && !AuthorsMatch(target, additional)) {
        // A nested timeline model can identify the displayed original after an
        // outer wrapper has exposed only the reposter. Replace the whole identity.
        target.author = @""; target.handle = @""; target.authorIdentifier = nil;
        target.avatar = nil; target.avatarData = nil;
    }
    BOOL sameAuthor = target.authorIdentifier.length && additional.authorIdentifier.length
        ? [target.authorIdentifier isEqual:additional.authorIdentifier]
        : (!target.handle.length || !additional.handle.length || [target.handle caseInsensitiveCompare:additional.handle] == NSOrderedSame);
    if (target.authorIsRepresented && !additional.authorIsRepresented) sameAuthor = AuthorsMatch(target, additional);
    if (sameAuthor) {
        if (!target.author.length || (incomingRepresented && additional.author.length)) target.author = additional.author;
        if (!target.authorIdentifier.length || (incomingRepresented && additional.authorIdentifier.length)) target.authorIdentifier = additional.authorIdentifier;
        if (!target.handle.length || (incomingRepresented && additional.handle.length)) target.handle = additional.handle;
        if (!target.avatar || (incomingRepresented && additional.avatar)) target.avatar = additional.avatar;
        if (!target.avatarData || (incomingRepresented && additional.avatarData)) target.avatarData = additional.avatarData;
        target.authorIsRepresented |= additional.authorIsRepresented;
    }
    if ((additional.bodyIsOriginal && !target.bodyIsOriginal) || (additional.bodyIsOriginal == target.bodyIsOriginal && (!target.body.length || additional.bodyPriority > target.bodyPriority || (target.bodyTruncated && !additional.bodyTruncated) || (!target.bodyIsOriginal && additional.body.length > target.body.length)))) {
        if (additional.body.length) { target.body = additional.body; target.bodyIsOriginal = additional.bodyIsOriginal; target.bodyPriority = additional.bodyPriority; target.bodyTruncated = additional.bodyTruncated; }
    }
    if (additional.translatedBody.length > target.translatedBody.length) target.translatedBody = additional.translatedBody;
    NSMutableDictionary *local = [additional.imageData mutableCopy] ?: [NSMutableDictionary dictionary];
    [local addEntriesFromDictionary:target.imageData ?: @{}]; target.imageData = local;
    if (!target.link.length) target.link = additional.link;
    if (!target.quote.length) target.quote = additional.quote;
    if (!target.quotedIdentifier.length) target.quotedIdentifier = additional.quotedIdentifier;
    if (!target.replyToIdentifier.length) target.replyToIdentifier = additional.replyToIdentifier;
    if (!target.conversationIdentifier.length) target.conversationIdentifier = additional.conversationIdentifier;
    if (additional.replyContextPost) BHRDAttachShareReplyContext(target, additional.replyContextPost);
    if (!target.repostedBy.length) target.repostedBy = additional.repostedBy;
    if (!target.quotedPost) target.quotedPost = [additional.quotedPost copy];
    else if (additional.quotedPost) BHRDMergeSharePost(target.quotedPost, additional.quotedPost);
    NSMutableOrderedSet *images = [NSMutableOrderedSet orderedSetWithArray:target.images ?: @[]];
    [images addObjectsFromArray:additional.images ?: @[]]; target.images = [images.array subarrayWithRange:NSMakeRange(0, MIN(4, images.count))];
    if ([target.title isEqual:@"X 推文"] && target.handle.length) target.title = [NSString stringWithFormat:@"@%@ 的推文", target.handle];
}
static BHRDSharePost *NativeAuthor(id source, NSString *userKey, NSString *IDKey, NSString *handleKey) {
    id user = Value(source, userKey);
    NSString *identifier = IDText(source, IDKey);
    NSString *handle = handleKey ? FirstHandle(source, @[handleKey]) : nil;
    if (!user && !identifier.length && !handle.length) return nil;
    BHRDSharePost *profile = [BHRDSharePost new];
    Author(profile, user);
    if (!profile.authorIdentifier.length) profile.authorIdentifier = identifier;
    if (!profile.handle.length) profile.handle = handle;
    return profile;
}
static BHRDSharePost *ReadPost(id source, NSUInteger depth, NSMutableSet *visited) {
    if (!source || source == NSNull.null || depth > 7 || visited.count > 64) return nil;
    NSValue *address = [NSValue valueWithNonretainedObject:source];
    if ([visited containsObject:address]) return nil;
    [visited addObject:address];
    BHRDSharePost *post = [BHRDSharePost new]; post.identifier = PostID(source);
    for (NSString *key in @[@"in_reply_to_status_id_str", @"in_reply_to_status_id", @"inReplyToStatusID", @"inReplyToStatusIDString", @"inReplyToTweetID"]) {
        NSString *value = IDText(source, key) ?: IDText(Value(source, @"legacy"), key);
        if (value.length && ![value isEqual:@"0"]) { post.replyToIdentifier = value; break; }
    }
    for (NSString *key in @[@"conversation_id_str", @"conversation_id", @"conversationID", @"conversationIDString"]) {
        NSString *value = IDText(source, key) ?: IDText(Value(source, @"legacy"), key);
        if (value.length && ![value isEqual:@"0"]) { post.conversationIdentifier = value; break; }
    }
    // Direct status fields belong to the raw author (possibly the reposter).
    // Keep even partial name/handle fallbacks inside that source's identity.
    // fromUserName is the screen name, not the user's human-readable name.
    BHRDSharePost *rawAuthor = NativeAuthor(source, @"fromUser", @"fromUserID", @"fromUserName") ?: [BHRDSharePost new];
    for (NSString *path in @[@"core.user_results.result", @"user_results.result", @"user", @"authorUser", @"statusUser", @"author", @"userViewModel", @"authorViewModel", @"userInfo"]) {
        id user = Path(source, path); if (!user) continue;
        BHRDSharePost *profile = [BHRDSharePost new];
        if ([user isKindOfClass:NSString.class]) profile.author = user; else Author(profile, user);
        BHRDMergeSharePost(rawAuthor, profile);
    }
    if (!rawAuthor.author.length) rawAuthor.author = FirstText(source, @[@"authorName", @"authorDisplayName", @"userFullName", @"displayFullName"]) ?: @"";
    if (!rawAuthor.handle.length) rawAuthor.handle = FirstHandle(source, @[@"authorScreenName", @"userScreenName", @"screenName", @"username"]) ?: @"";
    if (!rawAuthor.authorIdentifier.length) rawAuthor.authorIdentifier = IDText(Value(source, @"legacy"), @"user_id_str") ?: IDText(source, @"user_id_str") ?: IDText(source, @"authorID") ?: IDText(source, @"userID");
    if (rawAuthor.authorIdentifier.length) BHRDMergeSharePost(rawAuthor, [Users() objectForKey:rawAuthor.authorIdentifier]);
    BHRDSharePost *represented = NativeAuthor(source, @"representedFromUser", @"representedFromUserID", nil);
    if (HasAuthor(represented)) {
        represented.authorIsRepresented = YES;
        if (represented.authorIdentifier.length) BHRDMergeSharePost(represented, [Users() objectForKey:represented.authorIdentifier]);
        BHRDMergeSharePost(post, represented);
        if (AuthorsMatch(represented, rawAuthor)) BHRDMergeSharePost(post, rawAuthor);
    } else BHRDMergeSharePost(post, rawAuthor);
    for (NSString *path in @[@"note_tweet.note_tweet_results.result.text", @"noteTweet.text", @"noteTweet.content.text", @"noteTweetResult.text", @"noteTweetResult.result.text", @"noteTweetModel.text", @"noteTweetViewModel.text", @"noteTweetContent", @"note_tweet_results.result.text", @"extended_tweet.full_text", @"legacy.full_text", @"full_text", @"fullText", @"fullAttributedText"]) {
        NSString *body = BHRDShareText(Path(source, path));
        if (body.length) { post.body = body; post.bodyIsOriginal = YES; post.bodyPriority = [path.lowercaseString containsString:@"note"] ? 2 : 1; post.bodyTruncated = [Value(source, @"truncated") boolValue] || [Value(Value(source, @"legacy"), @"truncated") boolValue]; break; }
    }
    if (!post.body.length) for (NSString *path in @[@"textModel", @"attributedTextModel", @"attributedText", @"text", @"displayText"]) {
        NSString *body = BHRDShareText(Path(source, path)); if (body.length > post.body.length) post.body = body;
    }
    for (NSString *path in @[@"translatedText", @"translatedFullText", @"translation.text", @"translation.translated_text", @"translationResult.text", @"translatedTextModel", @"translationViewModel.text", @"translatedStatusText"]) {
        NSString *translated = BHRDShareText(Path(source, path));
        if (translated.length && ![translated isEqual:post.body] && translated.length > post.translatedBody.length) post.translatedBody = translated;
    }
    for (NSString *path in @[@"legacy.extended_entities.media", @"extended_entities.media", @"legacy.entities.media", @"entities.media", @"representedMediaEntities", @"extendedEntities.media"]) {
        id media = Path(source, path); if (![media isKindOfClass:NSArray.class]) continue;
        NSMutableOrderedSet *images = [NSMutableOrderedSet orderedSetWithArray:post.images];
        for (id item in media) {
            NSURL *url = ImageURL(Value(item, @"media_url_https") ?: Value(item, @"mediaURL"));
            if (url && images.count < 4) [images addObject:url];
        }
        post.images = images.array;
    }
    // 普通转推使用被转发推文的作者和正文，不拿转发人的信息覆盖原作者。
    for (NSString *path in @[@"legacy.retweeted_status_result.result", @"retweeted_status_result.result", @"retweeted_status", @"retweetedStatus", @"retweetedTweet"]) {
        id original = Path(source, path);
        BHRDSharePost *repost = original ? ReadPost(original, depth + 1, visited) : nil;
        if (repost.body.length) {
            // The explicit retweet relation may carry the original's author only
            // on its outer timeline wrapper. Fill missing fields without replacing
            // the original's own conflicting identity.
            BOOL compatible = repost.authorIdentifier.length && represented.authorIdentifier.length
                ? [repost.authorIdentifier isEqual:represented.authorIdentifier]
                : (!repost.handle.length || !represented.handle.length || [repost.handle caseInsensitiveCompare:represented.handle] == NSOrderedSame);
            if (HasAuthor(represented) && compatible) {
                BHRDSharePost *fallback = [represented copy];
                fallback.authorIsRepresented = repost.authorIsRepresented;
                BHRDMergeSharePost(repost, fallback);
                repost.authorIsRepresented = YES;
            }
            repost.repostedBy = rawAuthor.handle.length ? [@"@" stringByAppendingString:rawAuthor.handle] : rawAuthor.author;
            return repost;
        }
    }
    // 仅合并同一主推文的包装模型；引用关系在下面独立处理。
    for (NSString *name in @[@"tweet_results.result", @"result", @"tweet", @"viewModel", @"status", @"coreStatus", @"statusModel", @"representedStatus"]) {
        id child = Path(source, name);
        if (child && child != source) BHRDMergeSharePost(post, ReadPost(child, depth + 1, visited));
    }
    for (NSString *path in @[@"quoted_status_result.result", @"legacy.quoted_status_result.result", @"quoted_status", @"quotedStatus", @"quotedTweet", @"quotedStatusViewModel", @"quotedTweetViewModel", @"quotedStatusItemViewModel", @"quotedStatusItem", @"quoteTweet"]) {
        id child = Path(source, path); if (!child) continue;
        BHRDSharePost *quote = ReadPost(child, depth + 1, visited);
        if (quote && (quote.body.length || quote.identifier.length)) { post.quotedPost = quote; break; }
    }
    post.quotedIdentifier = post.quotedPost.identifier ?: IDText(Value(source, @"legacy"), @"quoted_status_id_str") ?: IDText(source, @"quoted_status_id_str");
    if (post.identifier.length) {
        BHRDSharePost *cached = [Cache() objectForKey:post.identifier];
        // 缓存别名仅由明确的转推关系建立：外层转推 ID 对应真正的原文。
        if (cached.identifier.length && ![cached.identifier isEqual:post.identifier]) return [cached copy];
        BHRDMergeSharePost(post, cached);
        post.link = [@"https://x.com/i/status/" stringByAppendingString:post.identifier];
    }
    if (post.quotedIdentifier.length) {
        BHRDSharePost *cached = [Cache() objectForKey:post.quotedIdentifier];
        if (!post.quotedPost) post.quotedPost = [cached copy]; else BHRDMergeSharePost(post.quotedPost, cached);
    }
    if (post.handle.length) post.title = [NSString stringWithFormat:@"@%@ 的推文", post.handle];
    return post;
}
static void Collect(id object, NSUInteger depth, NSUInteger *budget, BOOL usersOnly) {
    if (!*budget || depth > 35) return;
    (*budget)--;
    if ([object isKindOfClass:NSArray.class]) { for (id item in object) Collect(item, depth + 1, budget, usersOnly); return; }
    if (![object isKindOfClass:NSDictionary.class]) return;
    if (usersOnly) {
        NSString *handle = FirstText(object, @[@"legacy.screen_name", @"core.screen_name", @"screen_name"]);
        NSString *identifier = IDText(object, @"rest_id") ?: IDText(object, @"id_str");
        if (handle.length && identifier.length) { BHRDSharePost *author = [BHRDSharePost new]; Author(author, object); [Users() setObject:author forKey:identifier]; }
    } else {
        NSString *identifier = IDText(object, @"rest_id") ?: IDText(object, @"id_str") ?: IDText(Value(object, @"legacy"), @"id_str");
        BOOL hasBody = Value(object, @"full_text") || Path(object, @"legacy.full_text") || Value(object, @"note_tweet") || Value(object, @"extended_tweet");
        if (identifier.length && hasBody) {
            BHRDSharePost *post = ReadPost(object, 0, [NSMutableSet set]);
            if (post) {
                BHRDMergeSharePost(post, [Cache() objectForKey:identifier]);
                [Cache() setObject:[post copy] forKey:identifier];
                if (post.identifier.length) [Cache() setObject:[post copy] forKey:post.identifier];
            }
        }
    }
    for (id key in object) {
        if (!usersOnly && [key isEqual:@"legacy"]) {
            for (NSString *nested in @[@"retweeted_status_result", @"quoted_status_result"]) Collect(Path(object, [@"legacy." stringByAppendingString:nested]), depth + 1, budget, usersOnly);
            continue;
        }
        Collect(object[key], depth + 1, budget, usersOnly);
    }
}
void BHRDCacheSharePosts(id json, NSData *data) {
    if (!data.length) return;
    BOOL relevant = NO;
    for (NSString *marker in @[@"\"full_text\"", @"\"note_tweet\"", @"\"user_results\"", @"\"globalObjects\""]) {
        NSData *needle = [marker dataUsingEncoding:NSUTF8StringEncoding];
        if ([data rangeOfData:needle options:0 range:NSMakeRange(0, data.length)].location != NSNotFound) { relevant = YES; break; }
    }
    if (!relevant) return;
    NSUInteger budget = 25000; Collect(json, 0, &budget, YES);
    budget = 25000; Collect(json, 0, &budget, NO);
}
BHRDSharePost *BHRDSharePostFromSource(id source) {
    BHRDSharePost *post = [ReadPost(source, 0, [NSMutableSet set]) copy] ?: [BHRDSharePost new];
    BHRDSharePost *current = post;
    for (NSUInteger depth = 0; current && depth < 3; depth++, current = current.quotedPost) {
        if (current.authorIdentifier.length) BHRDMergeSharePost(current, [Users() objectForKey:current.authorIdentifier]);
        if (!current.quotedPost && current.quotedIdentifier.length) current.quotedPost = [[Cache() objectForKey:current.quotedIdentifier] copy];
    }
    if (post.replyToIdentifier.length) {
        BHRDAttachShareReplyContext(post, [Cache() objectForKey:post.replyToIdentifier]);
        if (post.conversationIdentifier.length) BHRDAttachShareReplyContext(post, [Cache() objectForKey:post.conversationIdentifier]);
    }
    return post;
}
void BHRDAttachShareReplyContext(BHRDSharePost *post, BHRDSharePost *candidate) {
    if (!post.replyToIdentifier.length || !candidate.identifier.length || [candidate.identifier isEqual:post.identifier]) return;
    BOOL root = [candidate.identifier isEqual:post.conversationIdentifier];
    if (!root && ![candidate.identifier isEqual:post.replyToIdentifier]) return;
    if (!candidate.body.length && !candidate.images.count) return;
    if (post.replyContextPost && [post.replyContextPost.identifier isEqual:candidate.identifier]) {
        BHRDMergeSharePost(post.replyContextPost, candidate); return;
    }
    if (post.replyContextPost && !root) return;
    post.replyContextPost = [candidate copy];
    // Context is a snapshot, not a recursive conversation graph.
    post.replyContextPost.replyContextPost = nil;
}
NSArray<BHRDSharePost *> *BHRDShareAllPosts(BHRDSharePost *post) {
    if (!post) return @[];
    NSMutableArray *pending = [NSMutableArray arrayWithObject:post], *result = [NSMutableArray array];
    NSHashTable *seen = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (NSUInteger i = 0; i < pending.count && i < 8; i++) {
        BHRDSharePost *current = pending[i];
        if ([seen containsObject:current]) continue;
        [seen addObject:current]; [result addObject:current];
        if (current.quotedPost) [pending addObject:current.quotedPost];
        if (current.replyContextPost) [pending addObject:current.replyContextPost];
    }
    return result;
}
NSArray<NSURL *> *BHRDShareImageURLs(BHRDSharePost *sourcePost) {
    NSMutableOrderedSet *urls = [NSMutableOrderedSet orderedSet];
    for (BHRDSharePost *post in BHRDShareAllPosts(sourcePost)) {
        [urls addObjectsFromArray:post.images ?: @[]]; if (post.avatar) [urls addObject:post.avatar];
    }
    return urls.array;
}
void BHRDApplyShareTextRows(BHRDSharePost *post, NSArray<NSDictionary *> *rows) {
    NSMutableArray<NSString *> *body = [NSMutableArray array], *translation = [NSMutableArray array];
    for (NSDictionary *row in rows) {
        NSString *text = BHRDShareText(row[@"text"]), *role = row[@"role"];
        if (!text.length) continue;
        if ([role isEqual:@"author"] && !post.author.length) post.author = text;
        else if ([role isEqual:@"handle"] && !post.handle.length) post.handle = [text stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@ "]];
        else if ([role isEqual:@"body"] || [role isEqual:@"translation"]) {
            NSMutableArray *fragmentsList = [role isEqual:@"translation"] ? translation : body;
            BOOL contained = NO;
            for (NSString *existing in fragmentsList) if ([existing containsString:text]) contained = YES;
            if (!contained) {
                NSIndexSet *fragments = [fragmentsList indexesOfObjectsPassingTest:^BOOL(NSString *old, __unused NSUInteger idx, __unused BOOL *stop) { return [text containsString:old]; }];
                [fragmentsList removeObjectsAtIndexes:fragments]; [fragmentsList addObject:text];
            }
        }
    }
    NSString *joined = [body componentsJoinedByString:@"\n\n"];
    if (!post.bodyIsOriginal && joined.length > post.body.length) post.body = joined;
    NSString *translated = [translation componentsJoinedByString:@"\n\n"];
    if (translated.length && ![translated isEqual:post.body] && translated.length > post.translatedBody.length) post.translatedBody = translated;
    if ([post.title isEqual:@"X 推文"] && post.handle.length) post.title = [NSString stringWithFormat:@"@%@ 的推文", post.handle];
}

NSDictionary<NSString *, NSData *> *BHRDShareEmbeddedImages(BHRDSharePost *sourcePost) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (BHRDSharePost *post in BHRDShareAllPosts(sourcePost)) {
        [result addEntriesFromDictionary:post.imageData ?: @{}];
        if (post.avatar.absoluteString.length && post.avatarData.length) result[post.avatar.absoluteString] = post.avatarData;
    }
    return result;
}
BOOL BHRDShareHasDistinctTranslation(BHRDSharePost *post) {
    NSString *original = [post.body stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *translated = [post.translatedBody stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return translated.length && ![original isEqual:translated];
}

NSArray<NSURL *> *BHRDShareVisibleImageURLs(BHRDSharePost *post, NSDictionary *options) {
    NSMutableOrderedSet *urls = [NSMutableOrderedSet orderedSet];
    NSMutableArray *posts = [NSMutableArray arrayWithObject:post];
    if ([options[@"content"] boolValue]) {
        if (post.replyContextPost) [posts addObject:post.replyContextPost];
        BHRDSharePost *quoted=post.quotedPost;
        for (NSUInteger depth=0; quoted && depth<2; depth++,quoted=quoted.quotedPost) [posts addObject:quoted];
        if (post.replyContextPost.quotedPost) [posts addObject:post.replyContextPost.quotedPost];
    }
    for (BHRDSharePost *current in posts) {
        if ([options[@"content"] boolValue]) [urls addObjectsFromArray:current.images ?: @[]];
        if ([options[@"author"] boolValue] && current.avatar) [urls addObject:current.avatar];
    }
    return urls.array;
}
