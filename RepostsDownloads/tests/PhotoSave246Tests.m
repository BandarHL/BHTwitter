#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>
#import "../BHRDPhotoLibrarySave.h"
#import "../BHRDPhotoCopyData.h"
#import "../BHRDAvatarDiagnostics.h"
static NSUInteger checks;
static void Check(BOOL value,NSString *message) { checks++; if (!value) { NSLog(@"FAIL: %@",message); exit(1); } }
static void Pump(void) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.03]]; }
static void Reset(PHAuthorizationStatus status) {
    PHPhotoLibrary.fixtureStatus=status; PHPhotoLibrary.fixtureQueries=0; PHPhotoLibrary.fixtureRequests=0; PHPhotoLibrary.fixtureCommits=0;
    PHPhotoLibrary.fixturePermission=nil; PHPhotoLibrary.fixtureCompletion=nil; PHPhotoLibrary.fixtureData=nil; PHPhotoLibrary.fixtureOptions=nil;
}
static NSData *Image(NSString *type,NSUInteger frames,NSInteger orientation) {
    CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(NULL,2,3,8,8,color,(CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context,1,0,0,1); CGContextFillRect(context,CGRectMake(0,0,2,3));
    CGImageRef image=CGBitmapContextCreateImage(context); NSMutableData *data=[NSMutableData data];
    CGImageDestinationRef dest=CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,(__bridge CFStringRef)type,frames,NULL);
    for (NSUInteger i=0;i<frames;i++) CGImageDestinationAddImage(dest,image,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImagePropertyOrientation:@(orientation)});
    BOOL done=CGImageDestinationFinalize(dest); CFRelease(dest); CGImageRelease(image); CGContextRelease(context); CGColorSpaceRelease(color);
    return done ? [data copy] : nil;
}
int main(void) { @autoreleasepool {
    NSData *png=Image(@"public.png",1,1), *jpeg=Image(@"public.jpeg",1,6), *gif=Image(@"com.compuserve.gif",2,1);
    Check(png && jpeg && gif,@"Image fixtures are encodable");
    Check([BHRDPhotoLibraryPayload(png) isEqual:png],@"PNG bytes preserved");
    Check([BHRDPhotoLibraryPayload(jpeg) isEqual:jpeg],@"JPEG including orientation metadata preserved");
    Check([BHRDPhotoLibraryPayload(gif) isEqual:gif],@"Animated GIF frames preserved as original data");
    NSData *tiff=Image(@"public.tiff",1,6), *converted=BHRDPhotoLibraryPayload(tiff);
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)converted,NULL);
    NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL)); CFRelease(source);
    Check([BHRDPhotoPasteboardType(converted) isEqual:@"public.png"],@"Other still image converted to PNG");
    Check([properties[(__bridge NSString *)kCGImagePropertyPixelWidth] integerValue]==3 && [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] integerValue]==2,@"EXIF rotation is physically applied during conversion");
    Check(!BHRDPhotoLibraryPayload([@"bad" dataUsingEncoding:NSUTF8StringEncoding]),@"Invalid payload rejected");
    NSDictionary *info=@{@"NSPhotoLibraryAddUsageDescription":@"Add photos"};
    __block BOOL current=YES; __block NSUInteger callbacks=0; __block BOOL success=NO; __block NSError *result=nil;
    void (^completed)(BOOL,NSError *)=^(BOOL ok,NSError *error) { Check(NSThread.isMainThread,@"Completion returns to main"); callbacks++; success=ok; result=error; };
    Reset(PHAuthorizationStatusAuthorized);
    BHRDPhotoSaveJob *job=[BHRDPhotoSaveJob saveData:jpeg hostInfo:info stillCurrent:^BOOL { return current; } completion:completed]; Pump();
    Check(job.committed && PHPhotoLibrary.fixtureCommits==1 && PHPhotoLibrary.fixtureRequests==0,@"Authorized access commits without requesting again");
    Check(PHPhotoLibrary.fixtureAccess==PHAccessLevelAddOnly,@"Only add-only access queried");
    Check([PHPhotoLibrary.fixtureData isEqual:jpeg] && [PHPhotoLibrary.fixtureOptions.uniformTypeIdentifier isEqual:@"public.jpeg"],@"Production Photos request receives original JPEG and matching type");
    Check([PHPhotoLibrary.fixtureOptions.originalFilename hasSuffix:@".jpg"],@"Resource uses correct extension");
    void (^finish)(BOOL,NSError *)=PHPhotoLibrary.fixtureCompletion;
    PHPhotoLibrary.fixtureCompletion=nil; finish(YES,nil); finish(YES,nil); Pump();
    Check(success && callbacks==1 && job.finished,@"Duplicate completion cannot report or save twice");
    callbacks=0; Reset(PHAuthorizationStatusDenied);
    job=[BHRDPhotoSaveJob saveData:png hostInfo:info stillCurrent:^BOOL { return YES; } completion:completed]; Pump();
    Check(!success && result.code==BHRDPhotoSaveDenied && callbacks==1 && PHPhotoLibrary.fixtureCommits==0,@"Denied access never writes");
    callbacks=0; Reset(PHAuthorizationStatusAuthorized);
    job=[BHRDPhotoSaveJob saveData:png hostInfo:@{} stillCurrent:^BOOL { return YES; } completion:completed]; Pump();
    Check(result.code==BHRDPhotoSaveMissingUsage && PHPhotoLibrary.fixtureQueries==0 && PHPhotoLibrary.fixtureRequests==0,@"Missing usage string skips all permission APIs");
    callbacks=0; Reset(PHAuthorizationStatusAuthorized);
    job=[BHRDPhotoSaveJob saveData:[@"bad" dataUsingEncoding:NSUTF8StringEncoding] hostInfo:info stillCurrent:^BOOL { return YES; } completion:completed]; Pump();
    Check(result.code==BHRDPhotoSaveInvalidData && PHPhotoLibrary.fixtureCommits==0,@"Invalid data cannot reach Photos");
    callbacks=0; current=YES; Reset(PHAuthorizationStatusNotDetermined);
    job=[BHRDPhotoSaveJob saveData:png hostInfo:info stillCurrent:^BOOL { return current; } completion:completed]; Pump();
    Check(PHPhotoLibrary.fixtureRequests==1 && !job.committed,@"Undetermined permission waits before commit");
    current=NO; void (^permission)(PHAuthorizationStatus)=PHPhotoLibrary.fixturePermission; PHPhotoLibrary.fixturePermission=nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{ permission(PHAuthorizationStatusAuthorized); }); Pump();
    Check(callbacks==1 && result.code==BHRDPhotoSaveCancelled && PHPhotoLibrary.fixtureCommits==0,@"Selection changed during permission prompt cannot save old photo");
    callbacks=0; current=YES; Reset(PHAuthorizationStatusNotDetermined);
    job=[BHRDPhotoSaveJob saveData:png hostInfo:info stillCurrent:^BOOL { return current; } completion:completed]; Pump();
    [job cancel]; permission=PHPhotoLibrary.fixturePermission; PHPhotoLibrary.fixturePermission=nil; permission(PHAuthorizationStatusAuthorized); Pump();
    Check(callbacks==1 && !job.committed && PHPhotoLibrary.fixtureCommits==0,@"Cancel during authorization completes once and discards late permission callback");
    callbacks=0; Reset(PHAuthorizationStatusLimited);
    job=[BHRDPhotoSaveJob saveData:gif hostInfo:info stillCurrent:^BOOL { return YES; } completion:completed]; Pump();
    Check(job.committed && [PHPhotoLibrary.fixtureData isEqual:gif],@"Authorized limited status preserves GIF bytes");
    [job cancel]; Check(!job.finished,@"After Photos commit, leaving viewer does not cancel accepted write");
    NSError *writeError=[NSError errorWithDomain:@"PhotosFixture" code:42 userInfo:nil]; finish=PHPhotoLibrary.fixtureCompletion; PHPhotoLibrary.fixtureCompletion=nil; finish(NO,writeError); Pump();
    Check(callbacks==1 && !success && result==writeError,@"Photos write failure is propagated once");
    callbacks=0; Reset(PHAuthorizationStatusNotDetermined);
    job=[BHRDPhotoSaveJob saveData:png hostInfo:info stillCurrent:^BOOL { return YES; } completion:completed]; Pump();
    permission=PHPhotoLibrary.fixturePermission; PHPhotoLibrary.fixturePermission=nil; permission(PHAuthorizationStatusAuthorized); permission(PHAuthorizationStatusAuthorized); Pump();
    Check(PHPhotoLibrary.fixtureCommits==1,@"Repeated authorization callback cannot submit duplicate asset");
    finish=PHPhotoLibrary.fixtureCompletion; PHPhotoLibrary.fixtureCompletion=nil; finish(YES,nil); Pump();
    Check(success && callbacks==1,@"Successful save finishes after Photos result");
#if BHRD_AVATAR_DIAGNOSTICS
    BHRDAvatarDiagnosticFlush();
#endif
    NSLog(@"PASS: %lu photo payload, Photos permission and save lifecycle checks",(unsigned long)checks);
} return 0; }
