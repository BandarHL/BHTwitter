#import <Foundation/Foundation.h>
#import "../BHRDPhotoCopyData.h"
static NSUInteger checks;
static void Check(BOOL ok, NSString *message) { checks++; if (!ok) { NSLog(@"FAIL: %@",message); exit(1); } }
static void Pump(NSTimeInterval seconds) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]]; }
static void Fetch(NSString *base, NSString *path, BOOL success, BOOL cancel) {
    __block NSUInteger callbacks=0; __block NSData *result=nil; __block NSError *failure=nil;
    BHRDPhotoFetch *fetch=[BHRDPhotoFetch fetchURL:[NSURL URLWithString:[base stringByAppendingString:path]] completion:^(NSData *data,NSError *error) { callbacks++; result=data; failure=error; }];
    if (cancel) { [fetch cancel]; [fetch cancel]; }
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    while (!callbacks && deadline.timeIntervalSinceNow>0) Pump(0.01);
    Check(callbacks==1, @"One completion per fetch");
    Check(success ? (result.length && !failure && [BHRDPhotoPasteboardType(result) isEqual:@"public.png"]) : (failure && !result),path);
    if (cancel) { Pump(1.2); Check(callbacks==1 && failure.code==NSURLErrorCancelled,@"Cancelled fetch cannot complete again or copy late"); }
}
int main(int argc,const char *argv[]) { @autoreleasepool {
    if (argc!=2) return 2;
    NSString *modern=BHRDOriginalPhotoURL(@"https://pbs.twimg.com/media/abc?format=jpg&name=small").absoluteString;
    Check([modern isEqual:@"https://pbs.twimg.com/media/abc?format=jpg&name=orig"],@"Modern thumbnail becomes original");
    Check([BHRDOriginalPhotoURL(@"https://pbs.twimg.com/media/abc.png:large").absoluteString isEqual:@"https://pbs.twimg.com/media/abc?format=png&name=orig"],@"Legacy suffix preserves PNG format");
    Check([BHRDOriginalPhotoURL(@"https://pbs.twimg.com/media/abc.jpg:1200x1200").absoluteString containsString:@"format=jpg&name=orig"],@"Legacy dimension suffix");
    Check([BHRDOriginalPhotoURL(@"https://pbs.twimg.com/profile_images/1/a_normal.jpg").path isEqual:@"/profile_images/1/a.jpg"],@"Profile thumbnail uses original asset");
    Check(!BHRDOriginalPhotoURL(@"https://example.com/media/abc.jpg"),@"Reject other hosts");
    Check(!BHRDOriginalPhotoURL(@"http://pbs.twimg.com/media/abc.jpg"),@"Only HTTPS");
    Check(!BHRDOriginalPhotoURL(@"https://pbs.twimg.com/ext_tw_video_thumb/1/a.jpg"),@"Video thumbnails are not photo originals");
    Check(!BHRDOriginalPhotoURL(@"https://pbs.twimg.com/media/a.svg"),@"Do not copy SVG as raster image");
    Check(!BHRDOriginalPhotoURL(@"https://pbs.twimg.com/media/a?format=svg&name=small"),@"Validate query format too");
    Check(!BHRDPhotoPasteboardType([@"<html>error</html>" dataUsingEncoding:NSUTF8StringEncoding]),@"Reject non-image clipboard content");
    Check(BHRDPhotoCopyMayComplete(@"a",@"a",1,1,YES,NO),@"Current visible request may copy");
    Check(!BHRDPhotoCopyMayComplete(@"a",@"b",1,1,YES,NO),@"Swiping to another photo blocks stale copy");
    Check(!BHRDPhotoCopyMayComplete(@"a",@"a",1,2,YES,NO),@"Returning to the same photo does not revive cancelled request");
    Check(!BHRDPhotoCopyMayComplete(@"a",@"a",1,1,NO,NO),@"Leaving fullscreen prevents clipboard mutation");
    Check(!BHRDPhotoCopyMayComplete(@"a",@"a",1,1,YES,YES),@"Modal overlay prevents late clipboard write");
    NSString *base=@(argv[1]);
    Fetch(base,@"/ok",YES,NO); Fetch(base,@"/missing",NO,NO); Fetch(base,@"/html",NO,NO);
    Fetch(base,@"/fake",NO,NO); Fetch(base,@"/large",NO,NO); Fetch(base,@"/redirect",NO,NO); Fetch(base,@"/slow",NO,YES);
    NSLog(@"PASS: %lu original-photo, clipboard lifecycle and HTTP checks",(unsigned long)checks);
} return 0; }
