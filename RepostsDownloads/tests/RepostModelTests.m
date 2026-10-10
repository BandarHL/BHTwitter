#import <Foundation/Foundation.h>
#import "../BHRDRepostModel.h"
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) {
    checks++;
    if (!pass) { NSLog(@"FAIL: %@", name); exit(1); }
}
@interface MockTweet : NSObject
@property(nonatomic) BOOL isRetweet;
@property(nonatomic, copy) NSString *statusID;
@property(nonatomic, strong) id status;
@property(nonatomic, strong) id quotedStatus;
@property(nonatomic, strong) id retweetedStatus;
@property(nonatomic, strong) id user;
@property(nonatomic, strong) id author;
@property(nonatomic, strong) id authorViewModel;
@property(nonatomic, strong) id representedMediaEntities;
@end
@implementation MockTweet @end
@interface NativeProfile : NSObject
@property(nonatomic, strong) NSAttributedString *displayFullName;
@property(nonatomic, copy) NSString *fullName;
@property(nonatomic, copy) NSString *username;
@property(nonatomic, copy) NSString *displayUsername;
@property(nonatomic, copy) NSString *profileImageURLString;
@end
@implementation NativeProfile @end
@interface NumericTweet : NSObject
@property(nonatomic) BOOL isRepost;
@property(nonatomic) unsigned long long statusID;
@end
@implementation NumericTweet @end
@interface ObjectFlagTweet : NSObject
- (NSNumber *)isRetweet;
@end
@implementation ObjectFlagTweet
- (NSNumber *)isRetweet { return @NO; }
@end
static MockTweet *Tweet(BOOL repost, NSString *identifier) {
    MockTweet *tweet = [MockTweet new]; tweet.isRetweet = repost; tweet.statusID = identifier; return tweet;
}
static NSDictionary *Result(NSDictionary *tweet) { return @{@"tweet_results": @{@"result": tweet}}; }
static NSDictionary *Repost(NSString *identifier, NSDictionary *original) {
    return @{@"rest_id": identifier, @"legacy": @{@"retweeted_status_result": @{@"result": original}},
             @"user": @{@"name": @"转发者", @"screen_name": @"reposter", @"profile_image_url_https": @"https://pbs.twimg.com/profile_images/reposter.jpg"}};
}
static BOOL SameInfo(BHRDRepostInfo *a, BHRDRepostInfo *b) {
    return [a.author isEqual:b.author] && [a.thumbnails isEqual:b.thumbnails] &&
           ((!a.avatar && !b.avatar) || [a.avatar isEqual:b.avatar]);
}
int main(void) {
    @autoreleasepool {
        NSString *suite = [@"BHRDModes." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        Check(BHRDReadRepostMode(defaults) == BHRDRepostModeBar, @"Upgrade defaults to the recommended non-destructive bar mode");
        for (NSInteger mode = 0; mode < 3; mode++) {
            [defaults setInteger:mode forKey:BHRDRepostModeKey];
            Check(BHRDReadRepostMode(defaults) == mode, @"All three mode choices persist");
        }
        for (id invalid in @[@(-1), @3, @"preview"]) {
            [defaults setObject:invalid forKey:BHRDRepostModeKey];
            Check(BHRDReadRepostMode(defaults) == BHRDRepostModeBar, @"Invalid mode safely falls back to a bar");
        }
        [defaults removePersistentDomainForName:suite];
        MockTweet *original = Tweet(NO, @"101"), *repost = Tweet(YES, @"102");
        MockTweet *quote = Tweet(NO, @"103"); quote.quotedStatus = repost;
        NSArray *sections = @[@[original, repost, quote], @[@"cursor-bottom"], @[]];
        NSArray *filtered = BHRDSectionsByRemovingReposts(sections);
        Check([filtered[0] isEqual:@[original, quote]], @"Remove the model, not just its height");
        Check([sections[0] count] == 3, @"Keep input data immutable");
        Check(filtered.count == 3 && filtered[1] == sections[1], @"Preserve section boundaries and pagination cursors");
        Check(!BHRDIsRepostModel(quote), @"A quoted repost does not turn the outer tweet into a repost");
        Check(BHRDSectionsByRemovingReposts(filtered) == filtered, @"Repeated filtering is idempotent");
        NSArray *allReposts = @[@[repost, Tweet(YES, @"104")]];
        Check([BHRDSectionsByRemovingReposts(allReposts)[0] count] == 0, @"Consecutive cached reposts disappear together");
        Check(BHRDSectionsByRemovingReposts(nil) == nil, @"Missing sections are safe");
        NSArray *unknown = @[@"opaque section", @[NSNull.null, @"reposted in body text", @{@"isRetweet": @YES}]];
        Check(BHRDSectionsByRemovingReposts(unknown) == unknown, @"Do not filter body text or unknown section shapes");
        MockTweet *wrapper = Tweet(NO, nil); wrapper.status = repost;
        Check(BHRDIsRepostModel(wrapper), @"Read a direct status wrapper's structural flag");
        Check(!BHRDIsRepostModel([ObjectFlagTweet new]), @"Never invoke an object-returning selector with a BOOL signature");
        NumericTweet *numeric = [NumericTweet new]; numeric.statusID = 1234567890123456789ULL; numeric.isRepost = YES;
        Check([BHRDRepostIdentity(numeric) isEqual:@"1234567890123456789"], @"Numeric tweet IDs retain full precision");
        Check([BHRDRepostIdentity(repost) isEqual:BHRDRepostIdentity(Tweet(YES, @"102"))], @"Rebuilt models keep stable reveal identity");
        MockTweet *anonymous = Tweet(YES, nil);
        Check([BHRDRepostIdentity(anonymous) isEqual:BHRDRepostIdentity(anonymous)], @"Anonymous model identity remains stable");
        Check(![BHRDRepostIdentity(anonymous) isEqual:BHRDRepostIdentity(Tweet(YES, nil))], @"Anonymous models cannot inherit each other's reveal state");
        Check(BHRDSafeThumbnailURL(@"https://evil.example/media/x.jpg") == nil, @"Reject unrelated thumbnail hosts");
        Check(BHRDSafeThumbnailURL(@"http://pbs.twimg.com/media/x.jpg") == nil, @"Only use encrypted thumbnails");
        Check([BHRDSafeThumbnailURL(@"https://pbs.twimg.com/media/x.jpg?name=orig&format=jpg").absoluteString containsString:@"name=small"], @"Fetch small thumbnails, not full-size media");
        NSURL *uncropped = BHRDSafeThumbnailURL(@"https://pbs.twimg.com/media/x.jpg:thumb?format=jpg&name=thumb");
        Check([uncropped.path isEqual:@"/media/x.jpg"] && [uncropped.query containsString:@"name=small"] && ![uncropped.query containsString:@"name=thumb"], @"Remove legacy square-crop suffixes as well as query sizes");
        Check([BHRDSafeThumbnailURL(@"https://pbs.twimg.com/ext_tw_video_thumb/poster.jpg:thumb").path isEqual:@"/ext_tw_video_thumb/poster.jpg"], @"Video posters also request their complete frame");
        Check([BHRDSafeThumbnailURL(@"https://pbs.twimg.com/profile_images/avatar.jpg:thumb").path hasSuffix:@":thumb"], @"Do not rewrite avatar sizing while fixing media crops");
        Check(BHRDSafeThumbnailURL(NSNull.null) == nil, @"Malformed image fields are ignored");
        Check(!BHRDDataMayContainRepostMetadata(nil) && !BHRDDataMayContainRepostMetadata([@"unrelated retweeted_status prose" dataUsingEncoding:NSUTF8StringEncoding]), @"Skip empty and unrelated metadata payloads");
        for (NSString *key in @[@"retweeted_status_result", @"retweeted_status", @"retweeted_status_id", @"retweeted_status_id_str", @"user_results", @"globalObjects", @"screen_name"]) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:@{key: @{} } options:0 error:nil];
            Check(BHRDDataMayContainRepostMetadata(data), @"Standalone repost/user metadata does not require a timeline entry ID");
        }
        NSDictionary *user = @{@"legacy": @{@"name": @"原创作者", @"screen_name": @"original", @"profile_image_url_https": @"https://pbs.twimg.com/profile_images/avatar.jpg"}};
        NSDictionary *inner = @{@"rest_id": @"200", @"core": @{@"user_results": @{@"result": user}}, @"legacy": @{@"extended_entities": @{@"media": @[
            @{@"media_url_https": @"https://pbs.twimg.com/media/one.jpg"},
            @{@"media_url_https": @"https://pbs.twimg.com/media/one.jpg"},
            @{@"media_url_https": @"https://pbs.twimg.com/ext_tw_video_thumb/two.jpg"},
            @{@"media_url_https": @"https://evil.example/unrelated.jpg"}
        ]}}};
        NSDictionary *outer = @{@"rest_id": @"201", @"legacy": @{@"retweeted_status_result": @{@"result": inner}}};
        NSDictionary *response = @{@"data": @{@"entries": @[@{@"content": @{@"itemContent": @{@"tweet_results": @{@"result": outer}}}}]}};
        BHRDCacheRepostMetadata(response);
        BHRDRepostInfo *info = BHRDInfoForRepostModel(Tweet(YES, @"201"));
        Check([info.author isEqual:@"原创作者 · @original"], @"Preview shows original author, not the reposter");
        Check(info.thumbnails.count == 2, @"Preview deduplicates photos/video posters and rejects unrelated URLs");
        Check([info.avatar.host isEqual:@"pbs.twimg.com"], @"Preview includes the author's avatar");
        Check(SameInfo(BHRDInfoForRepostModel(Tweet(YES, @"200")), info), @"Resolve hosts that expose the original tweet ID");
        Check(BHRDInfoForRepostModel(Tweet(YES, @"999")).thumbnails.count == 0, @"Missing metadata cannot reuse another tweet's thumbnails");
        BHRDCacheRepostMetadata(@[NSNull.null, @1, @"invalid", @{@"tweet_results": @"invalid"}]);
        Check(SameInfo(BHRDInfoForRepostModel(Tweet(YES, @"201")), info), @"Malformed payloads do not corrupt cached previews");
        Check([response[@"data"][@"entries"] count] == 1, @"Metadata collection keeps the original timeline intact");

        NSDictionary *splitUser = @{@"rest_id": @"split-user", @"legacy": @{@"description": @"旧字段仍存在", @"profile_image_url_https": NSNull.null},
                                    @"core": @{@"name": @"新版作者", @"screen_name": @"modern_author"},
                                    @"avatar": @{@"image_url": @"https://pbs.twimg.com/profile_images/modern.png"}};
        NSDictionary *splitOriginal = @{@"rest_id": @"split-original", @"core": @{@"user_results": @{@"result": splitUser}}};
        BHRDCacheRepostMetadata(Result(@{@"tweet": Repost(@"split-repost", splitOriginal)}));
        BHRDRepostInfo *modern = BHRDInfoForRepostModel(Tweet(YES, @"split-repost"));
        Check([modern.author isEqual:@"新版作者 · @modern_author"], @"Read core identity even when a legacy profile dictionary exists");
        Check([modern.avatar.path isEqual:@"/profile_images/modern.png"], @"Null legacy avatars cannot block the modern avatar field");
        NSDictionary *mixedUser = @{@"legacy": @{@"name": @"分散字段"}, @"core": @{@"screen_name": @"mixed_author"}, @"avatar": @{@"image_url": @"https://pbs.twimg.com/profile_images/mixed.png"}};
        BHRDCacheRepostMetadata(Repost(@"mixed-repost", @{@"rest_id": @"mixed-original", @"core": @{@"user_results": @{@"result": mixedUser}}}));
        Check([BHRDInfoForRepostModel(Tweet(YES, @"mixed-repost")).author isEqual:@"分散字段 · @mixed_author"], @"Resolve every author field independently across profile containers");

        NativeProfile *native = [NativeProfile new];
        native.displayFullName = [[NSAttributedString alloc] initWithString:@"原生完整姓名"];
        native.username = @"@native_author";
        native.profileImageURLString = @"https://pbs.twimg.com/profile_images/native.png";
        MockTweet *nativeOriginal = Tweet(NO, @"native-original"); nativeOriginal.user = @42; nativeOriginal.authorViewModel = native;
        nativeOriginal.representedMediaEntities = @[@{@"mediaURL": @"https://pbs.twimg.com/media/native.jpg:thumb"}];
        MockTweet *nativeRepost = Tweet(YES, @"native-repost"); nativeRepost.retweetedStatus = nativeOriginal;
        nativeRepost.user = @{@"name": @"不应显示的转发者", @"screen_name": @"reposter"};
        MockTweet *nativeWrapper = Tweet(NO, nil); nativeWrapper.status = nativeRepost;
        BHRDRepostInfo *nativeInfo = BHRDInfoForRepostModel(nativeWrapper);
        Check([nativeInfo.author isEqual:@"原生完整姓名 · @native_author"], @"Native authorViewModel supplies attributed full name and username despite a scalar user reference");
        Check([nativeInfo.avatar.path isEqual:@"/profile_images/native.png"], @"Recover native string-valued profile image URLs");
        Check(nativeInfo.thumbnails.count == 1 && [nativeInfo.thumbnails[0].path isEqual:@"/media/native.jpg"], @"Native media also preserves the complete frame");
        NativeProfile *fullName = [NativeProfile new]; fullName.fullName = @"旧版全名"; fullName.displayUsername = @"@older_author";
        MockTweet *older = Tweet(YES, @"older-native"); older.user = fullName;
        Check([BHRDInfoForRepostModel(older).author isEqual:@"旧版全名 · @older_author"], @"Support the fullName and displayUsername fields used by older native profiles");
        MockTweet *namedAuthor = Tweet(YES, @"named-author"); namedAuthor.author = @"直接提供的作者姓名";
        Check([BHRDInfoForRepostModel(namedAuthor).author isEqual:@"直接提供的作者姓名"], @"Native string authors are display names rather than profile objects");

        BHRDCacheRepostMetadata(Repost(@"native-cached-repost", @{@"rest_id": @"native-cached-original", @"legacy": @{@"extended_entities": @{@"media": @[@{@"media_url_https": @"https://pbs.twimg.com/media/cached.jpg"}]}}}));
        MockTweet *cachedNative = Tweet(NO, @"native-cached-original"); cachedNative.authorViewModel = native;
        MockTweet *cachedNativeRepost = Tweet(YES, @"native-cached-repost"); cachedNativeRepost.retweetedStatus = cachedNative;
        BHRDRepostInfo *enriched = BHRDInfoForRepostModel(cachedNativeRepost);
        Check([enriched.author isEqual:@"原生完整姓名 · @native_author"] && enriched.avatar != nil, @"A placeholder cache hit cannot block richer native author metadata");
        Check(enriched.thumbnails.count == 1, @"Native author enrichment retains cached media");
        BHRDCacheRepostMetadata(Repost(@"split-repost", @{@"rest_id": @"split-original", @"legacy": @{@"full_text": @"精简响应"}}));
        Check(SameInfo(modern, BHRDInfoForRepostModel(Tweet(YES, @"split-repost"))), @"Later partial responses cannot erase a known name, handle or avatar");

        NSDictionary *normalized = @{@"globalObjects": @{@"tweets": @{
            @"normalized-original": @{@"id_str": @"normalized-original", @"user_id_str": @"later-user", @"full_text": @"原帖", @"extended_entities": @{@"media": @[@{@"media_url_https": @"https://pbs.twimg.com/media/normalized.jpg"}]}},
            @"normalized-repost": @{@"id_str": @"normalized-repost", @"retweeted_status_id_str": @"normalized-original", @"user_id_str": @"reposting-user", @"full_text": @"RT 原帖"}},
            @"users": @{@"reposting-user": @{@"id_str": @"reposting-user", @"name": @"转发的人", @"screen_name": @"reposting"}}}};
        BHRDCacheRepostMetadata(normalized);
        BHRDRepostInfo *beforeUser = BHRDInfoForRepostModel(Tweet(YES, @"normalized-repost"));
        Check([beforeUser.author isEqual:@"转推作者"], @"Do not substitute the reposter when a normalized original user has not arrived");
        BHRDCacheRepostMetadata(@{@"globalObjects": @{@"users": @{@"later-user": @{@"name": @"延迟返回的作者", @"screen_name": @"late_author", @"profile_image_url_https": @"https://pbs.twimg.com/profile_images/late.png"}}}});
        BHRDRepostInfo *afterUser = BHRDInfoForRepostModel(Tweet(YES, @"normalized-repost"));
        Check([afterUser.author isEqual:@"延迟返回的作者 · @late_author"] && afterUser.avatar != nil, @"Separate user responses hydrate normalized original authors using their map key");
        Check(afterUser.thumbnails.count == 1, @"Normalized repost references find the original media");
        Check([beforeUser.author isEqual:@"转推作者"], @"Metadata lookups return stable snapshots for cells to compare after hydration");

        BHRDCacheRepostMetadata(@{@"id_str": @"early-reference", @"retweeted_status_id_str": @"late-original", @"user": @{@"name": @"转发者"}});
        BHRDCacheRepostMetadata(@{@"rest_id": @"late-original", @"core": @{@"user_results": @{@"result": splitUser}}, @"legacy": @{@"full_text": @"独立返回的原帖"}});
        Check([BHRDInfoForRepostModel(Tweet(YES, @"early-reference")).author isEqual:@"新版作者 · @modern_author"], @"A later standalone original updates an earlier repost-ID reference");
        BHRDCacheRepostMetadata(@{@"id_str": @"numeric-reference", @"retweeted_status_id": @1234567890123456789ULL});
        BHRDCacheRepostMetadata(@{@"rest_id": @"1234567890123456789", @"core": @{@"user_results": @{@"result": splitUser}}});
        Check([BHRDInfoForRepostModel(Tweet(YES, @"numeric-reference")).author isEqual:@"新版作者 · @modern_author"], @"Numeric original references retain full precision and resolve the original author");
        MockTweet *reposterOnly = Tweet(YES, @"early-reference"); reposterOnly.user = @{@"name": @"错误的转发者", @"profile_image_url_https": @"https://pbs.twimg.com/profile_images/wrong.png"};
        Check([BHRDInfoForRepostModel(reposterOnly).avatar.path isEqual:@"/profile_images/modern.png"], @"Native reposter fields cannot override an original-ID cache alias");

        BHRDCacheRepostMetadata(@{@"rest_id": @"quoted-container", @"legacy": @{@"full_text": @"只是评论", @"quoted_status_result": @{@"result": Repost(@"quoted-only-repost", @{@"rest_id": @"quoted-only-original", @"user": @{@"name": @"引用作者"}})}}});
        Check([BHRDInfoForRepostModel(Tweet(YES, @"quoted-only-repost")).author isEqual:@"转推作者"], @"Quoted reposts cannot populate unrelated primary preview metadata");
        MockTweet *quoteOnly = Tweet(YES, @"native-quote-only"); quoteOnly.quotedStatus = nativeOriginal;
        Check([BHRDInfoForRepostModel(quoteOnly).author isEqual:@"转推作者"], @"Native quoted author fields do not leak into the outer preview");
        MockTweet *cyclic = Tweet(YES, @"cyclic-native"); cyclic.status = cyclic;
        Check(BHRDInfoForRepostModel(cyclic) != nil, @"Self-referential native wrapper models terminate safely"); cyclic.status = nil;
        NSLog(@"PASS: %lu repost-mode/model checks", (unsigned long)checks);
    }
    return 0;
}
