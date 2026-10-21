#import <Foundation/Foundation.h>
#import "../BHRDRepostModel.h"
#import "../BHRDAdFilter.h"
#import "../BHRDSharePost.h"
#import "../BHRDShareRenderState.h"
#import "../BHRDHomeHeader.h"
#import "../BHRDTaskState.h"
#import "../BHRDStreamArguments.h"
#import "../BHRDDownloadStore.h"
@interface TFNDataViewItem : NSObject
@property(nonatomic,strong) id item;
@end
@implementation TFNDataViewItem @end
@interface ReviewTweet : NSObject
@property(nonatomic) BOOL isRetweet;
@property(nonatomic) BOOL isPromoted;
@property(nonatomic,copy) NSString *statusID;
@end
@implementation ReviewTweet @end
@interface UnknownModel : NSObject
@property(nonatomic) NSUInteger unknownReads;
@end
@implementation UnknownModel
- (id)valueForUndefinedKey:(NSString *)key { self.unknownReads++; return [super valueForUndefinedKey:key]; }
@end
static NSUInteger checks;
static void Check(BOOL value, NSString *name) { checks++; if (!value) { NSLog(@"FAIL: %@", name); exit(1); } }
static void Cache(NSDictionary *object) { BHRDCacheSharePosts(object, [NSJSONSerialization dataWithJSONObject:object options:0 error:nil]); }
int main(void) { @autoreleasepool {
    ReviewTweet *tweet=[ReviewTweet new]; tweet.isRetweet=YES; tweet.isPromoted=YES; tweet.statusID=@"wrapped-230";
    TFNDataViewItem *wrapper=[TFNDataViewItem new]; wrapper.item=tweet;
    Check(BHRDIsRepostModel(wrapper), @"Wrapped reposts enter bar/preview filtering");
    Check(BHRDIsPromotedModel(wrapper), @"Wrapped ads are recognized");
    Check([BHRDRepostIdentity(wrapper) isEqual:tweet.statusID], @"Expanded identity survives wrapper replacement");
    Check([BHRDSectionsByRemovingReposts(@[@[wrapper]])[0] count]==0, @"Hidden mode removes wrapped repost row");
    Check([BHRDSectionsByRemovingAds(@[@[wrapper]])[0] count]==0, @"Section filtering removes wrapped ad row");
    tweet.isRetweet=NO; tweet.isPromoted=NO;
    Check(!BHRDIsRepostModel(wrapper) && !BHRDIsPromotedModel(wrapper), @"Ordinary wrapped post remains");
    UnknownModel *unknown=[UnknownModel new];
    Check(!BHRDIsPromotedModel(unknown) && !BHRDIsRepostModel(unknown) && unknown.unknownReads==0, @"Missing native fields never use exception-driven probing");
    BHRDRepostInfo *author=BHRDInfoForRepostModel(@{@"rest_id":@"author-230", @"user":@{@"screen_name":@"alice",@"name":@"Alice"}, @"authorUser":@{@"screen_name":@"bob",@"profile_image_url_https":@"https://pbs.twimg.com/profile_images/bob.jpg"}});
    Check([author.authorHandle isEqual:@"alice"] && !author.avatar, @"Conflicting handles without numeric IDs cannot mix avatar");
    author=BHRDInfoForRepostModel(@{@"rest_id":@"author-231", @"user":@{@"screen_name":@"alice",@"name":@"Alice"}, @"authorUser":@{@"screen_name":@"ALICE",@"profile_image_url_https":@"https://pbs.twimg.com/profile_images/alice.jpg"}});
    Check([author.avatar.path hasSuffix:@"alice.jpg"], @"Matching handles still fill partial identity");
    Cache(@{@"rest_id":@"body-230",@"legacy":@{@"full_text":@"A very long previous full sentence"}});
    BHRDSharePost *post=BHRDSharePostFromSource(@{@"rest_id":@"body-230",@"legacy":@{@"full_text":@"Corrected"}});
    Check([post.body isEqual:@"Corrected"], @"Explicit shorter full body beats equal-quality stale cache");
    Cache(@{@"rest_id":@"body-230",@"legacy":@{@"full_text":@"Corrected"}});
    Check([BHRDSharePostFromSource(@{@"rest_id":@"body-230"}).body isEqual:@"Corrected"], @"Updated full body replaces cached earlier text");
    Cache(@{@"rest_id":@"body-230",@"legacy":@{@"full_text":@"Cor…",@"truncated":@YES}});
    Check([BHRDSharePostFromSource(@{@"rest_id":@"body-230"}).body isEqual:@"Corrected"], @"Explicitly truncated refresh cannot replace complete body");
    post.avatar=[NSURL URLWithString:@"https://pbs.twimg.com/profile_images/a.png"];
    post.images=@[[NSURL URLWithString:@"https://pbs.twimg.com/media/a.png"]];
    post.quotedPost=[BHRDSharePost new]; post.quotedPost.images=@[[NSURL URLWithString:@"https://pbs.twimg.com/media/q.png"]];
    Check(BHRDShareVisibleImageURLs(post,@{@"content":@NO,@"author":@NO}).count==0,@"Text-only export has no hidden image dependency");
    Check([BHRDShareVisibleImageURLs(post,@{@"content":@NO,@"author":@YES}) isEqual:@[post.avatar]],@"Author-only export requests no body or quote media");
    Check(BHRDShareVisibleImageURLs(post,@{@"content":@YES,@"author":@NO}).count==2,@"Content-only export excludes avatars");
    BHRDShareRenderState *state=[BHRDShareRenderState new];
    NSUInteger initial=[state invalidate]; Check([state accept:initial],@"Initial render can finish");
    Check([state canExportPNG:YES pendingImages:0 exporting:NO],@"Current image is exportable");
    NSUInteger incoming=[state invalidate];
    Check(![state canExportPNG:YES pendingImages:0 exporting:NO],@"Last image arrival blocks old PNG before delayed rendering starts");
    Check(![state accept:initial] && state.rendering,@"Late prior render cannot enable old export");
    NSUInteger theme=[state invalidate]; Check(![state accept:incoming],@"Theme change invalidates pending image render");
    Check([state accept:theme] && [state canExportPNG:YES pendingImages:0 exporting:NO],@"Only newest generation unlocks export");
    Check(![state canExportPNG:YES pendingImages:1 exporting:NO] && ![state canExportPNG:YES pendingImages:0 exporting:YES],@"Required image and photo write each block export");
    Check([state scheduleImageRender],@"First image arrival schedules one debounce");
    NSUInteger interleaved=[state invalidate]; [state accept:interleaved];
    Check(![state scheduleImageRender] && ![state canExportPNG:YES pendingImages:0 exporting:NO],@"Coalesced second image invalidates an intervening completed theme render");
    [state clearImageRenderSchedule]; Check([state scheduleImageRender],@"Completed debounce allows scheduling next image batch");
    NSArray *pages=@[@"extra",@"following",@"for-you"];
    Check([BHRDHomeSelectPrimaryPages(pages,@[@0,@2,@1]) isEqual:@[@"for-you",@"following"]],@"Reordered host pages follow semantic tab identity");
    Check(!BHRDHomeSelectPrimaryPages(pages,@[@0,@0,@1]),@"Unknown following page leaves native pager intact");
    Check(!BHRDHomeSelectPrimaryPages(pages,@[@1,@2,@1]),@"Ambiguous duplicate page identities cannot be truncated");
    NSObject *a=[NSObject new], *b=[NSObject new];
    Check(BHRDTryBeginTransfer(a) && !BHRDTryBeginTransfer(b),@"Different button and stream owners share admission");
    BHRDEndTransfer(b); Check(!BHRDTryBeginTransfer(b),@"Unrelated task cannot release live download");
    BHRDEndTransfer(a); Check(BHRDTryBeginTransfer(b),@"Completion/cancellation releases admission"); BHRDEndTransfer(b);
    NSArray *args=BHRDStreamArguments([NSURL URLWithString:@"https://video.twimg.com/a.m3u8"],@3,[NSURL fileURLWithPath:@"/tmp/video name.mp4"]);
    Check([args containsObject:@"0:3"] && [args containsObject:@"copy"] && ![args containsObject:@"-vf"] && ![args containsObject:@"-b:v"],@"Selected original stream is remuxed without resizing or bitrate loss");
    Check(!BHRDStreamArguments(nil,@1,nil),@"Invalid stream requests do not launch FFmpeg");
    NSURL *dir=[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *partial=[dir URLByAppendingPathComponent:@"test.partial.mp4"];
    [@"fixture" writeToURL:partial atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSURL *ready=BHRDCompleteDownload(partial);
    Check(ready && ![NSFileManager.defaultManager fileExistsAtPath:partial.path] && [NSFileManager.defaultManager fileExistsAtPath:ready.path],@"Completed stream becomes a recoverable finished file");
    NSURL *active=[dir URLByAppendingPathComponent:@"active.partial.mp4"], *unrelated=[dir URLByAppendingPathComponent:@"keep.txt"];
    [@"active" writeToURL:active atomically:YES encoding:NSUTF8StringEncoding error:nil]; [@"keep" writeToURL:unrelated atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSDate *old=[NSDate dateWithTimeIntervalSinceNow:-8*24*3600];
    for (NSURL *url in @[ready,active,unrelated]) [NSFileManager.defaultManager setAttributes:@{NSFileModificationDate:old} ofItemAtPath:url.path error:nil];
    BHRDPruneDownloads(dir,NSDate.date,[NSSet setWithObject:active.path]);
    Check(![NSFileManager.defaultManager fileExistsAtPath:ready.path],@"Expired retained downloads are removed");
    Check([NSFileManager.defaultManager fileExistsAtPath:active.path] && [NSFileManager.defaultManager fileExistsAtPath:unrelated.path],@"Cleanup excludes active transfers and unrelated file types");
    BHRDPruneDownloads(dir,NSDate.date,[NSSet set]); Check(![NSFileManager.defaultManager fileExistsAtPath:active.path],@"Abandoned old partials can be cleaned after restart");
    [NSFileManager.defaultManager removeItemAtURL:dir error:nil];
    NSLog(@"PASS: %lu release-2.3.0 regression checks",(unsigned long)checks);
} return 0; }
