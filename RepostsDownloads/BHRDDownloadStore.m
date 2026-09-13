#import "BHRDDownloadStore.h"
static NSMutableSet *ActivePaths(void) { static NSMutableSet *paths; static dispatch_once_t once; dispatch_once(&once, ^{ paths=[NSMutableSet set]; }); return paths; }
NSURL *BHRDDownloadDirectory(void) {
    NSURL *base = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [base URLByAppendingPathComponent:@"XSuixinDownloads" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [dir setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    return dir;
}
NSURL *BHRDNewDownloadURL(BOOL partial) {
    BHRDCleanSavedDownloads();
    NSURL *url = [BHRDDownloadDirectory() URLByAppendingPathComponent:[NSString stringWithFormat:@"视频-%@.%@", NSUUID.UUID.UUIDString, partial ? @"partial.mp4" : @"mp4"]];
    if (partial) @synchronized(ActivePaths()) { [ActivePaths() addObject:url.path]; }
    return url;
}
NSURL *BHRDCompleteDownload(NSURL *partial) {
    @synchronized(ActivePaths()) { [ActivePaths() removeObject:partial.path]; }
    NSString *name = [partial.lastPathComponent stringByReplacingOccurrencesOfString:@".partial.mp4" withString:@".mp4"];
    NSURL *ready = [partial.URLByDeletingLastPathComponent URLByAppendingPathComponent:name];
    return [NSFileManager.defaultManager moveItemAtURL:partial toURL:ready error:nil] ? ready : nil;
}
NSArray<NSURL *> *BHRDSavedDownloads(void) {
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:BHRDDownloadDirectory() includingPropertiesForKeys:@[NSURLContentModificationDateKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSMutableArray *result = [NSMutableArray array];
    for (NSURL *url in files) if ([url.pathExtension isEqual:@"mp4"] && ![url.lastPathComponent hasSuffix:@".partial.mp4"]) [result addObject:url];
    return [result sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *da=nil, *db=nil; [a getResourceValue:&da forKey:NSURLContentModificationDateKey error:nil]; [b getResourceValue:&db forKey:NSURLContentModificationDateKey error:nil];
        return [(db ?: NSDate.distantPast) compare:(da ?: NSDate.distantPast)];
    }];
}
void BHRDPruneDownloads(NSURL *directory, NSDate *now, NSSet<NSString *> *activePaths) {
    NSMutableSet *canonical = [NSMutableSet set];
    for (NSString *path in activePaths) [canonical addObject:[NSURL fileURLWithPath:path].URLByResolvingSymlinksInPath.path];
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:@[NSURLContentModificationDateKey, NSURLIsRegularFileKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for (NSURL *url in files) {
        if (![url.pathExtension isEqual:@"mp4"] || [canonical containsObject:url.URLByResolvingSymlinksInPath.path]) continue;
        NSDate *date=nil; NSNumber *regular=nil;
        [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        if (regular.boolValue && date && [now timeIntervalSinceDate:date] > 7*24*3600) [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }
}
void BHRDCleanSavedDownloads(void) {
    NSSet *active; @synchronized(ActivePaths()) { active = [ActivePaths() copy]; }
    BHRDPruneDownloads(BHRDDownloadDirectory(), NSDate.date, active);
}
void BHRDDiscardDownload(NSURL *url) {
    @synchronized(ActivePaths()) { [ActivePaths() removeObject:url.path]; }
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:@"BHRDDownloadsChanged" object:nil];
}
