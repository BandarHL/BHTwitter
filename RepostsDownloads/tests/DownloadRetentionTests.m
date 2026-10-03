#import <Foundation/Foundation.h>
#import "../BHRDDownloadStore.h"
#import "../BHRDFileNaming.h"
#import "../BHRDPreferences.h"
#import <math.h>
static NSUInteger checks;
static void Check(BOOL ok, NSString *message) {
    checks++;
    if (!ok) { NSLog(@"FAIL: %@", message); exit(1); }
}
static NSURL *File(NSURL *directory, NSString *name, NSDate *date) {
    NSURL *url = [directory URLByAppendingPathComponent:name];
    Check([[@"video fixture" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:url atomically:YES], @"Create actual fixture file");
    Check([NSFileManager.defaultManager setAttributes:@{NSFileModificationDate:date} ofItemAtPath:url.path error:nil], @"Set actual filesystem age");
    return url;
}
static BOOL Exists(NSURL *url) { return [NSFileManager.defaultManager fileExistsAtPath:url.path]; }
int main(void) { @autoreleasepool {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id originalPolicy = [defaults objectForKey:BHRDDownloadRetentionKey];
    [defaults removeObjectForKey:BHRDDownloadRetentionKey];
    Check(BHRDDownloadRetentionDays() == 7, @"Unset retention defaults to seven days");
    for (id invalid in @[@(-1), @1, @7.5, @"30", NSNull.null]) {
        if (invalid == NSNull.null) [defaults removeObjectForKey:BHRDDownloadRetentionKey];
        else [defaults setObject:invalid forKey:BHRDDownloadRetentionKey];
        Check(BHRDDownloadRetentionDays() == 7, @"Unsupported retention safely uses default");
    }
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:floor(NSDate.date.timeIntervalSince1970)];
    NSDate *old = [now dateByAddingTimeInterval:-44*24*3600];
    NSURL *directory = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    Check([NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil], @"Create isolated filesystem directory");
    NSURL *protected = File(directory, @"important.mp4", old);
    NSError *error = nil;
    Check(BHRDSetDownloadPermanent(protected, YES, &error) && !error && BHRDDownloadIsPermanent(protected), @"Protect actual completed MP4 with persistent file attribute");
    NSDate *mtime = nil;
    [protected getResourceValue:&mtime forKey:NSURLContentModificationDateKey error:nil];
    Check(fabs([mtime timeIntervalSinceDate:old]) < 1, @"Protection never resets retention age");
    NSURL *expired = File(directory, @"expired.mp4", old);
    NSURL *active = File(directory, @"active.partial.mp4", old);
    NSURL *unrelated = File(directory, @"avatar-diag.log", old);
    NSURL *recent = File(directory, @"recent.mp4", [now dateByAddingTimeInterval:-3600]);
    [defaults setInteger:7 forKey:BHRDDownloadRetentionKey];
    BHRDPruneDownloads(directory, now, [NSSet setWithObject:active.path]);
    Check(Exists(protected) && !Exists(expired), @"Cleanup expires ordinary video while retaining important file");
    Check(Exists(active) && Exists(unrelated) && Exists(recent), @"Cleanup preserves active transfers, unrelated files and recent downloads");
    NSURL *renamed = BHRDRenameVideoFile(protected, @"renamed important", &error);
    Check(renamed && !Exists(protected) && BHRDDownloadIsPermanent(renamed), @"Actual rename retains permanent marker on the file");
    NSURL *reopened = [NSURL fileURLWithPath:renamed.path];
    Check(BHRDDownloadIsPermanent(reopened), @"Protection survives independent URL instances and disk reads");
    BHRDPruneDownloads(directory, now, [NSSet setWithObject:active.path]);
    Check(Exists(renamed), @"Renamed old important file remains immune to cleanup");
    BHRDDiscardExportedDownload(reopened);
    Check(Exists(renamed), @"Successful single export preserves important original");
    NSURL *normalExport = File(directory, @"normal-export.mp4", now);
    BHRDDiscardExportedDownload(normalExport);
    Check(!Exists(normalExport), @"Successful ordinary export preserves existing removal behavior");
    Check(BHRDSetDownloadPermanent(renamed, NO, &error) && !BHRDDownloadIsPermanent(reopened), @"Cancel protection clears its persistent attribute");
    Check(Exists(renamed), @"Cancel protection does not immediately delete file");
    Check(BHRDSetDownloadPermanent(renamed, NO, &error), @"Cancel absent marker is idempotent");
    BHRDPruneDownloads(directory, now, [NSSet setWithObject:active.path]);
    Check(!Exists(renamed), @"Subsequent cleanup follows policy after protection is cancelled");
    NSURL *tenDays = File(directory, @"ten-days.mp4", [now dateByAddingTimeInterval:-10*24*3600]);
    NSURL *thirtyOneDays = File(directory, @"thirty-one-days.mp4", [now dateByAddingTimeInterval:-31*24*3600]);
    [defaults setInteger:30 forKey:BHRDDownloadRetentionKey];
    Check(BHRDDownloadRetentionDays() == 30 && [BHRDDownloadRetentionTitle() isEqual:@"30 天"], @"Thirty-day policy is reported accurately");
    Check(Exists(tenDays) && Exists(thirtyOneDays), @"Policy changes only store settings and leave existing files untouched");
    BHRDPruneDownloads(directory, now, [NSSet setWithObject:active.path]);
    Check(Exists(tenDays) && !Exists(thirtyOneDays), @"Thirty-day cleanup respects configured cutoff");
    [defaults setInteger:0 forKey:BHRDDownloadRetentionKey];
    Check(BHRDDownloadRetentionDays() == 0 && [BHRDDownloadRetentionTitle() isEqual:@"永久"], @"Zero is explicit permanent global retention");
    NSURL *ancient = File(directory, @"ancient.mp4", [now dateByAddingTimeInterval:-500*24*3600]);
    BHRDPruneDownloads(directory, now, [NSSet set]);
    Check(Exists(ancient) && Exists(active), @"Global permanent policy does not delete old completed or partial files");
    NSURL *nested = [directory URLByAppendingPathComponent:@"directory.mp4" isDirectory:YES];
    Check([NSFileManager.defaultManager createDirectoryAtURL:nested withIntermediateDirectories:NO attributes:nil error:nil], @"Create MP4-named directory fixture");
    NSURL *link = [directory URLByAppendingPathComponent:@"symlink.mp4"];
    Check([NSFileManager.defaultManager createSymbolicLinkAtURL:link withDestinationURL:ancient error:nil], @"Create real symbolic link fixture");
    for (NSURL *invalidFile in @[active, unrelated, nested, link, [directory URLByAppendingPathComponent:@"missing.mp4"]]) {
        error = nil;
        Check(!BHRDSetDownloadPermanent(invalidFile, YES, &error) && error != nil && !BHRDDownloadIsPermanent(invalidFile), @"Only a real completed regular MP4 can be marked important");
    }
    [defaults setInteger:7 forKey:BHRDDownloadRetentionKey];
    BHRDPruneDownloads(directory, now, [NSSet setWithObject:active.path]);
    Check([NSFileManager.defaultManager attributesOfItemAtPath:link.path error:nil] != nil && Exists(nested), @"Cleanup does not delete symbolic links or directories");
    NSURL *manual = File(directory, @"manual-delete.mp4", old);
    Check(BHRDSetDownloadPermanent(manual, YES, nil), @"Create important explicit-delete fixture");
    BHRDDiscardDownload(manual);
    Check(!Exists(manual), @"Explicit discard can delete a protected file");
    NSURL *replacement = File(directory, @"manual-delete.mp4", now);
    Check(!BHRDDownloadIsPermanent(replacement), @"New file at deleted pathname cannot inherit old protection");
    NSURL *boundary = File(directory, @"boundary.mp4", [now dateByAddingTimeInterval:-7*24*3600]);
    BHRDPruneDownloads(directory, now, [NSSet setWithObject:active.path]);
    Check(Exists(boundary), @"Exact retention boundary remains available");
    BHRDPruneDownloads(directory, [now dateByAddingTimeInterval:2], [NSSet setWithObject:active.path]);
    Check(!Exists(boundary), @"Passing the retention boundary expires the ordinary file");
    Check([NSFileManager.defaultManager removeItemAtURL:directory error:nil], @"Remove test directory and attributes");
    if (originalPolicy) [defaults setObject:originalPolicy forKey:BHRDDownloadRetentionKey];
    else [defaults removeObjectForKey:BHRDDownloadRetentionKey];
    NSLog(@"PASS: %lu download-retention checks", (unsigned long)checks);
} return 0; }
