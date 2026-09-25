#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "../BHRDFullscreenPhotoResolver.h"
#import "../BHRDFullscreenContext.h"
@interface PhotoImageView : UIImageView
@property(nonatomic,strong) NSURL *imageURL;
@end
@implementation PhotoImageView @end
@interface NativeAsyncImageNode : NSObject
@property(nonatomic,strong) UIImage *image;
@property(nonatomic,strong) NSURL *imageURL;
@end
@implementation NativeAsyncImageNode @end
@interface NativeNodeView : UIView
@property(nonatomic,strong) NativeAsyncImageNode *asyncdisplaykit_node;
@end
@implementation NativeNodeView @end
@interface T1SlideshowStatusView : UIView @end
@implementation T1SlideshowStatusView @end
@interface T1StatusInlineActionsView : UIView @end
@implementation T1StatusInlineActionsView @end
@interface T1QuotedStatusView : UIView @end
@implementation T1QuotedStatusView @end
@interface PhotoFixtureController : NSObject
@property(nonatomic,strong) UIView *viewIfLoaded;
@end
@implementation PhotoFixtureController @end
@interface T1ImmersiveFullScreenViewController : PhotoFixtureController @end
@implementation T1ImmersiveFullScreenViewController @end
@interface NewNativePhotoContainer : T1ImmersiveFullScreenViewController @end
@implementation NewNativePhotoContainer @end
@interface T1ImmersiveViewController : PhotoFixtureController @end
@implementation T1ImmersiveViewController @end
static NSUInteger checks;
static void Check(BOOL ok, NSString *message) { checks++; if (!ok) { NSLog(@"FAIL: %@",message); exit(1); } }
static PhotoImageView *Photo(UIView *root,CGFloat x,NSString *name) {
    PhotoImageView *view=[PhotoImageView new]; view.frame=CGRectMake(x,0,390,844); view.bounds=CGRectMake(0,0,390,844);
    view.image=[UIImage new]; view.imageURL=[NSURL URLWithString:[NSString stringWithFormat:@"https://pbs.twimg.com/media/%@?format=jpg&name=small",name]];
    [root addSubview:view]; return view;
}
int main(void) { @autoreleasepool {
    UIView *root=[UIView new]; root.frame=CGRectMake(0,0,390,844); root.bounds=root.frame; root.window=root;
    PhotoImageView *current=Photo(root,0,@"current"),*next=Photo(root,390,@"next");
    Check([BHRDCurrentFullscreenPhoto(root).url.absoluteString containsString:@"/current?"],@"Only centered pager image is selected");
    Check([BHRDCurrentFullscreenPhoto(root).url.absoluteString containsString:@"name=orig"],@"Resolver returns current original URL");
    current.frame=CGRectMake(-390,0,390,844); next.frame=CGRectMake(0,0,390,844);
    Check([BHRDCurrentFullscreenPhoto(root).url.absoluteString containsString:@"/next?"],@"Recycled pager resolves newly centered image");
    next.hidden=YES; Check(!BHRDCurrentFullscreenPhoto(root),@"Hidden/offscreen images are excluded"); next.hidden=NO;
    next.imageURL=[NSURL URLWithString:@"https://pbs.twimg.com/ext_tw_video_thumb/1/pu/img/poster.jpg"];
    Check(!BHRDCurrentFullscreenPhoto(root),@"Video poster is excluded even before a player item is attached");
    next.imageURL=nil; Check(BHRDCurrentFullscreenPhoto(root).image==next.image,@"Loaded bitmap remains available without a native URL getter");
    NSString *identity=BHRDCurrentFullscreenPhoto(root).identity; next.image=[UIImage new];
    Check(![BHRDCurrentFullscreenPhoto(root).identity isEqual:identity],@"Reused bitmap changes snapshot identity");
    next.hidden=YES;
    T1SlideshowStatusView *status=[T1SlideshowStatusView new]; status.bounds=root.bounds; status.frame=root.frame; [root addSubview:status]; Photo(status,0,@"status-photo");
    Check([BHRDCurrentFullscreenPhoto(root).url.absoluteString containsString:@"/status-photo?"],@"SlideshowStatusView may contain the main media and must not be pruned wholesale");
    status.hidden=YES; next.hidden=NO;
    AVPlayerLayer *video=[AVPlayerLayer playerLayerWithPlayer:[AVPlayer playerWithPlayerItem:[AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:@"/tmp/unused-fixture-video.mp4"]]]];
    video.frame=root.bounds; [root.layer addSublayer:video];
    Check(!BHRDCurrentFullscreenPhoto(root),@"Live central video suppresses poster copy button");
    [video removeFromSuperlayer];
    UIView *backgroundRoot=[UIView new]; backgroundRoot.bounds=root.bounds; backgroundRoot.frame=root.frame; backgroundRoot.window=backgroundRoot;
    UIImageView *background=[UIImageView new]; background.frame=root.frame; background.bounds=root.bounds; background.image=[UIImage new]; [backgroundRoot addSubview:background];
    PhotoImageView *foreground=Photo(backgroundRoot,0,@"real-photo"); foreground.frame=CGRectMake(0,200,390,444); foreground.bounds=CGRectMake(0,0,390,444);
    Check([BHRDCurrentFullscreenPhoto(backgroundRoot).url.absoluteString containsString:@"/real-photo?"],@"Real media URL outranks a larger decorative background bitmap");
    root.window=nil;
    Check(!BHRDCurrentFullscreenPhoto(root),@"Detached fullscreen owner has no current image");
    Check(BHRDIsFullscreenMediaController([T1ImmersiveFullScreenViewController new]),@"Photo path recognizes the same immersive full-screen controller as video");
    Check(BHRDIsFullscreenMediaController([T1ImmersiveViewController new]),@"Legacy immersive container is supported");
    Check(BHRDIsFullscreenMediaController([NewNativePhotoContainer new]),@"Native container subclasses retain recognition");
    Check(!BHRDIsFullscreenMediaController([PhotoFixtureController new]),@"Ordinary controllers are not treated as fullscreen media");
    UIView *mediaRoot=[UIView new]; mediaRoot.bounds=CGRectMake(0,0,390,844); mediaRoot.frame=mediaRoot.bounds; mediaRoot.window=mediaRoot;
    UIControl *wrapper=[UIControl new]; wrapper.frame=mediaRoot.frame; wrapper.bounds=mediaRoot.bounds; [mediaRoot addSubview:wrapper];
    PhotoImageView *inside=Photo(wrapper,0,@"inside-control");
    Check([BHRDCurrentFullscreenPhoto(mediaRoot).url.absoluteString containsString:@"/inside-control?"],@"Image descendants of controls are reachable");
    wrapper.frame=CGRectZero; wrapper.bounds=CGRectZero;
    Check(BHRDCurrentFullscreenPhoto(mediaRoot)!=nil,@"Unclipped zero-size native wrappers do not hide their visible media descendants");
    wrapper.frame=mediaRoot.frame; wrapper.bounds=mediaRoot.bounds;
    inside.frame=CGRectMake(0,100,390,180); inside.bounds=CGRectMake(0,0,390,180);
    Check(BHRDCurrentFullscreenPhoto(mediaRoot)!=nil,@"Short image above viewport midpoint is still a current photo");
    wrapper.clipsToBounds=YES; wrapper.bounds=CGRectMake(0,0,390,80); wrapper.frame=wrapper.bounds;
    Check(!BHRDCurrentFullscreenPhoto(mediaRoot),@"Clipped image outside its pager container is excluded");
    wrapper.hidden=YES;
    UIView *raster=[UIView new]; raster.frame=CGRectMake(0,100,390,500); raster.bounds=CGRectMake(0,0,390,500); [mediaRoot addSubview:raster];
    CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap=CGBitmapContextCreate(NULL,128,128,8,0,color,(CGBitmapInfo)kCGImageAlphaPremultipliedLast); CGColorSpaceRelease(color);
    CGImageRef pixels=CGBitmapContextCreateImage(bitmap); CGContextRelease(bitmap);
    raster.layer.contents=(__bridge id)pixels;
    Check(BHRDCurrentFullscreenPhoto(mediaRoot).image.CGImage==pixels,@"Custom native layer bitmap is copied directly without a screenshot");
    CGImageRelease(pixels);
    PhotoImageView *neighbor=Photo(mediaRoot,275,@"adjacent-page");
    Check(BHRDCurrentFullscreenPhoto(mediaRoot).image.CGImage==(__bridge CGImageRef)raster.layer.contents,@"A partially visible adjacent URL does not override the current bitmap");
    neighbor.hidden=YES; raster.hidden=YES;
    for (Class cls in @[T1StatusInlineActionsView.class,T1QuotedStatusView.class]) {
        UIView *chrome=[cls new]; chrome.frame=mediaRoot.frame; chrome.bounds=mediaRoot.bounds; [mediaRoot addSubview:chrome]; Photo(chrome,0,@"not-main-media");
        Check(!BHRDCurrentFullscreenPhoto(mediaRoot),@"Inline controls and quoted status chrome cannot become the main image"); chrome.hidden=YES;
    }
    NativeNodeView *nodeView=[NativeNodeView new]; nodeView.frame=mediaRoot.frame; nodeView.bounds=mediaRoot.bounds; nodeView.asyncdisplaykit_node=[NativeAsyncImageNode new];
    nodeView.asyncdisplaykit_node.image=[UIImage new]; nodeView.asyncdisplaykit_node.imageURL=[NSURL URLWithString:@"https://pbs.twimg.com/media/node?format=png&name=small"];
    [mediaRoot addSubview:nodeView];
    Check(BHRDCurrentFullscreenPhoto(mediaRoot).image==nodeView.asyncdisplaykit_node.image,@"Async image-node bitmap is available without an UIImageView");
    Check([BHRDCurrentFullscreenPhoto(mediaRoot).url.absoluteString containsString:@"/node?format=png&name=orig"],@"Current image-node URL stays paired with its bitmap");
    nodeView.hidden=YES;
    PhotoFixtureController *unknown=[PhotoFixtureController new]; unknown.viewIfLoaded=mediaRoot;
    UIView *source=[UIView new]; source.window=mediaRoot; [mediaRoot addSubview:source];
    BHRDRegisterFullscreenMediaSource(unknown,source);
    Check(BHRDIsFullscreenMediaController(unknown),@"Verified native immersive action bar admits an unnamed host");
    Check(!BHRDIsFullscreenMediaController([PhotoFixtureController new]),@"Source registration does not affect another instance of the same class");
    source.window=nil; Check(!BHRDIsFullscreenMediaController(unknown),@"Detached source does not leave generic controllers permanently marked");
    source.window=mediaRoot; source.superview=nil; Check(!BHRDIsFullscreenMediaController(unknown),@"Source reparenting invalidates the old host");
    NSLog(@"PASS: %lu production fullscreen photo-selection checks",(unsigned long)checks);
} return 0; }
