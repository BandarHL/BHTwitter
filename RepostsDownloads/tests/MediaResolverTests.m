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
// The view-bound player in X 12.24.1 is not an AVPlayer and has no currentItem.
// These typed object getters model the runtime metadata exported from device.
@interface TAVQualityEndpoints : NSObject
@property(nonatomic, copy) NSURL *manifestURL;
@property(nonatomic, copy) NSArray *availableEndpoints;
@end
@implementation TAVQualityEndpoints @end
@interface TAVFoundationItem : NSObject
@property(nonatomic, strong) Item *avPlayerItem;
@property(nonatomic, strong) TAVQualityEndpoints *qualityEndpoints;
@property(nonatomic, strong) id resourceLoader;
@end
@implementation TAVFoundationItem @end
@interface TAVFoundationPlayerTechnology : NSObject
@property(nonatomic, strong) Player *avPlayer;
@property(nonatomic, strong) TAVFoundationItem *foundationItem;
@end
@implementation TAVFoundationPlayerTechnology @end
@interface TAVTechnologicalPlayerInternalItem : NSObject
@property(nonatomic, strong) TAVFoundationPlayerTechnology *tech;
@end
@implementation TAVTechnologicalPlayerInternalItem @end
@interface TAVTechnologicalPlayerInternalState : NSObject
@property(nonatomic, strong) TAVTechnologicalPlayerInternalItem *currentItem;
@end
@implementation TAVTechnologicalPlayerInternalState @end
@interface TAVPlayer : NSObject
@property(nonatomic, strong) TAVTechnologicalPlayerInternalState *internalState;
@property(nonatomic, strong) TAVQualityEndpoints *qualityEndpoints;
@end
@implementation TAVPlayer @end
@interface TAVVideoQualityEndpoint : NSObject
@property(nonatomic, copy) NSString *qualityType;
@property(nonatomic, copy) NSDictionary *resolution;
@end
@implementation TAVVideoQualityEndpoint @end
@interface TAVFoundationPlayerEndpointsManager : NSObject {
    NSURL *_manifestURL;
    NSURL *_cacheURL;
}
@property(nonatomic, copy) NSSet *availableEndpoints;
- (instancetype)initWithManifest:(NSURL *)manifest cache:(NSURL *)cache;
@end
@implementation TAVFoundationPlayerEndpointsManager
- (instancetype)initWithManifest:(NSURL *)manifest cache:(NSURL *)cache {
    if ((self = [super init])) { _manifestURL = [manifest copy]; _cacheURL = [cache copy]; }
    return self;
}
@end
@interface UnverifiedEndpointsManager : NSObject {
    NSURL *_manifestURL;
}
- (instancetype)initWithManifest:(NSURL *)manifest;
@end
@implementation UnverifiedEndpointsManager
- (instancetype)initWithManifest:(NSURL *)manifest {
    if ((self = [super init])) _manifestURL = [manifest copy];
    return self;
}
@end
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
        TAVPlayer *tav = [TAVPlayer new]; tav.internalState = [TAVTechnologicalPlayerInternalState new];
        tav.internalState.currentItem = [TAVTechnologicalPlayerInternalItem new];
        TAVFoundationPlayerTechnology *tech = [TAVFoundationPlayerTechnology new]; tav.internalState.currentItem.tech = tech;
        tech.avPlayer = [Player new]; tech.avPlayer.currentItem = [Item new]; tech.avPlayer.currentItem.asset = [Asset new];
        tech.avPlayer.currentItem.asset.URL = [NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/tav-before-comments/pu/pl/master.m3u8"];
        live = BHRDResolveLiveVideoSource(tav);
        Check(![tav respondsToSelector:@selector(currentItem)] && [live[@"media"] count] == 1 && [FirstURL(live[@"media"]) containsString:@"tav-before-comments"], @"TAVPlayer resolves its technological current item without an AVPlayer currentItem getter or comment hydration");
        Check([live[@"sourcePath"] isEqual:@"source.internalState.currentItem.tech.avPlayer.currentItem.asset.URL"], @"Successful TAV resolution reports the exact native getter chain");
        tech.foundationItem = [TAVFoundationItem new]; tech.foundationItem.avPlayerItem = tech.avPlayer.currentItem;
        tech.avPlayer = nil;
        live = BHRDResolveLiveVideoSource(tav);
        Check([live[@"media"] count] == 1 && [live[@"sourcePath"] containsString:@"foundationItem.avPlayerItem.asset.URL"], @"Foundation item exposes the current AVPlayerItem even before the technology AVPlayer is attached");
        tech.foundationItem.avPlayerItem.asset.URL = [NSURL URLWithString:@"tavfoundation://tav-before-comments/master"];
        TAVQualityEndpoints *qualities = [TAVQualityEndpoints new]; tech.foundationItem.qualityEndpoints = qualities;
        qualities.manifestURL = [NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/tav-before-comments/pu/pl/master.m3u8?token=current"];
        qualities.availableEndpoints = @[@{@"url":@"https://video.twimg.com/ext_tw_video/tav-before-comments/pu/vid/480x270/low.mp4", @"mimeType":@"video/mp4", @"bitrate":@256000},
            @{@"URL":@"https://video.twimg.com/ext_tw_video/tav-before-comments/pu/vid/1280x720/high.mp4", @"contentType":@"video/mp4", @"bitrate":@2000000}];
        live = BHRDResolveLiveVideoSource(tav);
        NSArray *tavVariants = BHRDMediaObject(BHRDMediaObject([live[@"media"] firstObject],@"videoInfo"),@"variants");
        Check([live[@"media"] count] == 1 && tavVariants.count == 3 && [live[@"endpointCount"] unsignedIntegerValue] == 3, @"A custom-scheme playing asset uses real item-owned manifest and every available native quality endpoint");
        Check([BHRDMediaObject(tavVariants[1],@"bitrate") isEqual:@256000], @"Observed endpoint bitrate survives normalization when natively object encoded");
        Check([live[@"sourcePath"] containsString:@"qualityEndpoints.manifestURL"] && [FirstURL(live[@"media"]) containsString:@"token=current"], @"Native manifest query is preserved rather than guessing or rewriting an asset URL");
        NSString *tavOldIdentity = live[@"identity"];
        tav.qualityEndpoints = qualities;
        tav.internalState.currentItem = [TAVTechnologicalPlayerInternalItem new];
        live = BHRDResolveLiveVideoSource(tav);
        Check(![live[@"media"] count] && [live[@"reason"] isEqual:@"current_item_resource_unavailable"], @"After swiping an unreadable new TAV item cannot borrow a retained parent quality endpoint");
        tav.internalState.currentItem = nil;
        Check(![BHRDResolveLiveVideoSource(tav)[@"media"] count], @"A declared nil TAV current item excludes old parent endpoints during transition");
        tav.internalState.currentItem = [TAVTechnologicalPlayerInternalItem new]; tav.internalState.currentItem.tech = [TAVFoundationPlayerTechnology new];
        tav.internalState.currentItem.tech.foundationItem = [TAVFoundationItem new];
        tav.internalState.currentItem.tech.foundationItem.qualityEndpoints = [TAVQualityEndpoints new];
        tav.internalState.currentItem.tech.foundationItem.qualityEndpoints.availableEndpoints = @[@{@"url":@"https://video.twimg.com/ext_tw_video/tav-new-item/pu/vid/720x1280/new.mp4"}];
        live = BHRDResolveLiveVideoSource(tav);
        Check([live[@"media"] count] == 1 && ![live[@"identity"] isEqual:tavOldIdentity] && [FirstURL(live[@"media"]) containsString:@"tav-new-item"], @"A newly bound TAV item resolves its own native endpoint without an asset URL and invalidates the old media identity");
        live = BHRDResolveLiveVideoSource(@{@"mainThreadState":@{@"currentItem":@{@"tech":@{@"foundationItem":@{@"resourceLoader":@{@"manifestURL":@"https://video.twimg.com/amplify_video/tav-loader/pl/master.m3u8"}}}}}});
        Check([live[@"media"] count] == 1 && [live[@"sourcePath"] containsString:@"mainThreadState.currentItem.tech.foundationItem.resourceLoader.manifestURL"], @"The main-thread state and currently bound native resource loader are supported");
        live = BHRDResolveLiveVideoSource(@{@"internalState":@{@"currentItem":@{@"tech":@{@"config":@{@"qualityEndpoints":@{@"availableEndpoints":@{@"low":@{@"URL":@"https://video.twimg.com/ext_tw_video/tav-map/pu/vid/320x568/low.mp4"},@"high":@{@"URL":@"https://video.twimg.com/ext_tw_video/tav-map/pu/vid/720x1280/high.mp4"}}}}}}}});
        Check([live[@"media"] count] == 1 && [live[@"endpointCount"] unsignedIntegerValue] == 2, @"An explicit availableEndpoints mapping retains all qualities of the current technological item's config");
        live = BHRDResolveLiveVideoSource(@{@"internalState":@{@"currentItem":@{@"tech":@{@"foundationItem":@{@"avPlayerItem":@{@"asset":@{@"URL":@"tavfoundation://opaque/current"}}, @"qualityEndpoints":@{@"manifestURL":@"https://foreign.example/not-x.m3u8"}}}}}});
        Check(![live[@"media"] count] && [live[@"reason"] isEqual:@"unsupported_current_asset"], @"Neither custom asset schemes nor non-X manifests are transformed into fabricated download URLs");
        live = BHRDResolveLiveVideoSource(@{@"currentItem":@{@"qualityEndpoints":@{@"availableEndpoints":@[@{@"url":@"https://video.twimg.com/ext_tw_video/tav-mime/pu/vid/720x1280/wrong.mp4",@"mimeType":@"image/jpeg"}]}}});
        Check(![live[@"media"] count], @"An endpoint declaring a non-video MIME type is not normalized as a video");
        live = BHRDResolveLiveVideoSource(@{@"internalState":@{@"currentItem":@{@"qualityEndpoints":@{@"availableEndpoints":@[@{@"url":@"https://video.twimg.com/ext_tw_video/tav-conflict-A/pu/pl/a.m3u8"},@{@"url":@"https://video.twimg.com/ext_tw_video/tav-conflict-B/pu/pl/b.m3u8"}]}}}});
        Check(![live[@"media"] count] && [live[@"reason"] isEqual:@"ambiguous_current_assets"], @"Contradictory endpoints within the current TAV item remain a real identity conflict");
        tech = tav.internalState.currentItem.tech;
        tech.avPlayer = [Player new]; tech.avPlayer.currentItem = [Item new]; tech.avPlayer.currentItem.asset = [Asset new];
        tech.avPlayer.currentItem.asset.URL = [NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/retained-shared-player/pu/pl/old.m3u8"];
        tech.foundationItem.avPlayerItem = [Item new]; tech.foundationItem.avPlayerItem.asset = [Asset new];
        tech.foundationItem.avPlayerItem.asset.URL = [NSURL URLWithString:@"tavfoundation://currently-bound-new-item"];
        live = BHRDResolveLiveVideoSource(tav);
        Check([FirstURL(live[@"media"]) containsString:@"tav-new-item"] && ![FirstURL(live[@"media"]) containsString:@"retained-shared-player"], @"A new technological item's Foundation endpoints override the shared AVPlayer's different retained old item");
        Check([live[@"excludedPlaybackBranches"] count] == 1 && [live[@"resourceProbePaths"] count] > 0, @"Reports record the excluded mismatched AVPlayer and safe getter paths without resource values");
        tech.foundationItem.qualityEndpoints = nil;
        live = BHRDResolveLiveVideoSource(tav);
        Check(![live[@"media"] count] && [live[@"reason"] isEqual:@"unsupported_current_asset"], @"An opaque new Foundation item cannot fall back to the shared AVPlayer's old resource if new endpoints are absent");
        tech.foundationItem.avPlayerItem.asset.URL = [NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/foundation-current/pu/pl/new.m3u8"];
        live = BHRDResolveLiveVideoSource(tav);
        Check([FirstURL(live[@"media"]) containsString:@"foundation-current"], @"When Foundation item and shared player disagree only the bound Foundation resource is read");
        tech.avPlayer.currentItem = tech.foundationItem.avPlayerItem;
        live = BHRDResolveLiveVideoSource(tav);
        Check([live[@"media"] count] == 1 && ![live[@"excludedPlaybackBranches"] count], @"An exactly matching Foundation and AVPlayer item safely keeps both compatible getter paths");
        live = BHRDResolveLiveVideoSource(@{@"internalState":@{@"currentItem":@{@"asset":@{@"URL":@"https://video.twimg.com/ext_tw_video/state-current/pu/pl/a.m3u8"}}}, @"mainThreadState":@{@"currentItem":@{@"asset":@{@"URL":@"https://video.twimg.com/ext_tw_video/state-old/pu/pl/b.m3u8"}}}});
        Check(![live[@"media"] count] && [live[@"reason"] isEqual:@"current_item_mismatch"], @"Different current items advertised by internal and main-thread states never get unioned as one playing video");
        tav.internalState = nil;
        Check(![BHRDResolveLiveVideoSource(tav)[@"media"] count], @"An unattached TAV state cannot borrow its retained parent quality endpoints");
        TAVFoundationPlayerEndpointsManager *manager = [[TAVFoundationPlayerEndpointsManager alloc] initWithManifest:[NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/ivar-manifest/pu/pl/master.m3u8?tag=23"] cache:[NSURL fileURLWithPath:@"/tmp/tav-cache"]];
        TAVVideoQualityEndpoint *quality = [TAVVideoQualityEndpoint new]; quality.qualityType = @"high"; quality.resolution = @{@"width":@1080,@"height":@1920};
        manager.availableEndpoints = [NSSet setWithObject:quality];
        Check(![manager respondsToSelector:NSSelectorFromString(@"manifestURL")], @"Device-shaped endpoint manager has no manifest property getter");
        NSDictionary *ivarBound = @{@"internalState":@{@"currentItem":@{@"tech":@{@"qualityEndpoints":manager, @"foundationItem":@{@"avPlayerItem":@{@"asset":@{@"URL":@"tavfoundation://manifest-managed/item"}}}}}}};
        live = BHRDResolveLiveVideoSource(ivarBound);
        Check([live[@"media"] count] == 1 && [FirstURL(live[@"media"]) containsString:@"ivar-manifest"], @"Current TAV technology reads its verified manager's object ivar manifest when AVAsset uses a custom scheme");
        Check([live[@"sourcePath"] isEqual:@"source.internalState.currentItem.tech.qualityEndpoints._manifestURL"] && [live[@"resourceAccess"] isEqual:@"object_ivar"], @"Read diagnostics distinguish the precise allowed manager ivar from ordinary object getters");
        Check([live[@"endpointCount"] unsignedIntegerValue] == 1, @"Resolution-only NSSet quality endpoints do not fabricate MP4 URLs or extra menu qualities");
        Check(![BHRDResolveLiveVideoSource(manager)[@"media"] count], @"An unbound manager manifest cannot authorize download outside a currently bound item");
        manager = [[TAVFoundationPlayerEndpointsManager alloc] initWithManifest:nil cache:[NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/cache-not-manifest/pu/pl/cache.m3u8"]];
        manager.availableEndpoints = [NSSet setWithObject:quality];
        live = BHRDResolveLiveVideoSource(@{@"currentItem":@{@"tech":@{@"qualityEndpoints":manager}}});
        Check(![live[@"media"] count], @"A resolution-only endpoint set and cache URL cannot substitute for a missing manifest");
        manager = [[TAVFoundationPlayerEndpointsManager alloc] initWithManifest:[NSURL fileURLWithPath:@"/tmp/manifest.m3u8"] cache:nil];
        live = BHRDResolveLiveVideoSource(@{@"currentItem":@{@"tech":@{@"qualityEndpoints":manager}}});
        Check(![live[@"media"] count] && [live[@"reason"] isEqual:@"unsupported_current_asset"], @"A file-scheme manifest ivar is rejected rather than handed to a remote downloader");
        UnverifiedEndpointsManager *unverified = [[UnverifiedEndpointsManager alloc] initWithManifest:[NSURL URLWithString:@"https://video.twimg.com/ext_tw_video/unverified/pu/pl/master.m3u8"]];
        Check(![BHRDResolveLiveVideoSource(@{@"currentItem":@{@"tech":@{@"qualityEndpoints":unverified}}})[@"media"] count], @"An identically named manifest ivar on an unverified private class is never inspected");
        NSLog(@"PASS: %lu shared media-resolution checks", (unsigned long)checks);
    }
    return 0;
}
