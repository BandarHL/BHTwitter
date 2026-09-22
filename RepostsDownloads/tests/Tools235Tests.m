#import <UIKit/UIKit.h>
#import "../BHRDFileNaming.h"
#import "../BHRDPhotoClipboard.h"
static NSUInteger checks;
static void Check(BOOL ok,NSString *message) { checks++; if (!ok) { NSLog(@"FAIL: %@",message); exit(1); } }
int main(void) { @autoreleasepool {
    Check([BHRDVideoFilename(@"  我的收藏  ") isEqual:@"我的收藏.mp4"],@"Trim and preserve Unicode names");
    Check([BHRDVideoFilename(@"clip.MP4") isEqual:@"clip.mp4"],@"No doubled extension");
    for (NSString *input in @[@"",@"../other",@"a/b",@"a\\b",@"a:b",@".hidden",@"a.partial",@"a.partial.mp4",@"a\nb",[@"a" stringByPaddingToLength:81 withString:@"a" startingAtIndex:0]]) Check(!BHRDVideoFilename(input),@"Reject invalid filename");
    NSURL *dir=[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *source=[dir URLByAppendingPathComponent:@"before.mp4"];
    NSData *content=[@"video-fixture" dataUsingEncoding:NSUTF8StringEncoding]; [content writeToURL:source atomically:YES];
    NSDate *old=[NSDate dateWithTimeIntervalSinceNow:-3600]; [NSFileManager.defaultManager setAttributes:@{NSFileModificationDate:old} ofItemAtPath:source.path error:nil];
    NSError *error=nil; NSURL *renamed=BHRDRenameVideoFile(source,@"after",&error);
    Check(renamed && !error && [renamed.lastPathComponent isEqual:@"after.mp4"],@"Rename completed download");
    Check([[NSData dataWithContentsOfURL:renamed] isEqual:content] && ![NSFileManager.defaultManager fileExistsAtPath:source.path],@"Rename preserves bytes and removes old path");
    NSDate *mtime=nil; [renamed getResourceValue:&mtime forKey:NSURLContentModificationDateKey error:nil];
    Check(fabs([mtime timeIntervalSinceDate:old])<1,@"Rename preserves retention date");
    NSURL *existing=[dir URLByAppendingPathComponent:@"existing.mp4"]; [@"other" writeToURL:existing atomically:YES encoding:NSUTF8StringEncoding error:nil];
    Check(!BHRDRenameVideoFile(renamed,@"existing",&error),@"Collision never overwrites a download");
    Check([[NSString stringWithContentsOfURL:existing encoding:NSUTF8StringEncoding error:nil] isEqual:@"other"],@"Collision preserves destination");
    NSURL *partial=[dir URLByAppendingPathComponent:@"active.partial.mp4"]; [content writeToURL:partial atomically:YES];
    Check(!BHRDRenameVideoFile(partial,@"move-active",nil),@"Active partial download cannot be renamed");
    NSURL *link=[dir URLByAppendingPathComponent:@"link.mp4"]; [NSFileManager.defaultManager createSymbolicLinkAtURL:link withDestinationURL:renamed error:nil];
    Check(!BHRDRenameVideoFile(link,@"move-link",nil),@"Symlink cannot rename external file");
    [NSFileManager.defaultManager removeItemAtURL:dir error:nil];
    NSData *png=[[NSData alloc] initWithBase64EncodedString:@"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1cAAAAASUVORK5CYII=" options:0];
    UIPasteboard *board=UIPasteboard.generalPasteboard;
    Check(BHRDWritePhotoClipboard(png,YES),@"Private photo copy succeeds");
    Check([board.fixtureOptions[UIPasteboardOptionLocalOnly] boolValue],@"Private copy is local-only");
    NSDate *expiry=board.fixtureOptions[UIPasteboardOptionExpirationDate];
    Check(expiry.timeIntervalSinceNow>598 && expiry.timeIntervalSinceNow<=600,@"Private copy expires in ten minutes");
    Check(board.fixtureItems.count==1 && [board.fixtureItems[0][@"public.png"] isEqual:png],@"Actual image bytes, not URL/text, are copied");
    NSArray *previous=board.fixtureItems;
    Check(!BHRDWritePhotoClipboard([@"invalid" dataUsingEncoding:NSUTF8StringEncoding],YES) && board.fixtureItems==previous,@"Invalid image never clears existing clipboard");
    Check(BHRDWritePhotoClipboard(png,NO) && board.fixtureOptions.count==0,@"Normal copy does not retain earlier private expiry options");
    NSLog(@"PASS: %lu image-tool privacy and file management checks",(unsigned long)checks);
} return 0; }
