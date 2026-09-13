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
        NSLog(@"PASS: %lu shared media-resolution checks", (unsigned long)checks);
    }
    return 0;
}
