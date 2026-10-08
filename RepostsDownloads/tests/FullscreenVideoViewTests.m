#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "../BHRDFullscreenVideoResolver.h"
#import "../BHRDFullscreenContext.h"
#import "../BHRDMediaResolver.h"
#import "../BHRDFullscreenVideoPresence.h"
#import "../BHRDFullscreenVisibility.h"
@interface FixtureFullscreenHost : NSObject
@property(nonatomic,strong) UIView *viewIfLoaded;
@property(nonatomic,strong) id viewModel;
@end
@implementation FixtureFullscreenHost @end
@interface T1ImmersiveFullScreenViewController : FixtureFullscreenHost @end
@implementation T1ImmersiveFullScreenViewController @end
@interface NativeVideoSurface : UIView
@property(nonatomic,strong) id player;
@property(nonatomic,strong) id currentPlayer;
@property(nonatomic,strong) id viewModel;
@end
@implementation NativeVideoSurface @end
@interface TAVPlayer : NSObject
@property(nonatomic,strong) id internalState;
@property(nonatomic,strong) id mainThreadState;
@end
@implementation TAVPlayer @end
@interface TAVFoundationPlayerEndpointsManager : NSObject {
    NSURL *_manifestURL;
}
@property(nonatomic,strong) NSSet *availableEndpoints;
- (instancetype)initWithManifest:(NSURL *)manifest;
@end
@implementation TAVFoundationPlayerEndpointsManager
- (instancetype)initWithManifest:(NSURL *)manifest {
    if ((self=[super init])) { _manifestURL=manifest; _availableEndpoints=[NSSet setWithObjects:@{@"resolution":@"720x1280"},@{@"resolution":@"1080x1920"},nil]; }
    return self;
}
@end
@interface T1ImmersiveCardView : NativeVideoSurface @end
@implementation T1ImmersiveCardView @end
@interface T1StatusInlineActionsView : UIView
@property(nonatomic,strong) id viewModel;
@property(nonatomic,strong) id delegate;
@end
@implementation T1StatusInlineActionsView @end
@interface T1SlideshowStatusView : UIView
@property(nonatomic,strong) id media;
@end
@implementation T1SlideshowStatusView @end
@interface _TtC14T1TwitterSwift17ImmersiveCardView : UIView
@property(nonatomic,strong) id status;
@end
@implementation _TtC14T1TwitterSwift17ImmersiveCardView @end
@interface NativeQuotedStatusView : UIView @end
@implementation NativeQuotedStatusView @end
static NSUInteger Checks;
static void Check(BOOL condition,NSString *message) { Checks++; if (!condition) { NSLog(@"FAIL: %@",message); exit(1); } }
static NSString *VideoURL(NSString *identifier) { return [NSString stringWithFormat:@"https://video.twimg.com/ext_tw_video/%@/pu/pl/current.m3u8",identifier]; }
static NSDictionary *Player(NSString *identifier) { return @{@"currentItem":@{@"asset":@{@"URL":VideoURL(identifier)}}}; }
static id NativeModel(NSString *identifier) { return @{@"statusID":identifier,@"currentMediaEntity":@{@"videoInfo":@{@"variants":@[@{@"url":VideoURL(identifier),@"contentType":@"application/x-mpegURL"}]}}}; }
static id SwiftStatus(NSString *post,NSString *asset) {
    return @{@"statusID":post,@"representedMediaEntities":@[@{@"videoInfo":@{@"variants":@[
        @{@"url":VideoURL(asset),@"contentType":@"application/x-mpegURL"},
        @{@"url":[NSString stringWithFormat:@"https://video.twimg.com/ext_tw_video/%@/vid/320x180/a.mp4",asset],@"contentType":@"video/mp4"},
        @{@"url":[NSString stringWithFormat:@"https://video.twimg.com/ext_tw_video/%@/vid/720x1280/b.mp4",asset],@"contentType":@"video/mp4"}]} }]};
}
static id TAVItem(NSString *identifier) {
    return @{@"tech":@{@"foundationItem":@{@"avPlayerItem":@{@"asset":@{@"URL":VideoURL(identifier)}}}}};
}
static void Frame(UIView *view,CGRect rect) { view.frame=rect; view.bounds=CGRectMake(0,0,rect.size.width,rect.size.height); view.layer.frame=rect; view.layer.bounds=view.bounds; }
static void Attach(UIView *parent,UIView *child,CGRect rect) { Frame(child,rect); child.window=parent.window; [parent addSubview:child]; [parent.layer addSublayer:child.layer]; }
static T1ImmersiveFullScreenViewController *Host(void) {
    T1ImmersiveFullScreenViewController *host=[T1ImmersiveFullScreenViewController new];
    host.viewIfLoaded=[UIView new]; Frame(host.viewIfLoaded,CGRectMake(0,0,390,844)); host.viewIfLoaded.window=host.viewIfLoaded; return host;
}
static NSString *URL(NSDictionary *context) { return BHRDMediaObject([BHRDMediaObject(BHRDMediaObject([context[@"media"] firstObject],@"videoInfo"),@"variants") firstObject],@"url"); }
int main(void) { @autoreleasepool {
    T1ImmersiveFullScreenViewController *swiftHost=Host();
    _TtC14T1TwitterSwift17ImmersiveCardView *swiftA=[_TtC14T1TwitterSwift17ImmersiveCardView new],*swiftB=[_TtC14T1TwitterSwift17ImmersiveCardView new];
    Attach(swiftHost.viewIfLoaded,swiftA,swiftHost.viewIfLoaded.bounds); Attach(swiftHost.viewIfLoaded,swiftB,CGRectMake(0,844,390,844));
    NativeVideoSurface *swiftPlayerA=[NativeVideoSurface new],*swiftPlayerB=[NativeVideoSurface new];
    swiftPlayerA.player=Player(@"swift-first"); swiftPlayerB.player=Player(@"swift-second");
    Attach(swiftA,swiftPlayerA,CGRectMake(0,140,390,480)); Attach(swiftB,swiftPlayerB,CGRectMake(0,140,390,480));
    swiftA.status=SwiftStatus(@"swift-post-one",@"swift-first"); swiftB.status=SwiftStatus(@"swift-post-two",@"swift-second");
    NSDictionary *swiftContext=BHRDCurrentFullscreenVideoContext(swiftHost);
    Check([swiftContext[@"sourcePath"] isEqual:@"current_card.status"] && [BHRDMediaObject(BHRDMediaObject([swiftContext[@"media"] firstObject],@"videoInfo"),@"variants") count]==3,@"Swift immersive status supplies all native MP4 qualities instead of only the current HLS URL");
    Frame(swiftA,CGRectMake(0,-844,390,844)); Frame(swiftB,swiftHost.viewIfLoaded.bounds); swiftContext=BHRDCurrentFullscreenVideoContext(swiftHost);
    Check([swiftContext[@"sourcePath"] isEqual:@"current_card.status"] && [URL(swiftContext) containsString:@"swift-second"],@"Swiping to the second Swift card reads its own status without comment hydration or inline controls");
    Check([BHRDMediaObject(BHRDMediaObject([swiftContext[@"media"] firstObject],@"videoInfo"),@"variants") count]==3,@"Later cards retain the same complete native quality list as the first card");
    swiftB.status=SwiftStatus(@"swift-old",@"swift-first"); swiftContext=BHRDCurrentFullscreenVideoContext(swiftHost);
    Check([URL(swiftContext) containsString:@"swift-second"] && ![swiftContext[@"sourcePath"] isEqual:@"current_card.status"],@"A recycled old Swift status cannot replace the newly playing video's URI");
    swiftPlayerB.player=@{@"currentItem":@{}};
    Check(![BHRDCurrentFullscreenVideoContext(swiftHost)[@"media"] count],@"A Swift post still needs its playing identity confirmed before old native qualities can be used");
    T1ImmersiveFullScreenViewController *opaqueHost=Host();
    NativeVideoSurface *opaque=[NativeVideoSurface new]; opaque.player=@{@"currentItem":@{}};
    Attach(opaqueHost.viewIfLoaded,opaque,CGRectMake(0,180,390,330));
    Check(BHRDHasVisibleFullscreenVideo(opaqueHost),@"A playing/loading surface is video evidence even when no downloadable URL exists");
    BHRDFullscreenVisibility *visibility=[BHRDFullscreenVisibility new]; [visibility didAppear]; [visibility observeVideoPresence:BHRDHasVisibleFullscreenVideo(opaqueHost)];
    Check([visibility shouldDisplayEnabled:YES attached:YES] && ![BHRDCurrentFullscreenVideoContext(opaqueHost)[@"media"] count],@"Resource discovery failure cannot remove the independent download entry");
    opaque.hidden=YES; [visibility observeVideoPresence:BHRDHasVisibleFullscreenVideo(opaqueHost)];
    Check([visibility shouldDisplayEnabled:YES attached:YES],@"Fading playback chrome or a temporarily missing surface retains the established entry"); opaque.hidden=NO;
    [visibility observePhotoPresence]; Check(![visibility shouldDisplayEnabled:YES attached:YES],@"An explicitly displayed photo clears video-only visibility");
    [visibility observeVideoPresence:YES]; [visibility didDisappear]; Check(![visibility shouldDisplayEnabled:YES attached:YES],@"Late player evidence cannot restore a departed entry");
    T1StatusInlineActionsView *actions=[T1StatusInlineActionsView new];
    actions.viewModel=@{@"statusID":@"inline-post",@"representedMediaEntities":@[NativeModel(@"video-one")[@"currentMediaEntity"],NativeModel(@"video-two")[@"currentMediaEntity"]]};
    Attach(opaqueHost.viewIfLoaded,actions,CGRectMake(0,730,390,64));
    NSDictionary *bridged=BHRDCurrentFullscreenVideoContext(opaqueHost);
    Check([bridged[@"media"] count]==2 && [bridged[@"reason"] isEqual:@"resolved_inline_model"],@"Current native actions provide the same grouped video parameters despite an opaque player");
    NSString *boundIdentity=bridged[@"identity"];
    Check([BHRDCurrentFullscreenVideoContext(opaqueHost)[@"identity"] isEqual:boundIdentity],@"A native menu remains bound to the same current item and post");
    actions.viewModel=NativeModel(@"new-post-video");
    Check(![BHRDCurrentFullscreenVideoContext(opaqueHost)[@"resourceIdentity"] isEqual:bridged[@"resourceIdentity"]],@"Rebinding the current actions cannot retain another post's parameter list");
    actions.hidden=YES; Check(![BHRDCurrentFullscreenVideoContext(opaqueHost)[@"media"] count],@"Hidden actions cannot rescue an opaque surface with stale native metadata"); actions.hidden=NO;
    Frame(actions,CGRectMake(0,930,390,64)); Check(![BHRDCurrentFullscreenVideoContext(opaqueHost)[@"media"] count],@"Offscreen actions cannot supply the fullscreen parameters"); Frame(actions,CGRectMake(0,730,390,64));
    actions.viewModel=nil; actions.delegate=@{@"viewModel":NativeModel(@"delegate-current")};
    Check([URL(BHRDCurrentFullscreenVideoContext(opaqueHost)) containsString:@"delegate-current"],@"The native actions adapter's own view model works like the inline download button");
    BHRDRegisterFullscreenInlineModel(actions,NativeModel(@"registered-old")); actions.delegate=nil;
    Check(![BHRDCurrentFullscreenVideoContext(opaqueHost)[@"media"] count],@"A live getter cleared during reuse invalidates any captured previous model");
    opaque.player=Player(@"real-live"); actions.viewModel=NativeModel(@"different-native");
    Check([URL(BHRDCurrentFullscreenVideoContext(opaqueHost)) containsString:@"real-live"],@"A stale native parameter list cannot block the independently verified playing resource");
    T1ImmersiveFullScreenViewController *entityHost=Host(); T1SlideshowStatusView *mediaPage=[T1SlideshowStatusView new];
    mediaPage.media=NativeModel(@"direct-current-media")[@"currentMediaEntity"]; Attach(entityHost.viewIfLoaded,mediaPage,entityHost.viewIfLoaded.bounds);
    NativeVideoSurface *opaqueChild=[NativeVideoSurface new]; opaqueChild.player=@{@"currentItem":@{}}; Attach(mediaPage,opaqueChild,CGRectMake(0,180,390,330));
    Check([URL(BHRDCurrentFullscreenVideoContext(entityHost)) containsString:@"direct-current-media"],@"The currently displayed slideshow media works without post details or a public asset URL");
    Check(BHRDHasVisibleFullscreenVideo(entityHost),@"The current native media marks a video before its download model is hydrated");
    mediaPage.media=@{@"type":@"photo",@"mediaURL":@"https://pbs.twimg.com/media/current-photo.jpg"};
    Check(!BHRDHasVisibleFullscreenVideo(entityHost),@"A current photo in a recycled slideshow excludes its retained old player subtree");
    Check(BHRDHasSelectedFullscreenPhoto(entityHost),@"Explicit photo selection clears sticky video visibility even before the image has loaded");
    T1ImmersiveFullScreenViewController *host=Host(); UIView *root=host.viewIfLoaded;
    NativeVideoSurface *surface=[NativeVideoSurface new]; surface.player=Player(@"900001"); Attach(root,surface,CGRectMake(0,200,390,260));
    NSDictionary *context=BHRDCurrentFullscreenVideoContext(host);
    Check([context[@"media"] count]==1 && [URL(context) containsString:@"900001"],@"The visible playing URL downloads before a comment/detail model exists");
    Check([context[@"identity"] hasPrefix:@"item:"] && [context[@"playerCount"] isEqual:@1],@"Selection is tied to the actual current player item");
    NSString *first=context[@"identity"]; Check([BHRDCurrentFullscreenVideoContext(host)[@"identity"] isEqual:first],@"Repeated reads keep the same live item token");
    surface.player=Player(@"900002"); context=BHRDCurrentFullscreenVideoContext(host);
    Check([URL(context) containsString:@"900002"] && ![context[@"identity"] isEqual:first],@"Reusing a video surface with a new item never returns the previous resource");
    host.viewModel=NativeModel(@"900099"); surface.viewModel=NativeModel(@"900099");
    Check([URL(BHRDCurrentFullscreenVideoContext(host)) containsString:@"900002"],@"A stale hydrated controller/view model cannot override current playback");
    NSMutableDictionary *pendingItem=[NSMutableDictionary dictionary]; surface.player=@{@"currentItem":pendingItem};
    context=BHRDCurrentFullscreenVideoContext(host); first=context[@"identity"];
    Check([context[@"media"] count]==0 && first.length>0,@"An unreadable current item rejects old model data but keeps a stable retry token");
    pendingItem[@"asset"]=@{@"URL":VideoURL(@"900003")}; context=BHRDCurrentFullscreenVideoContext(host);
    Check([URL(context) containsString:@"900003"] && [context[@"identity"] isEqual:first],@"Loading the same selected item may complete without visiting comments");
    surface.hidden=YES; Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"Hidden view players are excluded even when their layer itself is not hidden"); surface.hidden=NO;
    surface.alpha=0; Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"Transparent view players are excluded"); surface.alpha=1;
    Frame(surface,CGRectMake(0,900,390,260)); Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"An offscreen playing view cannot supply media");
    Frame(surface,CGRectMake(0,200,390,260)); root.window=nil; Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"A detached fullscreen root rejects playback"); root.window=root;
    FixtureFullscreenHost *ordinary=[FixtureFullscreenHost new]; ordinary.viewIfLoaded=root; Check([BHRDCurrentFullscreenVideoContext(ordinary)[@"media"] count]==0,@"A normal attached screen is not inferred fullscreen merely because it has a player");
    BHRDRegisterFullscreenMediaSource(ordinary,surface); Check([URL(BHRDCurrentFullscreenVideoContext(ordinary)) containsString:@"900003"],@"An attached native fullscreen source verifies an unnamed controller");
    [surface removeFromSuperview]; [surface.layer removeFromSuperlayer]; Check([BHRDCurrentFullscreenVideoContext(ordinary)[@"media"] count]==0,@"A reparented registered source does not keep its old host verified");

    host=Host(); root=host.viewIfLoaded;
    T1ImmersiveCardView *current=[T1ImmersiveCardView new],*next=[T1ImmersiveCardView new];
    Attach(root,current,CGRectMake(0,0,390,844)); Attach(root,next,CGRectMake(0,744,390,844));
    NativeVideoSurface *playing=[NativeVideoSurface new],*adjacent=[NativeVideoSurface new]; playing.player=Player(@"910001"); adjacent.player=Player(@"910002");
    Attach(current,playing,CGRectMake(0,0,390,844)); Attach(next,adjacent,CGRectMake(0,0,390,844));
    Check([URL(BHRDCurrentFullscreenVideoContext(host)) containsString:@"910001"],@"A partially visible adjacent full-height page is not the current video");
    Frame(current,CGRectMake(0,-844,390,844)); Frame(next,CGRectMake(0,0,390,844));
    Check([URL(BHRDCurrentFullscreenVideoContext(host)) containsString:@"910002"],@"After swiping the centered page supplies its fresh playback resource");
    Frame(current,CGRectMake(0,-422,390,844)); Frame(next,CGRectMake(0,422,390,844)); context=BHRDCurrentFullscreenVideoContext(host);
    Check([context[@"media"] count]==0 && [context[@"reason"] isEqual:@"pager_transition_unsettled"],@"A half-swiped pager with two possible current resources fails safely");
    Frame(current,CGRectMake(0,0,390,844)); Frame(next,CGRectMake(0,844,390,844)); current.hidden=YES;
    Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"A hidden page cannot leak a child player through the root layer traversal"); current.hidden=NO;

    host=Host(); root=host.viewIfLoaded; UIView *clip=[UIView new]; clip.clipsToBounds=YES; Attach(root,clip,CGRectMake(0,0,390,80));
    surface=[NativeVideoSurface new]; surface.player=Player(@"920001"); Attach(clip,surface,CGRectMake(0,100,390,260));
    Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"Ancestor clipping excludes a video outside its container");
    clip.clipsToBounds=NO; Check([URL(BHRDCurrentFullscreenVideoContext(host)) containsString:@"920001"],@"Unclipped wrappers allow actually visible media descendants");
    clip.hidden=YES; Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"Hidden ancestors exclude private player getter sources");
    NativeQuotedStatusView *quoted=[NativeQuotedStatusView new]; Attach(root,quoted,root.bounds); NativeVideoSurface *quoteVideo=[NativeVideoSurface new]; quoteVideo.player=Player(@"920099"); Attach(quoted,quoteVideo,root.bounds);
    Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"Quoted/chrome video is not promoted to the main fullscreen download"); quoted.hidden=YES;
    NativeVideoSurface *one=[NativeVideoSurface new],*two=[NativeVideoSurface new]; one.player=Player(@"930001"); two.player=Player(@"930002"); Attach(root,one,CGRectMake(0,100,390,400)); Attach(root,two,CGRectMake(0,300,390,200));
    context=BHRDCurrentFullscreenVideoContext(host); Check([context[@"media"] count]==0 && [context[@"reason"] isEqual:@"conflicting_visible_resources"],@"Two visible different players are rejected instead of choosing the largest");
    two.player=Player(@"930001"); Check([URL(BHRDCurrentFullscreenVideoContext(host)) containsString:@"930001"],@"Duplicate native surfaces for one resource do not create a different-video conflict");

    host=Host(); root=host.viewIfLoaded; surface=[NativeVideoSurface new]; Attach(root,surface,CGRectMake(0,180,390,330));
    TAVPlayer *tav=[TAVPlayer new]; tav.internalState=@{@"currentItem":TAVItem(@"tav-current")}; surface.player=tav;
    context=BHRDCurrentFullscreenVideoContext(host); first=context[@"identity"];
    Check([URL(context) containsString:@"tav-current"] && [first hasPrefix:@"item:"],@"A TAV internal current item exposes a download before loading comments");
    Check([context[@"sourcePath"] containsString:@"internalState.currentItem.tech.foundationItem.avPlayerItem.asset.URL"],@"TAV diagnostics preserve the observed current resource chain without exporting its URL");
    Check([BHRDCurrentFullscreenVideoContext(host)[@"identity"] isEqual:first],@"Repeated TAV reads preserve the logical current item token");
    tav.internalState=@{@"currentItem":TAVItem(@"tav-current")}; context=BHRDCurrentFullscreenVideoContext(host);
    Check([URL(context) containsString:@"tav-current"] && ![context[@"identity"] isEqual:first],@"Replacing a TAV logical item invalidates its menu even when the asset URL is identical");
    NSMutableDictionary *loadingTAVItem=[NSMutableDictionary dictionary]; tav.internalState=@{@"currentItem":loadingTAVItem};
    context=BHRDCurrentFullscreenVideoContext(host); first=context[@"identity"];
    Check(![context[@"media"] count] && [first hasPrefix:@"item:"],@"An unreadable new TAV item has a stable retry token and cannot reuse a prior item");
    loadingTAVItem[@"tech"]=TAVItem(@"tav-loaded")[@"tech"]; context=BHRDCurrentFullscreenVideoContext(host);
    Check([URL(context) containsString:@"tav-loaded"] && [context[@"identity"] isEqual:first],@"The same TAV logical item may hydrate its resource while its download attempt waits");
    tav.mainThreadState=@{@"currentItem":TAVItem(@"tav-main-current")}; context=BHRDCurrentFullscreenVideoContext(host);
    Check(![context[@"media"] count] && [context[@"reason"] isEqual:@"current_item_mismatch"],@"Contradictory internal and main-thread TAV items reject playback rather than downloading a retained resource");
    tav.internalState=nil; context=BHRDCurrentFullscreenVideoContext(host);
    Check([URL(context) containsString:@"tav-main-current"],@"A published main-thread TAV item supplies the current resource when no conflicting internal item exists");
    tav.mainThreadState=nil;
    TAVFoundationPlayerEndpointsManager *endpointManager=[[TAVFoundationPlayerEndpointsManager alloc] initWithManifest:[NSURL URLWithString:VideoURL(@"tav-real-manifest")]];
    tav.internalState=@{@"currentItem":@{@"tech":@{@"foundationItem":@{@"avPlayerItem":@{@"asset":@{@"URL":@"tav-resource://current/item"}}},@"qualityEndpoints":endpointManager}}};
    context=BHRDCurrentFullscreenVideoContext(host);
    Check([URL(context) containsString:@"tav-real-manifest"] && [context[@"resourceAccess"] isEqual:@"object_ivar"],@"A fullscreen TAV custom asset URL is resolved using the current item's verified manifest ivar");
    Check([context[@"sourcePath"] hasSuffix:@"tech.qualityEndpoints._manifestURL"] && [context[@"resourceProbePaths"] count]>1,@"The next exported probe identifies the item-owned manifest access and inspected object chain");
    Check([BHRDMediaObject(BHRDMediaObject([context[@"media"] firstObject],@"videoInfo"),@"variants") count]==1,@"Resolution-only NSSet endpoints cannot fabricate fullscreen quality download URLs");

    // Both enumeration orders must inspect the readable candidate. A nil-item
    // outer wrapper on the same surface is different from an opaque selected
    // item, which may be replacing the visible AV player's previous video.
    TAVPlayer *unboundTAV=[TAVPlayer new]; id readableAV=Player(@"order-current");
    surface.player=unboundTAV; surface.currentPlayer=readableAV;
    NSDictionary *wrapperFirst=BHRDCurrentFullscreenVideoContext(host); first=wrapperFirst[@"identity"];
    Check([URL(wrapperFirst) containsString:@"order-current"] && [wrapperFirst[@"resolvedPlayerCount"] isEqual:@1] && [wrapperFirst[@"unresolvedPlayerCount"] isEqual:@1],@"An unreadable nil-item TAV wrapper does not poison a readable player on the same current surface");
    surface.player=readableAV; surface.currentPlayer=unboundTAV; context=BHRDCurrentFullscreenVideoContext(host);
    Check([URL(context) containsString:@"order-current"] && [context[@"identity"] isEqual:first],@"Swapping candidate enumeration order retains the same current download selection");
    Check([context[@"candidateResults"] count]==2 && [context[@"unresolvedReasons"] count]==1,@"Diagnostics record every resolved and unreadable candidate instead of returning at the first failure");
    BOOL safeFields=YES; NSSet *diagnosticKeys=[NSSet setWithArray:@[@"kind",@"sourceClass",@"reason",@"stage",@"sourcePath",@"currentItemPresent",@"resolved",@"resourceAccess",@"endpointCount"]];
    for (NSDictionary *candidate in context[@"candidateResults"]) if (![[NSSet setWithArray:candidate.allKeys] isEqual:diagnosticKeys]) safeFields=NO;
    Check(safeFields,@"Candidate diagnostics contain only fixed classes and stages, with no URL, account, or post identity");
    unboundTAV.internalState=@{@"currentItem":[NSMutableDictionary dictionary]}; context=BHRDCurrentFullscreenVideoContext(host);
    Check(![context[@"media"] count] && [context[@"reason"] isEqual:@"ambiguous_visible_player_selection"],@"An opaque new TAV item cannot borrow a readable older AV player even on the same surface");
    first=context[@"identity"]; surface.player=unboundTAV; surface.currentPlayer=readableAV; context=BHRDCurrentFullscreenVideoContext(host);
    Check(![context[@"media"] count] && [context[@"identity"] isEqual:first],@"A genuine opaque-item conflict remains unsafe in both candidate orders");
    unboundTAV.internalState=@{@"currentItem":[NSMutableDictionary dictionary]};
    Check(![BHRDCurrentFullscreenVideoContext(host)[@"identity"] isEqual:first],@"Replacing the unreadable TAV item cancels a pending attempt despite the retained readable AV item");
    unboundTAV.internalState=nil; surface.currentPlayer=nil; surface.player=readableAV;
    NativeVideoSurface *independent=[NativeVideoSurface new]; independent.player=unboundTAV; Attach(root,independent,surface.frame);
    context=BHRDCurrentFullscreenVideoContext(host);
    Check(![context[@"media"] count] && [context[@"reason"] isEqual:@"ambiguous_visible_player_selection"],@"Matching viewport geometry alone does not merge independent opaque and known video surfaces");
    independent.hidden=YES;
    Check([URL(BHRDCurrentFullscreenVideoContext(host)) containsString:@"order-current"],@"Hiding the unrelated opaque surface permits the still visible current player");

    surface.player=@{@"currentItem":@{}}; surface.currentPlayer=unboundTAV; context=BHRDCurrentFullscreenVideoContext(host);
    NSString *unavailableReason=context[@"reason"],*unavailableToken=context[@"identity"];
    Check(![context[@"media"] count] && [context[@"resolvedPlayerCount"] isEqual:@0] && [context[@"unresolvedPlayerCount"] isEqual:@2],@"When all current players are unreadable the result exposes their failure counts");
    id emptyAV=surface.player; surface.player=unboundTAV; surface.currentPlayer=emptyAV; context=BHRDCurrentFullscreenVideoContext(host);
    Check([context[@"reason"] isEqual:unavailableReason] && [context[@"identity"] isEqual:unavailableToken],@"All-unreadable diagnostics and retry identity are independent of candidate enumeration order");

    host=Host(); root=host.viewIfLoaded; T1ImmersiveCardView *native=[T1ImmersiveCardView new]; native.viewModel=NativeModel(@"940001"); Attach(root,native,root.bounds);
    Check([URL(BHRDCurrentFullscreenVideoContext(host)) containsString:@"940001"],@"A visible bound current-media model works when no AVPlayerLayer is exposed");
    native.viewModel=NativeModel(@"940002"); Check([URL(BHRDCurrentFullscreenVideoContext(host)) containsString:@"940002"],@"A recycled native card resolves new metadata without a retained old model");
    NativeVideoSurface *unresolvedSurface=[NativeVideoSurface new]; Attach(native,unresolvedSurface,CGRectMake(0,100,390,400));
    context=BHRDCurrentFullscreenVideoContext(host);
    Check([context[@"media"] count]==0 && [context[@"sourceClass"] isEqual:@"NativeVideoSurface"],@"An unresolved specific playback surface cannot borrow its parent card's retained old post metadata");
    [unresolvedSurface removeFromSuperview]; [unresolvedSurface.layer removeFromSuperlayer];
    native.viewModel=@{@"statusID":@"940003"}; context=BHRDCurrentFullscreenVideoContext(host); first=context[@"identity"];
    Check([context[@"media"] count]==0 && first.length>0,@"One visible identified card may await current media without accepting old cached resources");
    native.viewModel=NativeModel(@"940003"); context=BHRDCurrentFullscreenVideoContext(host);
    Check([URL(context) containsString:@"940003"] && [context[@"identity"] isEqual:first],@"The same visible status may hydrate native qualities with a stable retry token");
    native.viewModel=nil; context=BHRDCurrentFullscreenVideoContext(host);
    Check([context[@"media"] count]==0,@"Removing a card model does not resurrect last known media");
    Check([context[@"observedViewClasses"] containsObject:@"T1ImmersiveCardView"] && [context[@"examinedViewCount"] unsignedIntegerValue]>=2 && ![context[@"scanTruncated"] boolValue],@"Failure metadata identifies observed wrappers without account or media contents");
    native.hidden=YES;
    AVPlayer *av=[AVPlayer playerWithPlayerItem:[AVPlayerItem playerItemWithURL:[NSURL URLWithString:VideoURL(@"950001")]]];
    AVPlayerLayer *layer=[AVPlayerLayer playerLayerWithPlayer:av]; layer.frame=CGRectMake(0,100,390,500); [root.layer addSublayer:layer];
    Check([URL(BHRDCurrentFullscreenVideoContext(host)) containsString:@"950001"],@"An actual AVPlayerLayer exposes the live URL with no native post hydration");
    layer.hidden=YES; Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"Hidden native player layers are excluded"); layer.hidden=NO; layer.opacity=0;
    Check([BHRDCurrentFullscreenVideoContext(host)[@"media"] count]==0,@"Transparent native player layers are excluded");
    for (NSUInteger index=0;index<705;index++) Attach(root,[UIView new],CGRectMake(0,0,1,1));
    context=BHRDCurrentFullscreenVideoContext(host);
    Check([context[@"media"] count]==0 && [context[@"scanTruncated"] boolValue] && [context[@"reason"] isEqual:@"source_scan_budget_exceeded"],@"A truncated hierarchy scan refuses an incompletely observed selection");
    __block NSDictionary *background; dispatch_semaphore_t done=dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ background=BHRDCurrentFullscreenVideoContext(host); dispatch_semaphore_signal(done); });
    dispatch_semaphore_wait(done,DISPATCH_TIME_FOREVER);
    Check([background[@"media"] count]==0 && [background[@"reason"] isEqual:@"fullscreen_scan_requires_main_thread"],@"A background callback cannot read UIKit hierarchy or modify selection state");
    NSLog(@"PASS: %lu production fullscreen video-source view checks",(unsigned long)Checks);
} return 0; }
