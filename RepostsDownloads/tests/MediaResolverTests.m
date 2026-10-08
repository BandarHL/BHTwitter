#import <Foundation/Foundation.h>
#import "../BHRDMediaResolver.h"
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) { checks++; if (!pass) { NSLog(@"FAIL: %@", name); exit(1); } }
@interface Variant : NSObject
@property(nonatomic, copy) NSString *url;
@property(nonatomic, copy) NSString *contentType;
@end
@implementation Variant @end
@interface Info : NSObject
@property(nonatomic, copy) NSArray *variants;
@end
@implementation Info @end
@interface Media : NSObject
@property(nonatomic, strong) Info *videoInfo;
@end
@implementation Media @end
@interface Model : NSObject
@property(nonatomic, copy) NSString *statusID;
@property(nonatomic, copy) NSArray *representedMediaEntities;
@property(nonatomic, weak) id delegate;
@end
@implementation Model @end
@interface Wrapper : NSObject
@property(nonatomic, strong) id viewModel;
@end
@implementation Wrapper @end
@interface Asset : NSObject
@property(nonatomic, copy) NSURL *URL;
@end
@implementation Asset @end
@interface Item : NSObject
@property(nonatomic, strong) Asset *asset;
@end
@implementation Item @end
@interface Player : NSObject
@property(nonatomic, strong) Item *currentItem;
@end
@implementation Player @end
@interface ScalarGetter : NSObject
- (NSUInteger)media;
@end
@implementation ScalarGetter
- (NSUInteger)media { return 42; }
@end
@interface ThrowingGetter : NSObject
- (id)currentItem;
@end
@implementation ThrowingGetter
- (id)currentItem { [NSException raise:@"FixtureUnavailable" format:@"Native getter temporarily unavailable"]; return nil; }
@end
@interface ThrowingSignature : NSObject @end
@implementation ThrowingSignature
- (BOOL)respondsToSelector:(SEL)selector {
    if (selector == NSSelectorFromString(@"currentItem") || selector == NSSelectorFromString(@"statusID")) return YES;
    return [super respondsToSelector:selector];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    if (selector == NSSelectorFromString(@"currentItem") || selector == NSSelectorFromString(@"statusID")) {
        [NSException raise:@"FixtureSignatureUnavailable" format:@"Native signature temporarily unavailable"];
    }
    return [super methodSignatureForSelector:selector];
}
@end
static Media *Video(NSString *assetID) {
    Media *media = [Media new]; media.videoInfo = [Info new];
    NSMutableArray *variants = [NSMutableArray array];
    for (NSString *quality in @[@"480x270", @"640x360", @"1280x720", @"1920x1080"]) {
        Variant *v = [Variant new]; v.contentType = @"video/mp4";
        v.url = [NSString stringWithFormat:@"https://video.twimg.com/ext_tw_video/%@/pu/vid/%@/sample.mp4", assetID, quality];
        [variants addObject:v];
    }
    Variant *hls = [Variant new]; hls.contentType = @"application/x-mpegURL";
    hls.url = [NSString stringWithFormat:@"https://video.twimg.com/ext_tw_video/%@/pu/pl/sample.m3u8", assetID];
    [variants addObject:hls]; media.videoInfo.variants = variants; return media;
}
static NSString *FirstURL(NSArray *media) { return BHRDMediaObject([BHRDMediaObject(BHRDMediaObject(media.firstObject, @"videoInfo"), @"variants") firstObject], @"url"); }
int main(void) {
    @autoreleasepool {
        Media *videoA = Video(@"asset-A"), *videoB = Video(@"asset-B");
        Model *inlineModel = [Model new]; inlineModel.statusID = @"tweet-A"; inlineModel.representedMediaEntities = @[videoA];
        NSArray *inlineResult = BHRDResolveMedia(inlineModel);
        Check([inlineResult isEqual:@[videoA]], @"Keep the working inline-button media path");
        Check([videoA.videoInfo.variants count] == 5, @"Preserve all native quality choices including HLS");
        Model *fullscreenModel = [Model new]; fullscreenModel.statusID = @"tweet-A";
        Check([BHRDResolveMedia(fullscreenModel) isEqual:inlineResult], @"A separate fullscreen model with the same tweet ID recovers inline qualities");
        Wrapper *wrapper = [Wrapper new]; wrapper.viewModel = fullscreenModel;
        Check([BHRDResolveMedia(wrapper) isEqual:inlineResult], @"Recover native data through fullscreen model wrappers");
        fullscreenModel.statusID = @"tweet-B";
        Check(BHRDResolveMedia(fullscreenModel).count == 0, @"Reusing the fullscreen model for another tweet invalidates old cache");
        fullscreenModel.representedMediaEntities = @[videoB];
        Check([BHRDResolveMedia(fullscreenModel) isEqual:@[videoB]], @"Newly loaded media takes priority over old data");
        fullscreenModel.representedMediaEntities = nil;
        Check([BHRDResolveMedia(fullscreenModel) isEqual:@[videoB]], @"Same identified video survives a temporary loss of variants");
        Player *player = [Player new]; player.currentItem = [Item new]; player.currentItem.asset = [Asset new];
        player.currentItem.asset.URL = [NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/asset-A/pu/pl/different-playlist.m3u8?tag=1"];
        Check([BHRDResolveMedia(player) isEqual:@[videoA]], @"The playing HLS asset recovers the complete inline variant list by video ID");
        player.currentItem.asset.URL = [NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/asset-B/pu/vid/640x360/another-file.mp4"];
        Check([BHRDResolveMedia(player) isEqual:@[videoB]], @"Reused AVPlayer-like object follows its new current item");
        player.currentItem.asset.URL = [NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/asset-C/pu/vid/640x360/file.mp4"];
        NSArray *direct = BHRDResolveMedia(player);
        Check(direct.count == 1 && [FirstURL(direct) containsString:@"asset-C"], @"Unknown but currently playing MP4 remains downloadable");
        player.currentItem.asset.URL = [NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/asset-D/pu/pl/file.m3u8"];
        NSArray *hls = BHRDResolveMedia(player);
        Check(hls.count == 1 && [FirstURL(hls) containsString:@"asset-D"], @"No stale player-object cache when the current asset changes");
        player.currentItem.asset.URL = [NSURL URLWithString:@"https://unrelated.example/video.mp4"];
        Check(BHRDResolveMedia(player).count == 0, @"Do not reuse a previous video for an unrelated asset URL");
        player.currentItem.asset.URL = [NSURL fileURLWithPath:@"/tmp/video.mp4"];
        Check(BHRDResolveMedia(player).count == 0, @"Local player files are not treated as remote download URLs");
        Model *unknown = [Model new]; unknown.statusID = @"unseen-tweet";
        Check(BHRDResolveMedia(unknown).count == 0, @"An unidentified current video never uses the globally last downloaded video");
        unknown.delegate = unknown;
        Check(BHRDResolveMedia(unknown).count == 0, @"Cyclic native delegate graphs terminate");
        Check(BHRDResolveMedia([ScalarGetter new]).count == 0, @"Scalar private getters are not invoked as Objective-C object returns");
        Model *multi = [Model new]; multi.statusID = @"tweet-multi"; multi.representedMediaEntities = @[videoA, videoB, videoA];
        Check([BHRDResolveMedia(multi) isEqual:@[videoA, videoB]], @"Multi-video inline posts retain order without duplicate media");
        Check(BHRDResolveMedia(nil).count == 0 && BHRDResolveMedia(NSNull.null).count == 0, @"Nil and null sources safely produce no media");
        Model *anonymous = [Model new]; anonymous.representedMediaEntities = @[Video(@"anonymous")];
        (void)BHRDResolveMedia(anonymous); anonymous.representedMediaEntities = nil;
        Check(BHRDResolveMedia(anonymous).count == 0, @"Anonymous reused models cannot inherit an unverifiable old video");
        Check([BHRDMediaStatusIdentity(@{@"viewModel":@{@"representedStatus":@{@"restID":@123456}}}) isEqual:@"123456"], @"Current wrapper status identity is available before details hydration");
        Check([BHRDMediaStatusIdentity(@{@"tweet":@{@"statusID":@"tweet-wrapped"}}) isEqual:@"tweet-wrapped"], @"Tweet wrapper identity is read through bounded explicit getters");
        NSDictionary *live = BHRDResolveLiveVideoSource(@{@"playerSessionProducer":@{@"sessionProducible":@{@"playerSession":@{@"player":@{@"currentItem":@{@"asset":@{@"URL":@"https://video.twimg.com/ext_tw_video/live-unhydrated/pu/pl/master.m3u8?tag=21"}}}}}}});
        Check([live[@"media"] count] == 1 && [FirstURL(live[@"media"]) containsString:@"live-unhydrated"], @"Playing HLS session resolves without visiting comments or hydrated post metadata");
        Check([live[@"stage"] isEqual:@"live_asset"] && [live[@"sourcePath"] containsString:@"currentItem.asset.URL"], @"Live resource result identifies the actual getter path");
        Check([live[@"identity"] isEqual:@"asset:ext_tw_video/live-unhydrated"], @"Selection resource identity is tied to current asset, never a player object's address");
        NSMutableDictionary *reusedItem = [@{@"asset":@{@"URL":@"https://video.twimg.com/ext_tw_video/live-new/pu/vid/720x1280/new.mp4"}} mutableCopy];
        NSDictionary *reused = @{@"currentItem":reusedItem, @"viewModel":inlineModel};
        live = BHRDResolveLiveVideoSource(reused);
        Check([FirstURL(live[@"media"]) containsString:@"live-new"], @"Current playing asset wins over hydrated old post metadata on a reused player");
        NSString *firstIdentity = live[@"identity"];
        reusedItem[@"asset"] = @{@"URL":@"https://video.twimg.com/ext_tw_video/live-next/pu/pl/new.m3u8"};
        live = BHRDResolveLiveVideoSource(reused);
        Check(![firstIdentity isEqual:live[@"identity"]] && [FirstURL(live[@"media"]) containsString:@"live-next"], @"Swiping with the same player and item wrapper follows the new current resource");
        live = BHRDResolveLiveVideoSource(@{@"currentMediaEntity":videoB, @"representedMediaEntities":@[videoA,videoB]});
        Check([live[@"media"] count] == 1 && [FirstURL(live[@"media"]) containsString:@"asset-B"], @"Explicit current media takes precedence over other videos in the same post");
        live = BHRDResolveLiveVideoSource(@{@"viewModel":@{@"representedStatus":@{@"statusID":@"native-before-details", @"extendedEntities":@{@"media":@[videoB]}}}});
        Check([live[@"media"] count] == 1 && [live[@"statusIdentity"] isEqual:@"native-before-details"], @"Live native status wrappers resolve a single coherent video");
        live = BHRDResolveLiveVideoSource(@{@"representedMediaEntities":@[videoA,videoB]});
        Check([live[@"media"] count] == 0 && [live[@"reason"] isEqual:@"ambiguous_current_media"], @"Unselected multi-video native metadata cannot borrow the first video");
        live = BHRDResolveLiveVideoSource(@{@"currentMediaEntity":@{@"videoInfo":@{@"variants":@[@{@"url":@"https://video.twimg.com/ext_tw_video/mixed-A/pu/pl/a.m3u8"},@{@"url":@"https://video.twimg.com/ext_tw_video/mixed-B/pu/pl/b.m3u8"}]}}});
        Check([live[@"media"] count] == 0 && [live[@"reason"] isEqual:@"ambiguous_current_media"], @"One native entity with contradictory variant identities is rejected");
        live = BHRDResolveLiveVideoSource(@{@"player":@{@"currentItem":@{@"asset":@{@"URL":@"https://video.twimg.com/ext_tw_video/first/pu/pl/a.m3u8"}}}, @"currentPlayer":@{@"currentItem":@{@"asset":@{@"URL":@"https://video.twimg.com/ext_tw_video/second/pu/pl/b.m3u8"}}}});
        Check([live[@"media"] count] == 0 && [live[@"reason"] isEqual:@"ambiguous_current_assets"], @"Conflicting current playback resources fail closed");
        live = BHRDResolveLiveVideoSource(@{@"statusID":@"tweet-A"});
        Check([live[@"media"] count] == 0 && [live[@"statusIdentity"] isEqual:@"tweet-A"], @"Strict live resolver never substitutes a previously cached identified post when metadata is missing");
        live = BHRDResolveLiveVideoSource(@{@"delegate":inlineModel});
        Check([live[@"media"] count] == 0, @"Generic delegate graphs are excluded from current-video resolution");
        live = BHRDResolveLiveVideoSource(@{@"playbackResource":@{@"resourceURL":@"https://video.twimg.com/amplify_video/live-resource/pl/main.m3u8"}});
        Check([live[@"media"] count] == 1 && [live[@"sourcePath"] containsString:@"playbackResource.resourceURL"], @"Private playback resource URL wrappers support HLS");
        live = BHRDResolveLiveVideoSource(@{@"assetURL":@"https://video.twimg.com/ext_tw_video/live-direct/pu/vid/1280x720/file.mp4"});
        Check([live[@"media"] count] == 1 && [FirstURL(live[@"media"]) containsString:@"live-direct"], @"Current private assetURL supports direct MP4");
        live = BHRDResolveLiveVideoSource(@{@"currentItem":@{@"asset":@{@"URL":@"https://foreign.example/video.mp4"}}});
        Check([live[@"media"] count] == 0 && [live[@"reason"] isEqual:@"unsupported_current_asset"], @"Foreign assets are reported rather than downloaded as an X video");
        live = BHRDResolveLiveVideoSource(@{@"currentItem":@{@"asset":@{@"URL":[NSURL fileURLWithPath:@"/tmp/native-player-cache.mp4"]}}});
        Check([live[@"media"] count] == 0, @"Local playback caches cannot fabricate a remote download URL");
        live = BHRDResolveLiveVideoSource(@{@"currentItem":@{@"asset":@{}}, @"viewModel":inlineModel});
        Check([live[@"media"] count] == 0 && [live[@"reason"] isEqual:@"current_item_resource_unavailable"], @"An opaque current item never falls back to a recycled hydrated old tweet");
        live = BHRDResolveLiveVideoSource(@{@"currentItem":NSNull.null, @"viewModel":inlineModel});
        Check([live[@"media"] count] == 0, @"A not-yet-attached current playback item cannot download its old view model");
        live = BHRDResolveLiveVideoSource(@{@"currentItem":@{@"asset":@{}}, @"assetURL":@"https://video.twimg.com/ext_tw_video/parent-old/pu/pl/old.m3u8"});
        Check([live[@"media"] count] == 0, @"A parent playback URL cannot override an unreadable newly bound item");
        live = BHRDResolveLiveVideoSource(@{@"currentItem":@{@"asset":@{@"URL":@"https://video.twimg.com/ext_tw_video/item-new/pu/pl/new.m3u8"}}, @"assetURL":@"https://video.twimg.com/ext_tw_video/parent-old/pu/pl/old.m3u8"});
        Check([FirstURL(live[@"media"]) containsString:@"item-new"], @"Bound item URL takes precedence over a stale parent resource URL");
        Check([BHRDResolveLiveVideoSource([ScalarGetter new])[@"media"] count] == 0, @"Strict wrapper probing never invokes a scalar getter as an object getter");
        Check([BHRDResolveLiveVideoSource([ThrowingGetter new])[@"media"] count] == 0, @"Temporarily throwing native getter cannot crash video resolution");
        Check([BHRDResolveLiveVideoSource([ThrowingSignature new])[@"media"] count] == 0 && !BHRDMediaStatusIdentity([ThrowingSignature new]), @"Native signature probing exceptions are isolated for resources and status identity");
        NSMutableDictionary *cycle = [NSMutableDictionary dictionary]; id cycleReference = cycle; cycle[@"playerSession"] = cycleReference;
        Check([BHRDResolveLiveVideoSource(cycle)[@"media"] count] == 0, @"Current session cycles terminate within the traversal budget");
        [cycle removeAllObjects];
        Media *mutating = Video(@"mutable-original");
        Model *mutatingModel = [Model new]; mutatingModel.statusID = @"mutable-post"; mutatingModel.representedMediaEntities = @[mutating];
        (void)BHRDResolveMedia(mutatingModel);
        mutating.videoInfo = Video(@"mutable-recycled").videoInfo;
        player.currentItem.asset.URL = [NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/mutable-original/pu/pl/current.m3u8"];
        live = BHRDResolveLiveVideoSource(player);
        Check([FirstURL(live[@"media"]) containsString:@"mutable-original"] && ![FirstURL(live[@"media"]) containsString:@"mutable-recycled"], @"Asset quality cache rechecks recycled native entity identity before use");
        live = BHRDResolveLiveVideoSource(@{@"currentMediaEntity":@{@"videoInfo":@{@"primaryUrl":@"https://video.twimg.com/ext_tw_video/primary-only/pu/pl/main.m3u8"}}});
        Check([live[@"media"] count] == 1, @"A current native primaryUrl remains usable when variants are not hydrated");
        Check([BHRDResolveLiveVideoSource(nil)[@"media"] count] == 0 && [BHRDResolveLiveVideoSource(NSNull.null)[@"media"] count] == 0, @"Strict nil and null inputs remain safely unresolved");
        Check([NSJSONSerialization dataWithJSONObject:@{@"identity":live[@"identity"],@"reason":live[@"reason"],@"stage":live[@"stage"],@"sourcePath":live[@"sourcePath"]} options:0 error:nil].length > 0, @"Resolution diagnostics are JSON-safe without persisting full resource URLs");
        NSMutableArray *wideLevel = [NSMutableArray array];
        for (NSUInteger index = 0; index < 256; index++) [wideLevel addObject:[NSMutableDictionary new]];
        while (wideLevel.count > 1) {
            NSMutableArray *parents = [NSMutableArray array];
            for (NSUInteger index = 0; index < wideLevel.count; index += 2)
                [parents addObject:@{@"viewModel":wideLevel[index],@"mediaViewModel":wideLevel[index+1]}];
            wideLevel = parents;
        }
        live = BHRDResolveLiveVideoSource(@{@"assetURL":@"https://video.twimg.com/ext_tw_video/early-candidate/pu/pl/current.m3u8",@"viewModel":wideLevel.firstObject});
        Check([live[@"media"] count] == 0 && [live[@"reason"] isEqual:@"resource_scan_budget_exceeded"], @"A live resource discovered early is rejected when more than 160 nodes remain unverified");
        NSMutableArray *nativeLevel = [NSMutableArray array];
        for (NSUInteger index = 0; index < 256; index++) [nativeLevel addObject:[NSMutableDictionary new]];
        while (nativeLevel.count > 1) {
            NSMutableArray *parents = [NSMutableArray array];
            for (NSUInteger index = 0; index < nativeLevel.count; index += 2)
                [parents addObject:[NSMutableArray arrayWithObjects:nativeLevel[index],nativeLevel[index+1],nil]];
            nativeLevel = parents;
        }
        live = BHRDResolveLiveVideoSource(@{@"representedMediaEntities":@[videoA,nativeLevel.firstObject]});
        Check([live[@"media"] count] == 0 && [live[@"reason"] isEqual:@"resource_scan_budget_exceeded"], @"A native media candidate discovered early is rejected when native traversal exceeds 160 nodes");
        id deepSource = @{@"assetURL":@"https://video.twimg.com/ext_tw_video/deep-conflict/pu/pl/later.m3u8"};
        for (NSUInteger index = 0; index < 14; index++) deepSource = @{@"viewModel":deepSource};
        live = BHRDResolveLiveVideoSource(@{@"assetURL":@"https://video.twimg.com/ext_tw_video/depth-early/pu/pl/first.m3u8",@"viewModel":deepSource});
        Check([live[@"media"] count] == 0 && [live[@"reason"] isEqual:@"resource_scan_budget_exceeded"], @"Unverified descendants beyond the depth limit never authorize an earlier resource");
        NSDictionary *bound=BHRDResolveBoundVideoSource(@{@"statusID":@"same-inline-post",@"representedMediaEntities":@[videoA,videoB]});
        Check([bound[@"media"] count]==2 && [bound[@"assetIdentities"] count]==2,@"Bound native post keeps both grouped parameter lists instead of rejecting a multi-video post");
        Check([BHRDMediaObject(BHRDMediaObject([bound[@"media"] firstObject],@"videoInfo"),@"variants") count]==[videoA.videoInfo.variants count],@"Bound model snapshots preserve every quality used by the native button");
        NSMutableDictionary *boundModel=[@{@"statusID":@"same-inline-post",@"representedMediaEntities":@[videoA]} mutableCopy];
        NSString *boundToken=BHRDResolveBoundVideoSource(boundModel)[@"identity"];
        Check([boundToken isEqual:BHRDResolveBoundVideoSource(boundModel)[@"identity"]],@"The same native model remains a stable selection");
        boundModel[@"representedMediaEntities"]=@[videoB];
        Check(![boundToken isEqual:BHRDResolveBoundVideoSource(boundModel)[@"identity"]],@"In-place media rebinding invalidates the previous bound selection");
        Check(![BHRDResolveBoundVideoSource(@{@"delegate":@{@"viewModel":inlineModel}})[@"media"] count],@"Bound source never walks an unrelated delegate graph");
        Check(![BHRDResolveBoundVideoSource(nil)[@"media"] count],@"An absent inline binding does not pick a globally recent video");
        Model *remembered=[Model new]; remembered.statusID=@"native-cached-current"; remembered.representedMediaEntities=@[Video(@"exact-cache-resource")]; BHRDRememberMedia(remembered);
        bound=BHRDResolveBoundVideoSource(@{@"statusID":@"native-cached-current"});
        Check([FirstURL(bound[@"media"]) containsString:@"exact-cache-resource"],@"A compact fullscreen model can reuse stamped native parameters for its exact bound post before details load");
        Check(![BHRDResolveBoundVideoSource(@{@"statusID":@"different-current"})[@"media"] count],@"A different bound post never adopts those cached native parameters");
        ((Media *)remembered.representedMediaEntities.firstObject).videoInfo=Video(@"recycled-cached-resource").videoInfo;
        Check(![BHRDResolveBoundVideoSource(@{@"statusID":@"native-cached-current"})[@"media"] count],@"Recycled cached entities cannot provide another video's parameters under an old post key");
        NSLog(@"PASS: %lu shared media-resolution checks", (unsigned long)checks);
    }
    return 0;
}
