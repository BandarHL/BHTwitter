#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "../BHRDFullscreenPhotoResolver.h"
@interface PhotoImageView : UIImageView
@property(nonatomic,strong) NSURL *imageURL;
@end
@implementation PhotoImageView @end
@interface T1SlideshowStatusView : UIView @end
@implementation T1SlideshowStatusView @end
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
    Check(!BHRDCurrentFullscreenPhoto(root),@"Tweet information overlay cannot supply current fullscreen image");
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
    NSLog(@"PASS: %lu production fullscreen photo-selection checks",(unsigned long)checks);
} return 0; }
