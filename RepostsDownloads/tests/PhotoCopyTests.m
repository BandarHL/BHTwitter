#import <Foundation/Foundation.h>
#import "../BHRDPhotoCopyData.h"
#import <zlib.h>
static NSUInteger checks;
static void Check(BOOL ok, NSString *message) { checks++; if (!ok) { NSLog(@"FAIL: %@",message); exit(1); } }
static void Pump(NSTimeInterval seconds) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]]; }
// Compress one zero-filled row repeatedly, without allocating a large bitmap.
static NSData *SizedPNG(uint32_t width,uint32_t height) {
    uint8_t header[]={137,80,78,71,13,10,26,10,0,0,0,13,'I','H','D','R',0,0,0,0,0,0,0,0,8,6,0,0,0,0,0,0,0};
    for (NSUInteger i=0;i<4;i++) { header[16+i]=(uint8_t)(width>>(24-8*i)); header[20+i]=(uint8_t)(height>>(24-8*i)); }
    uint32_t crc=(uint32_t)crc32(0,header+12,17);
    for (NSUInteger i=0;i<4;i++) header[29+i]=(uint8_t)(crc>>(24-8*i));
    NSMutableData *data=[NSMutableData dataWithBytes:header length:sizeof(header)];
    NSMutableData *compressed=[NSMutableData data];
    if (width<=8001 && height<=4000) {
        NSData *row=[NSMutableData dataWithLength:1+(NSUInteger)width*4]; uint8_t buffer[4096]; z_stream stream={0};
        deflateInit(&stream,Z_BEST_SPEED);
        for (uint32_t y=0;y<height;y++) {
            stream.next_in=(Bytef *)row.bytes; stream.avail_in=(uInt)row.length;
            do { stream.next_out=buffer; stream.avail_out=sizeof(buffer); deflate(&stream,Z_NO_FLUSH); [compressed appendBytes:buffer length:sizeof(buffer)-stream.avail_out]; } while (stream.avail_in || !stream.avail_out);
        }
        int result;
        do { stream.next_out=buffer; stream.avail_out=sizeof(buffer); result=deflate(&stream,Z_FINISH); [compressed appendBytes:buffer length:sizeof(buffer)-stream.avail_out]; } while (result!=Z_STREAM_END);
        deflateEnd(&stream);
    }
    uint8_t chunk[8]={0,0,0,0,'I','D','A','T'}; uint32_t length=(uint32_t)compressed.length;
    for (NSUInteger i=0;i<4;i++) chunk[i]=(uint8_t)(length>>(24-8*i)); [data appendBytes:chunk length:8]; [data appendData:compressed];
    crc=(uint32_t)crc32(0,chunk+4,4); crc=(uint32_t)crc32(crc,compressed.bytes,(uInt)compressed.length);
    uint8_t trailer[16]={0,0,0,0,0,0,0,0,'I','E','N','D',174,66,96,130};
    for (NSUInteger i=0;i<4;i++) trailer[i]=(uint8_t)(crc>>(24-8*i)); [data appendBytes:trailer length:16]; return data;
}
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
    Check([BHRDPhotoPasteboardType(SizedPNG(8000,4000)) isEqual:@"public.png"],@"Metadata budget accepts the 32 MP boundary without decoding pixels");
    Check(!BHRDPhotoPasteboardType(SizedPNG(8001,4000)),@"Metadata budget rejects just over 32 MP before pixel decoding");
    Check(!BHRDPhotoPasteboardType(SizedPNG(UINT32_MAX,UINT32_MAX)),@"Dimension arithmetic cannot wrap and bypass the image budget");
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
