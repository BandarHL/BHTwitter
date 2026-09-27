#import <Foundation/Foundation.h>
#import "../BHRDRepostModel.h"
@interface IdentityUser : NSObject
@property(nonatomic) unsigned long long userID;
@property(nonatomic,copy) NSString *fullName;
@property(nonatomic,copy) NSString *username;
@property(nonatomic,strong) NSURL *profileImageURL;
@end
@implementation IdentityUser @end
@interface IdentityPost : NSObject
@property(nonatomic) BOOL isRetweet;
@property(nonatomic,copy) NSString *statusID;
@property(nonatomic,strong) id fromUser;
@property(nonatomic) unsigned long long fromUserID;
@property(nonatomic,copy) NSString *fromUserName;
@property(nonatomic,strong) id representedFromUser;
@property(nonatomic) unsigned long long representedFromUserID;
@property(nonatomic,strong) id retweetedStatus;
@property(nonatomic,strong) id status;
@property(nonatomic,strong) id user;
@property(nonatomic,copy) NSString *authorName;
@property(nonatomic,copy) NSArray *representedMediaEntities;
@end
@implementation IdentityPost @end
static NSUInteger checks;
static void Check(BOOL ok, NSString *name) { checks++; if (!ok) { NSLog(@"FAIL: %@",name); exit(1); } }
static IdentityUser *User(unsigned long long identity, NSString *name, NSString *handle) {
    IdentityUser *user=[IdentityUser new]; user.userID=identity; user.fullName=name; user.username=handle;
    user.profileImageURL=[NSURL URLWithString:[NSString stringWithFormat:@"https://pbs.twimg.com/profile_images/%@.jpg",handle]]; return user;
}
static IdentityPost *Post(NSString *identity, IdentityUser *author) {
    IdentityPost *post=[IdentityPost new]; post.statusID=identity; post.isRetweet=YES; post.representedFromUser=author;
    post.representedMediaEntities=@[@{@"mediaURL":@"https://pbs.twimg.com/media/same-photo.jpg"}]; return post;
}
static BOOL IsAuthor(BHRDRepostInfo *info, IdentityUser *author) {
    return [info.authorName isEqual:author.fullName] && [info.authorHandle isEqual:author.username] && [info.avatar isEqual:author.profileImageURL];
}
int main(void) { @autoreleasepool {
    IdentityUser *original=User(200,@"Original Writer",@"original_writer"), *reposter=User(100,@"Reposter",@"reposter");
    IdentityPost *row=Post(@"241-1",original); row.fromUser=reposter;
    row.user=@{@"name":@"Stale generic user",@"screen_name":@"stale",@"profile_image_url_https":@"https://pbs.twimg.com/profile_images/stale.jpg"};
    BHRDRepostInfo *first=BHRDInfoForRepostModel(row);
    Check(IsAuthor(first,original),@"Displayed original supplies one coherent name/handle/avatar tuple");
    Check([first.authorIdentifier isEqual:@"200"],@"Original numeric user ID is preserved");
    Check(first.thumbnails.count==1,@"Original author recovery preserves media");
    IdentityPost *recreated=Post(@"241-1",nil); recreated.fromUser=reposter; recreated.authorName=@"Reposter from incomplete wrapper";
    Check(IsAuthor(BHRDInfoForRepostModel(recreated),original),@"Rebuilt model after returning from detail restores original identity");
    recreated.representedFromUserID=200;
    Check(IsAuthor(BHRDInfoForRepostModel(recreated),original),@"ID-only refresh does not erase recovered name and avatar");
    Check(IsAuthor(BHRDInfoForRepostModel(Post(@"241-1",nil)),original),@"Switching Following/For You wrappers retains same-post metadata");
    first.authorName=@"Mutated UI snapshot"; first.avatar=nil;
    Check(IsAuthor(BHRDInfoForRepostModel(Post(@"241-1",nil)),original),@"UI snapshot mutation cannot poison model or metadata cache");
    IdentityPost *nested=Post(@"241-original",nil); nested.isRetweet=NO; nested.fromUser=original;
    IdentityPost *outer=Post(@"241-repost",reposter); outer.retweetedStatus=nested; outer.fromUser=reposter;
    BHRDRepostInfo *resolved=BHRDInfoForRepostModel(outer);
    Check(IsAuthor(resolved,original),@"Explicit original wins over contradictory outer represented user");
    Check([resolved.postIdentifier isEqual:@"241-original"],@"Author snapshot binds the original tweet ID");
    Check(IsAuthor(BHRDInfoForRepostModel(Post(@"241-repost",nil)),original),@"Retweet ID alias resolves the original after old cell is destroyed");
    IdentityPost *bare=Post(@"241-bare-reposter",nil); bare.fromUser=reposter; bare.fromUserID=100;
    bare.user=@{@"screen_name":@"reposter",@"name":@"Reposter"}; bare.authorName=@"Reposter";
    Check(!BHRDInfoForRepostModel(bare).authorHandle.length,@"An outer fromUser alone is not relabeled as original author");
    Check(!BHRDInfoForRepostModel(bare).avatar,@"An outer reposter avatar is not used for unknown original");
    IdentityUser *nameOnly=[IdentityUser new]; nameOnly.fullName=@"Original Writer";
    IdentityPost *partialOriginal=Post(@"241-name-only",nameOnly); partialOriginal.isRetweet=NO;
    partialOriginal.fromUser=reposter; partialOriginal.user=@{@"name":@"Reposter",@"screen_name":@"reposter",@"profile_image_url_https":@"https://pbs.twimg.com/profile_images/reposter.jpg"};
    BHRDRepostInfo *partialInfo=BHRDInfoForRepostModel(partialOriginal);
    Check([partialInfo.authorName isEqual:@"Original Writer"] && !partialInfo.authorHandle.length,@"Name-only represented author never borrows the raw user's handle");
    Check(!partialInfo.avatar && !partialInfo.authorIdentifier.length,@"Partial represented identity never combines with generic reposter avatar/ID");
    IdentityPost *weak=Post(@"241-correction",nil); weak.user=@{@"name":@"Wrong",@"screen_name":@"wrong",@"profile_image_url_https":@"https://pbs.twimg.com/profile_images/wrong.jpg"};
    (void)BHRDInfoForRepostModel(weak);
    Check(IsAuthor(BHRDInfoForRepostModel(Post(@"241-correction",original)),original),@"Native represented identity replaces a weak cached generic identity atomically");
    Check(IsAuthor(BHRDInfoForRepostModel(Post(@"241-correction",nil)),original),@"Corrected original is retained for later partial models");
    IdentityPost *reuse=Post(@"241-reuse-a",original); (void)BHRDInfoForRepostModel(reuse);
    reuse.statusID=@"241-reuse-b"; reuse.representedFromUser=nil;
    Check(!BHRDInfoForRepostModel(reuse).authorHandle.length,@"Reused model object cannot carry old post author to a new ID");
    IdentityUser *other=User(300,@"Other Writer",@"other_writer");
    reuse.representedFromUser=other; Check(IsAuthor(BHRDInfoForRepostModel(reuse),other),@"New post acquires its own coherent identity");
    Check(IsAuthor(BHRDInfoForRepostModel(Post(@"241-reuse-a",nil)),original),@"Reuse does not overwrite the previous post cache");
    IdentityPost *zeroA=Post(@"0",original), *zeroB=Post(@"0",other);
    Check(![BHRDRepostIdentity(zeroA) isEqual:BHRDRepostIdentity(zeroB)],@"Zero IDs cannot collapse unrelated posts onto one cache key");
    Check(IsAuthor(BHRDInfoForRepostModel(zeroA),original) && IsAuthor(BHRDInfoForRepostModel(zeroB),other),@"Anonymous row snapshots remain isolated");
    IdentityUser *partial=User(200,@"",@""); partial.profileImageURL=nil;
    Check(IsAuthor(BHRDInfoForRepostModel(Post(@"241-1",partial)),original),@"Empty native strings are missing fields, not destructive updates");
    IdentityUser *bidi=User(400,@"方向字符作者",@"\u2066\u202A@bidi_user\u202C\u2069"); bidi.profileImageURL=nil;
    Check([BHRDInfoForRepostModel(Post(@"241-bidi",bidi)).authorHandle isEqual:@"bidi_user"],@"Native directional handle formatting is normalized");
    IdentityPost *changingWrapper=Post(@"241-wrapper",nil); changingWrapper.status=Post(@"241-inner-a",original);
    (void)BHRDInfoForRepostModel(changingWrapper); changingWrapper.status=Post(@"241-inner-b",other);
    Check(IsAuthor(BHRDInfoForRepostModel(changingWrapper),other),@"A changed inner status cannot be redirected to an older cached alias");
    IdentityPost *sameMedia=Post(@"241-unrelated-same-media",nil);
    Check(!BHRDInfoForRepostModel(sameMedia).authorHandle.length,@"Equal media URLs do not imply equal tweet or author identity");
    NSLog(@"PASS: %lu repost author and return-lifecycle checks",(unsigned long)checks);
} return 0; }
