#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "../BHRDFullscreenVideoResolver.h"
#import "../BHRDFullscreenContext.h"
#import "../BHRDMediaResolver.h"
@interface FixtureFullscreenHost : NSObject
@property(nonatomic,strong) UIView *viewIfLoaded;
@property(nonatomic,strong) id viewModel;
@end
@implementation FixtureFullscreenHost @end
@interface T1ImmersiveFullScreenViewController : FixtureFullscreenHost @end
@implementation T1ImmersiveFullScreenViewController @end
@interface NativeVideoSurface : UIView
@property(nonatomic,strong) id player;
@property(nonatomic,strong) id viewModel;
@end
@implementation NativeVideoSurface @end
@interface T1ImmersiveCardView : NativeVideoSurface @end
@implementation T1ImmersiveCardView @end
@interface NativeQuotedStatusView : UIView @end
@implementation NativeQuotedStatusView @end
static NSUInteger Checks;
static void Check(BOOL condition,NSString *message) { Checks++; if (!condition) { NSLog(@"FAIL: %@",message); exit(1); } }
static NSString *VideoURL(NSString *identifier) { return [NSString stringWithFormat:@"https://video.twimg.com/ext_tw_video/%@/pu/pl/current.m3u8",identifier]; }
static NSDictionary *Player(NSString *identifier) { return @{@"currentItem":@{@"asset":@{@"URL":VideoURL(identifier)}}}; }
static id NativeModel(NSString *identifier) { return @{@"statusID":identifier,@"currentMediaEntity":@{@"videoInfo":@{@"variants":@[@{@"url":VideoURL(identifier),@"contentType":@"application/x-mpegURL"}]}}}; }
static void Frame(UIView *view,CGRect rect) { view.frame=rect; view.bounds=CGRectMake(0,0,rect.size.width,rect.size.height); view.layer.frame=rect; view.layer.bounds=view.bounds; }
static void Attach(UIView *parent,UIView *child,CGRect rect) { Frame(child,rect); child.window=parent.window; [parent addSubview:child]; [parent.layer addSublayer:child.layer]; }
static T1ImmersiveFullScreenViewController *Host(void) {
    T1ImmersiveFullScreenViewController *host=[T1ImmersiveFullScreenViewController new];
    host.viewIfLoaded=[UIView new]; Frame(host.viewIfLoaded,CGRectMake(0,0,390,844)); host.viewIfLoaded.window=host.viewIfLoaded; return host;
}
static NSString *URL(NSDictionary *context) { return BHRDMediaObject([BHRDMediaObject(BHRDMediaObject([context[@"media"] firstObject],@"videoInfo"),@"variants") firstObject],@"url"); }
int main(void) { @autoreleasepool {
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
