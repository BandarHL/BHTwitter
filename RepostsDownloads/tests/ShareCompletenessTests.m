#import <Foundation/Foundation.h>
#import "../BHRDSharePost.h"
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) { checks++; if (!pass) { NSLog(@"FAIL: %@", name); exit(1); } }
@interface TextModel : NSObject
@property(nonatomic, strong) NSAttributedString *attributedString;
@end
@implementation TextModel @end
@interface NativeAuthor : NSObject
@property(nonatomic) unsigned long long userID;
@property(nonatomic, copy) NSString *displayFullName;
@property(nonatomic, copy) NSString *fullName;
@property(nonatomic, copy) NSString *screenName;
@property(nonatomic, copy) NSString *username;
@property(nonatomic, copy) NSString *displayUsername;
@property(nonatomic, strong) NSURL *profileImageURL;
@end
@implementation NativeAuthor @end
@interface NativePost : NSObject
@property(nonatomic, copy) NSString *statusID;
@property(nonatomic) unsigned long long inReplyToStatusID;
@property(nonatomic, strong) id user;
@property(nonatomic, strong) id fromUser;
@property(nonatomic, copy) NSString *fromUserName;
@property(nonatomic) unsigned long long fromUserID;
@property(nonatomic, strong) id representedFromUser;
@property(nonatomic) unsigned long long representedFromUserID;
@property(nonatomic, strong) id authorViewModel;
@property(nonatomic, copy) NSString *authorName;
@property(nonatomic, copy) NSString *translatedText;
@property(nonatomic, copy) NSString *authorScreenName;
@property(nonatomic, strong) TextModel *textModel;
@property(nonatomic, strong) id noteTweet;
@property(nonatomic, strong) NativePost *quotedStatusViewModel;
@property(nonatomic, strong) NativePost *retweetedStatus;
@property(nonatomic, strong) NativePost *tweet;
@property(nonatomic, strong) NativePost *viewModel;
@end
@implementation NativePost @end
static NativePost *Post(NSString *identifier, NSString *body, NSString *author, NSString *handle) {
    NativePost *post = [NativePost new]; post.statusID = identifier;
    post.textModel = [TextModel new]; post.textModel.attributedString = [[NSAttributedString alloc] initWithString:body];
    post.authorName = author; post.authorScreenName = handle; return post;
}
static void CacheJSON(id json) { BHRDCacheSharePosts(json, [NSJSONSerialization dataWithJSONObject:json options:0 error:nil]); }
int main(void) {
    @autoreleasepool {
        // Native X uses fromUser/fromUserName on a status and representedFromUser
        // on a timeline item. No network post cache or visible UILabel is required.
        NativeAuthor *nativeUser = [NativeAuthor new];
        nativeUser.userID = 1760600000000000123ULL; nativeUser.fullName = @"贝塔酱"; nativeUser.username = @"Walden779";
        nativeUser.profileImageURL = [NSURL URLWithString:@"https://pbs.twimg.com/profile_images/native-author.png"];
        NativePost *nativeStatus = Post(@"native-status", @"来自原生状态模型的正文", nil, nil);
        nativeStatus.fromUser = nativeUser; nativeStatus.fromUserID = nativeUser.userID;
        BHRDSharePost *native = BHRDSharePostFromSource(nativeStatus);
        Check([native.author isEqual:@"贝塔酱"] && [native.handle isEqual:@"Walden779"], @"Cold native status reads fullName and username through fromUser");
        Check([native.authorIdentifier isEqual:@"1760600000000000123"] && [native.avatar isEqual:nativeUser.profileImageURL] && [native.body isEqual:nativeStatus.textModel.attributedString.string], @"Native author preserves its 64-bit ID, avatar and existing body");
        NativePost *handleOnly = Post(@"native-handle-only", @"只有原生用户名", nil, nil);
        handleOnly.fromUserName = @"@handle_only";
        native = BHRDSharePostFromSource(handleOnly);
        Check([native.handle isEqual:@"handle_only"] && !native.author.length, @"fromUserName is a handle and never fabricated as the display name");
        handleOnly.authorName = @"独立中文昵称";
        native = BHRDSharePostFromSource(handleOnly);
        Check([native.author isEqual:@"独立中文昵称"] && [native.handle isEqual:@"handle_only"], @"A native handle retains a separately supplied display name");
        handleOnly.authorName = nil; handleOnly.fromUserName = @"\u2066\u202A@narutomohamed93\u202C\u2069";
        native = BHRDSharePostFromSource(handleOnly);
        Check([native.handle isEqual:@"narutomohamed93"] && !native.author.length, @"Native handles accept the BIDI wrappers observed in the device author label");
        handleOnly.fromUserName = @"\u061C\u200E\u200F\u202A\u202B\u202C\u202D\u202E\u2066\u2067\u2068\u2069@valid_name";
        Check([BHRDSharePostFromSource(handleOnly).handle isEqual:@"valid_name"], @"Only the known directional controls are removed before handle validation");
        handleOnly.authorName = nil; handleOnly.fromUserName = @"这不是英文用户名";
        native = BHRDSharePostFromSource(handleOnly);
        Check(!native.handle.length && !native.author.length, @"Invalid native handles are not reinterpreted as names");
        handleOnly.authorName = @"👩\u200D💻 开发者"; handleOnly.fromUserName = @"@name\u200Dpart";
        native = BHRDSharePostFromSource(handleOnly);
        Check([native.author isEqual:handleOnly.authorName] && !native.handle.length, @"Handle cleanup preserves ZWJ display-name emoji and rejects ZWJ inside a handle");
        NativeAuthor *displayUser = [NativeAuthor new]; displayUser.fullName = @"兼容作者"; displayUser.displayUsername = @"@display_user";
        NativePost *displayStatus = Post(@"native-display-username", @"兼容原生作者格式", nil, nil); displayStatus.fromUser = displayUser;
        native = BHRDSharePostFromSource(displayStatus);
        Check([native.author isEqual:@"兼容作者"] && [native.handle isEqual:@"display_user"], @"Native displayUsername supplies an @-prefixed handle");

        NativePost *timeline = Post(@"native-timeline", @"列表展示摘要", nil, nil);
        timeline.representedFromUser = nativeUser; timeline.representedFromUserID = nativeUser.userID;
        timeline.tweet = Post(timeline.statusID, @"列表背后的完整原生推文正文", nil, nil);
        NativePost *wrappedTimeline = [NativePost new]; wrappedTimeline.viewModel = timeline;
        native = BHRDSharePostFromSource(wrappedTimeline);
        Check([native.author isEqual:@"贝塔酱"] && [native.handle isEqual:@"Walden779"] && [native.identifier isEqual:timeline.statusID], @"Wrapped timeline items read representedFromUser for the same post");
        Check([native.body isEqual:timeline.tweet.textModel.attributedString.string] && [native.avatar isEqual:nativeUser.profileImageURL], @"Timeline author enrichment keeps the nested tweet body and matching avatar");

        CacheJSON(@{@"user_results": @{@"result": @{@"rest_id": @"1760600000000000456", @"core": @{@"name": @"独立缓存作者", @"screen_name": @"cached_native"}, @"avatar": @{@"image_url": @"https://pbs.twimg.com/profile_images/native-cache.png"}}}});
        NativePost *cachedStatus = Post(@"native-user-cache", @"没有推文缓存的正文", nil, nil); cachedStatus.fromUserID = 1760600000000000456ULL;
        native = BHRDSharePostFromSource(cachedStatus);
        Check([native.author isEqual:@"独立缓存作者"] && [native.handle isEqual:@"cached_native"] && [native.authorIdentifier isEqual:@"1760600000000000456"], @"fromUserID joins a separately captured user without a cached tweet");
        Check([native.avatar.path hasSuffix:@"native-cache.png"] && [native.body isEqual:cachedStatus.textModel.attributedString.string], @"User-only cache hydration keeps the correct avatar and native body");
        NativePost *cachedTimeline = Post(@"native-represented-cache", @"只有展示作者 ID 的列表正文", nil, nil); cachedTimeline.representedFromUserID = cachedStatus.fromUserID;
        native = BHRDSharePostFromSource(cachedTimeline);
        Check([native.author isEqual:@"独立缓存作者"] && [native.handle isEqual:@"cached_native"], @"representedFromUserID joins the same separate user cache");

        NativeAuthor *quotedUser = [NativeAuthor new]; quotedUser.userID = 1760600000000000789ULL; quotedUser.fullName = @"引用原作者"; quotedUser.username = @"quoted_native";
        quotedUser.profileImageURL = [NSURL URLWithString:@"https://pbs.twimg.com/profile_images/native-quote.png"];
        NativePost *nativeQuote = Post(@"native-quote", @"独立引用正文", nil, nil); nativeQuote.fromUser = quotedUser; nativeQuote.fromUserID = quotedUser.userID;
        nativeStatus.quotedStatusViewModel = nativeQuote;
        native = BHRDSharePostFromSource(nativeStatus);
        Check([native.author isEqual:@"贝塔酱"] && [native.quotedPost.author isEqual:@"引用原作者"] && [native.quotedPost.handle isEqual:@"quoted_native"], @"Native primary and quoted authors stay separate");
        Check([native.avatar isEqual:nativeUser.profileImageURL] && [native.quotedPost.avatar isEqual:quotedUser.profileImageURL] && [native.quotedPost.authorIdentifier isEqual:@"1760600000000000789"], @"Native quoted avatar and ID belong to the quoted author");
        NativeAuthor *repostingUser = [NativeAuthor new]; repostingUser.userID = 1760600000000000999ULL; repostingUser.fullName = @"转发人"; repostingUser.username = @"native_reposter";
        repostingUser.profileImageURL = [NSURL URLWithString:@"https://pbs.twimg.com/profile_images/native-reposter.png"];
        NativePost *nativeRepost = Post(@"native-repost", @"转发摘要", nil, nil); nativeRepost.fromUser = repostingUser; nativeRepost.fromUserID = repostingUser.userID; nativeRepost.fromUserName = repostingUser.username; nativeRepost.retweetedStatus = nativeStatus;
        native = BHRDSharePostFromSource(nativeRepost);
        Check([native.identifier isEqual:nativeStatus.statusID] && [native.author isEqual:@"贝塔酱"] && [native.handle isEqual:@"Walden779"] && [native.avatar isEqual:nativeUser.profileImageURL], @"Native repost exports the original identity and avatar");
        Check([native.repostedBy isEqual:@"@native_reposter"] && [native.quotedPost.handle isEqual:@"quoted_native"], @"Native reposter remains secondary to the original and quoted authors");

        NativeAuthor *representedName = [NativeAuthor new]; representedName.userID = nativeUser.userID; representedName.fullName = nativeUser.fullName;
        NativePost *mixedItem = Post(nativeStatus.statusID, @"展示原作者的列表正文", nil, nil);
        mixedItem.representedFromUser = representedName; mixedItem.representedFromUserID = nativeUser.userID;
        mixedItem.fromUser = repostingUser; mixedItem.fromUserID = repostingUser.userID; mixedItem.fromUserName = repostingUser.username;
        native = BHRDSharePostFromSource(mixedItem);
        Check([native.author isEqual:@"贝塔酱"] && [native.authorIdentifier isEqual:@"1760600000000000123"] && !native.handle.length && !native.avatar, @"A represented author cannot borrow another native user's handle or avatar");
        mixedItem.tweet = nativeStatus;
        native = BHRDSharePostFromSource(mixedItem);
        Check([native.author isEqual:@"贝塔酱"] && [native.handle isEqual:@"Walden779"] && [native.avatar isEqual:nativeUser.profileImageURL], @"Matching nested status fills the represented author without reposter contamination");

        NSDictionary *userA = @{@"userID": @100, @"fullName": @"展示作者 A", @"username": @"author_a", @"profileImageURL": @"https://pbs.twimg.com/profile_images/author-a.png"};
        NSDictionary *userB = @{@"userID": @200, @"fullName": @"转发作者 B", @"username": @"reposter_b", @"profileImageURL": @"https://pbs.twimg.com/profile_images/reposter-b.png"};
        CacheJSON(@{@"user_results": @{@"result": @{@"rest_id": @"100", @"core": @{@"name": @"展示作者 A", @"screen_name": @"author_a"}, @"avatar": @{@"image_url": @"https://pbs.twimg.com/profile_images/author-a.png"}}}});
        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-unknown-raw", @"full_text": @"展示作者正文", @"representedFromUserID": @100, @"fromUserName": @"reposter_b"});
        Check([native.author isEqual:@"展示作者 A"] && [native.handle isEqual:@"author_a"] && [native.authorIdentifier isEqual:@"100"], @"An unverified raw handle cannot contaminate a represented user loaded from cache");
        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-raw-fallback", @"full_text": @"展示作者正文", @"representedFromUserID": @100, @"fromUser": @{@"userID": @200}, @"authorName": @"转发作者 B", @"authorScreenName": @"reposter_b"});
        Check([native.author isEqual:@"展示作者 A"] && [native.handle isEqual:@"author_a"] && [native.avatar.path hasSuffix:@"author-a.png"], @"Rejected raw identities cannot bypass author checks through direct name or handle fallbacks");
        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-raw-id-only", @"full_text": @"展示作者正文", @"representedFromUserID": @100, @"fromUserID": @200, @"authorName": @"转发作者 B"});
        Check([native.author isEqual:@"展示作者 A"] && [native.handle isEqual:@"author_a"], @"A raw ID binds direct author fallbacks even without a raw user object");
        NSDictionary *originalA = @{@"rest_id": @"represented-repost-original", @"full_text": @"作者 A 的原文", @"fromUser": userA};
        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-repost", @"full_text": @"转发摘要", @"representedFromUser": userA, @"fromUser": userB, @"retweetedStatus": originalA});
        Check([native.identifier isEqual:@"represented-repost-original"] && [native.author isEqual:@"展示作者 A"] && [native.handle isEqual:@"author_a"] && [native.repostedBy isEqual:@"@reposter_b"], @"Repost attribution comes from the raw author when represented and raw users differ");
        NSDictionary *sparseUser = @{@"userID": @111, @"fullName": @"稀疏原帖作者", @"username": @"sparse_author", @"profileImageURL": @"https://pbs.twimg.com/profile_images/sparse-author.png"};
        native = BHRDSharePostFromSource(@{@"rest_id": @"sparse-repost-wrapper", @"representedFromUser": sparseUser, @"fromUser": userB, @"retweetedStatus": @{@"rest_id": @"sparse-original", @"full_text": @"未携带用户对象的原帖正文"}});
        Check([native.identifier isEqual:@"sparse-original"] && [native.authorIdentifier isEqual:@"111"] && [native.author isEqual:@"稀疏原帖作者"] && [native.handle isEqual:@"sparse_author"] && [native.avatar.path hasSuffix:@"sparse-author.png"] && [native.repostedBy isEqual:@"@reposter_b"], @"An explicit sparse repost retains the original author already present on its wrapper");
        native = BHRDSharePostFromSource(@{@"rest_id": @"sparse-conflict-wrapper", @"representedFromUser": sparseUser, @"fromUser": userB, @"retweetedStatus": @{@"rest_id": @"sparse-conflict-original", @"full_text": @"身份明确的原帖", @"fromUser": @{@"userID": @222, @"fullName": @"原帖自身作者", @"username": @"author_c"}}});
        Check([native.authorIdentifier isEqual:@"222"] && [native.author isEqual:@"原帖自身作者"] && [native.handle isEqual:@"author_c"] && !native.avatar && [native.repostedBy isEqual:@"@reposter_b"], @"Sparse-repost enrichment cannot replace an original's explicitly conflicting identity");

        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-boxed-zero", @"full_text": @"有效原始作者", @"representedFromUserID": @0, @"fromUser": userA});
        Check([native.authorIdentifier isEqual:@"100"] && [native.handle isEqual:@"author_a"], @"A boxed zero represented user ID does not suppress a valid raw author");
        native = BHRDSharePostFromSource(@{@"rest_id": @"native-boxed-zero", @"full_text": @"有效作者 ID 回退", @"fromUser": @{@"userID": @0}, @"fromUserID": @100});
        Check([native.authorIdentifier isEqual:@"100"] && [native.author isEqual:@"展示作者 A"] && [native.handle isEqual:@"author_a"], @"A boxed zero profile ID falls back to a valid native user ID and cache");
        native = BHRDSharePostFromSource(@{@"rest_id": @"native-all-zero", @"full_text": @"未知作者 ID", @"representedFromUserID": @0, @"fromUserID": @0, @"userID": @0, @"fromUserName": @"valid_unknown"});
        Check(!native.authorIdentifier.length && [native.handle isEqual:@"valid_unknown"], @"Zero IDs remain unknown while an independently supplied handle stays usable");
        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-string-zero", @"full_text": @"字符串零也是未知 ID", @"representedFromUserID": @"0", @"fromUserID": @100});
        Check([native.authorIdentifier isEqual:@"100"] && [native.handle isEqual:@"author_a"], @"String zero and boxed zero share the same unknown-ID semantics");

        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-wrapper-cold", @"representedFromUserID": @101, @"tweet": @{@"rest_id": @"represented-wrapper-cold", @"full_text": @"包装中的完整正文", @"fromUserName": @"reposter_b"}});
        Check([native.authorIdentifier isEqual:@"101"] && !native.author.length && !native.handle.length && [native.body isEqual:@"包装中的完整正文"], @"A cold represented identity survives a wrapper without borrowing an unverified raw handle");
        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-child-priority", @"fromUser": userB, @"tweet": @{@"rest_id": @"represented-child-priority", @"full_text": @"子模型展示作者 A", @"representedFromUserID": @100}});
        Check([native.authorIdentifier isEqual:@"100"] && [native.author isEqual:@"展示作者 A"] && [native.handle isEqual:@"author_a"], @"A nested represented author supersedes a raw wrapper's unrelated author");
        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-title-cold", @"fromUser": userB, @"tweet": @{@"rest_id": @"represented-title-cold", @"full_text": @"作者尚未加载的正文", @"representedFromUserID": @104}});
        Check([native.authorIdentifier isEqual:@"104"] && !native.handle.length && [native.title isEqual:@"X 推文"], @"Replacing an unverified raw author also removes its generated attribution title");
        BHRDSharePost *customTitle = BHRDSharePostFromSource(@{@"rest_id": @"represented-custom-title", @"fromUser": userB});
        customTitle.title = @"用户自己填写的标题";
        BHRDMergeSharePost(customTitle, BHRDSharePostFromSource(@{@"rest_id": @"represented-custom-title", @"representedFromUserID": @104}));
        Check([customTitle.authorIdentifier isEqual:@"104"] && !customTitle.handle.length && [customTitle.title isEqual:@"用户自己填写的标题"], @"Replacing a raw author preserves an explicitly customized title");
        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-cold-match", @"representedFromUserID": @101, @"fromUser": @{@"userID": @101, @"fullName": @"同 ID 的作者", @"username": @"cold_author"}, @"full_text": @"同 ID 的正文"});
        Check([native.authorIdentifier isEqual:@"101"] && [native.author isEqual:@"同 ID 的作者"] && [native.handle isEqual:@"cold_author"], @"A proven matching raw user can enrich a represented identity without cache");
        native = BHRDSharePostFromSource(@{@"rest_id": @"represented-handle-match", @"representedFromUser": @{@"userID": @103, @"username": @"known_handle"}, @"fromUser": @{@"fullName": @"同用户名的作者", @"username": @"KNOWN_HANDLE", @"profileImageURL": @"https://pbs.twimg.com/profile_images/same-handle.png"}, @"full_text": @"同用户名的正文"});
        Check([native.authorIdentifier isEqual:@"103"] && [native.author isEqual:@"同用户名的作者"] && [native.handle isEqual:@"known_handle"] && [native.avatar.path hasSuffix:@"same-handle.png"], @"Matching handles can verify an unnumbered raw profile without changing represented identity");

        NativePost *main = Post(@"complete-main", @"主推文的正文", nil, nil);
        main.user = @42; // 旧 user 入口只有 ID，实际作者位于另一个模型。
        NativeAuthor *author = [NativeAuthor new]; author.displayFullName = @"完整作者名"; author.screenName = @"main_author"; author.profileImageURL = [NSURL URLWithString:@"https://pbs.twimg.com/profile_images/main.png"];
        main.authorViewModel = author;
        BHRDSharePost *result = BHRDSharePostFromSource(main);
        Check([result.author isEqual:@"完整作者名"] && [result.handle isEqual:@"main_author"], @"Do not stop at an empty user reference when authorViewModel has the author");
        Check(result.avatar != nil, @"Recover avatar from native author profile");
        Check([result.body isEqual:@"主推文的正文"], @"Unwrap native attributed-text models");
        main.noteTweet = @{@"text": @"主推文的正文\n\n长正文第二段，完整内容不会被展示摘要替代。"};
        result = BHRDSharePostFromSource(main);
        Check([result.body containsString:@"长正文第二段"], @"Read native note-tweet content beyond the preview");
        NativePost *quote = Post(@"complete-quote", @"被引用推文的完整正文与后续段落。", @"原文作者", @"quote_author");
        main.quotedStatusViewModel = quote;
        result = BHRDSharePostFromSource(main);
        Check([result.author isEqual:@"完整作者名"] && [result.quotedPost.author isEqual:@"原文作者"], @"Keep primary and quoted authors separate");
        Check([result.quotedPost.body isEqual:@"被引用推文的完整正文与后续段落。"], @"Native quote models keep their full original body");
        Check([result.quotedPost.link hasSuffix:@"complete-quote"] && [result.link hasSuffix:@"complete-main"], @"Each post has its own original link");
        BHRDSharePost *copy = [result copy]; copy.quotedPost.body = @"编辑后的文字";
        Check(![result.quotedPost.body isEqual:copy.quotedPost.body], @"Editing a copy cannot modify cached quoted originals");
        NativePost *repost = Post(@"complete-repost", @"RT 摘要", @"转发人", @"reposter"); repost.retweetedStatus = quote;
        BHRDSharePost *original = BHRDSharePostFromSource(repost);
        Check([original.author isEqual:@"原文作者"] && [original.identifier isEqual:@"complete-quote"], @"A repost exports the original author's full post");
        Check([original.repostedBy isEqual:@"@reposter"], @"Retain the reposter as secondary attribution");
        NativePost *cycle = Post(@"cycle", @"循环模型正文", @"作者", @"author"); cycle.quotedStatusViewModel = cycle;
        Check(BHRDSharePostFromSource(cycle).quotedPost == nil, @"Self-referential quote models terminate"); cycle.quotedStatusViewModel = nil;

        CacheJSON(@{@"globalObjects": @{@"tweets": @{@"late-user-post": @{@"id_str": @"late-user-post", @"user_id_str": @"late-user", @"full_text": @"缓存里的正文"}}}});
        CacheJSON(@{@"globalObjects": @{@"users": @{@"late-user": @{@"id_str": @"late-user", @"name": @"后来返回的作者", @"screen_name": @"late_author", @"profile_image_url_https": @"https://pbs.twimg.com/profile_images/late.png"}}}});
        NativePost *later = Post(@"late-user-post", @"摘要", nil, nil);
        result = BHRDSharePostFromSource(later);
        Check([result.author isEqual:@"后来返回的作者"] && [result.handle isEqual:@"late_author"], @"Separate normalized user responses hydrate cached post authors");
        later.noteTweet = @{@"text": @"缓存里的正文\n\n后来模型提供的更完整段落必须保留，不能被缓存提前返回挡住。"};
        Check([BHRDSharePostFromSource(later).body containsString:@"更完整段落"], @"A cache hit does not prevent richer native body data");
        CacheJSON(@{@"rest_id": @"rich", @"legacy": @{@"full_text": @"这是完整正文，包含后半段，不应该丢失。"}, @"core": @{@"user_results": @{@"result": @{@"core": @{@"name": @"新版作者", @"screen_name": @"modern_author"}, @"avatar": @{@"image_url": @"https://pbs.twimg.com/profile_images/new.png"}}}}});
        CacheJSON(@{@"rest_id": @"rich", @"legacy": @{@"full_text": @"短摘要", @"truncated": @YES}});
        result = BHRDSharePostFromSource(Post(@"rich", @"", nil, nil));
        Check([result.body containsString:@"后半段"] && [result.author isEqual:@"新版作者"], @"Partial later responses cannot erase full text or author data");

        NSDictionary *jsonQuote = @{@"rest_id": @"json-quote", @"legacy": @{@"full_text": @"引用内容", @"extended_entities": @{@"media": @[@{@"media_url_https": @"https://pbs.twimg.com/media/quote.png"}]}}, @"user": @{@"name": @"引用者", @"screen_name": @"quoted"}};
        CacheJSON(@{@"rest_id": @"json-main", @"legacy": @{@"full_text": @"我的评论", @"quoted_status_result": @{@"result": jsonQuote}}, @"user": @{@"name": @"评论者", @"screen_name": @"commenter"}});
        result = BHRDSharePostFromSource(Post(@"json-main", @"", nil, nil));
        Check([result.body isEqual:@"我的评论"] && [result.quotedPost.author isEqual:@"引用者"], @"Legacy nested quote results do not replace the main body");
        Check(result.quotedPost.images.count == 1 && BHRDShareImageURLs(result).count == 1, @"Quoted images are included in the editor's image-loading list");
        CacheJSON(@{@"rest_id": @"json-repost", @"legacy": @{@"full_text": @"RT: 摘要", @"retweeted_status_result": @{@"result": jsonQuote}}, @"user": @{@"name": @"转发人", @"screen_name": @"rt_user"}});
        result = BHRDSharePostFromSource(Post(@"json-repost", @"RT: 摘要", nil, nil));
        Check([result.identifier isEqual:@"json-quote"] && [result.body isEqual:@"引用内容"], @"Retweet-ID cache aliases resolve to the actual original");
        BHRDSharePost *snapshot = [BHRDSharePost new]; snapshot.body = @"第一段摘要";
        BHRDApplyShareTextRows(snapshot, @[@{@"role": @"author", @"text": @"可见作者"}, @{@"role": @"handle", @"text": @"@visible_author"}, @{@"role": @"body", @"text": @"第一段摘要"}, @{@"role": @"body", @"text": @"第一段摘要以及完整后续内容"}, @{@"role": @"body", @"text": @"第二段和最后一句"}]);
        Check([snapshot.author isEqual:@"可见作者"] && [snapshot.handle isEqual:@"visible_author"], @"Visible header rows fill missing author fields");
        Check([snapshot.body isEqual:@"第一段摘要以及完整后续内容\n\n第二段和最后一句"], @"Visible paragraph merging removes duplicated parent/child text and keeps the tail");
        BHRDApplyShareTextRows(snapshot, @[@{@"role": @"author", @"text": @"不应覆盖"}]);
        Check([snapshot.author isEqual:@"可见作者"], @"Snapshot fallback does not replace already known authors");
        NativePost *translated = Post(@"bilingual-native", @"display preview", @"Writer", @"writer");
        translated.noteTweet = @{@"text": @"Complete original English text, stored independently from its translation."};
        translated.translatedText = @"单独保存完整原文和中文译文。";
        BHRDSharePost *dual = BHRDSharePostFromSource(translated);
        Check([dual.body hasPrefix:@"Complete original"] && [dual.translatedBody isEqual:translated.translatedText], @"Read explicit native translation fields without losing the original");
        BHRDSharePost *dualCopy = [dual copy];
        Check([dualCopy.translatedBody isEqual:dual.translatedBody], @"Editing snapshots retain translation data");
        NSString *suite = [@"XSuixinAuthorMigration." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:suite];
        [prefs setBool:NO forKey:@"bhrd_share_author"];
        [prefs setBool:NO forKey:@"bhrd_share_content"];
        BHRDRestoreShareAuthorOption(prefs);
        Check([BHRDShareOptions(prefs)[@"author"] boolValue], @"Requested author visibility restored once");
        Check(![BHRDShareOptions(prefs)[@"content"] boolValue], @"Other share choices remain unchanged");
        [prefs setBool:NO forKey:@"bhrd_share_author"]; BHRDRestoreShareAuthorOption(prefs);
        Check(![BHRDShareOptions(prefs)[@"author"] boolValue], @"Later explicit author-off choice persists");
        [prefs removePersistentDomainForName:suite];
        NSDictionary *parentJSON = @{@"rest_id":@"9001", @"legacy":@{@"full_text":@"Original parent text", @"id_str":@"9001"}};
        CacheJSON(@{@"data":@[parentJSON]});
        NativePost *replyModel = Post(@"9002", @"My reply", @"Reply Writer", @"replywriter"); replyModel.inReplyToStatusID = 9001;
        BHRDSharePost *reply = BHRDSharePostFromSource(replyModel);
        Check([reply.replyToIdentifier isEqual:@"9001"] && [reply.replyContextPost.body isEqual:@"Original parent text"], @"Native numeric reply ID resolves exact cached parent");
        Check([reply.author isEqual:@"Reply Writer"] && [reply.body isEqual:@"My reply"], @"Parent does not overwrite reply author or body");
        BHRDSharePost *wrong = BHRDSharePostFromSource(Post(@"9999", @"Neighbor comment", @"Other", @"other"));
        BHRDAttachShareReplyContext(reply, wrong);
        Check([reply.replyContextPost.identifier isEqual:@"9001"], @"Unrelated visible neighbors cannot become the original");
        NSDictionary *rootJSON = @{@"rest_id":@"9000", @"legacy":@{@"full_text":@"Thread root", @"id_str":@"9000"}};
        CacheJSON(@{@"data":@[rootJSON]});
        BHRDSharePost *nested = BHRDSharePostFromSource(@{@"rest_id":@"9003", @"legacy":@{@"full_text":@"Nested reply", @"in_reply_to_status_id_str":@"9002", @"conversation_id_str":@"9000"}});
        Check([nested.replyContextPost.identifier isEqual:@"9000"], @"Nested replies prefer verified conversation root");
        Check(!BHRDSharePostFromSource(rootJSON).replyContextPost, @"Original posts do not acquire reply context");
        BHRDSharePost *missing = BHRDSharePostFromSource(@{@"rest_id":@"9004", @"legacy":@{@"full_text":@"Reply without loaded parent", @"in_reply_to_status_id_str":@"9100"}});
        Check(!missing.replyContextPost, @"Missing parents are not fabricated");
        BHRDSharePost *parent = BHRDSharePostFromSource(Post(@"9100", @"Loaded visible parent", @"Parent Author", @"parent"));
        parent.avatar = [NSURL URLWithString:@"https://pbs.twimg.com/profile_images/parent.png"]; parent.avatarData = [@"fixture" dataUsingEncoding:NSUTF8StringEncoding];
        BHRDAttachShareReplyContext(missing, parent);
        Check([missing.replyContextPost.body isEqual:parent.body], @"Matching visible parent fills cache misses");
        Check([BHRDShareImageURLs(missing) containsObject:parent.avatar] && BHRDShareEmbeddedImages(missing)[parent.avatar.absoluteString] != nil, @"Parent avatar participates in asset loading");
        BHRDSharePost *replyCopy = [missing copy]; replyCopy.replyContextPost.body = @"edited";
        Check(![missing.replyContextPost.body isEqual:@"edited"], @"Editing snapshots cannot mutate the parent cache");
        NSLog(@"PASS: %lu author/body/original-post checks", (unsigned long)checks);
    }
    return 0;
}
