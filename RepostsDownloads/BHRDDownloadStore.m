#import "BHRDDownloadStore.h"
#import "BHRDPreferences.h"
#import <sys/stat.h>
#import <sys/xattr.h>
#import <errno.h>
static const char * const PermanentAttribute = "com.caun.xsuixin.permanent-download";
static NSMutableSet *ActivePaths(void) { static NSMutableSet *paths; static dispatch_once_t once; dispatch_once(&once, ^{ paths=[NSMutableSet set]; }); return paths; }
static BOOL RegularFile(NSURL *url) {
    if (!url.isFileURL || !url.fileSystemRepresentation) return NO;
    struct stat status;
    return lstat(url.fileSystemRepresentation, &status) == 0 && S_ISREG(status.st_mode);
}
BOOL BHRDDownloadIsPermanent(NSURL *url) {
    if (!RegularFile(url)) return NO;
    char value = 0;
    return getxattr(url.fileSystemRepresentation, PermanentAttribute, &value, sizeof(value), 0, XATTR_NOFOLLOW) == sizeof(value) && value == '1';
}
BOOL BHRDSetDownloadPermanent(NSURL *url, BOOL permanent, NSError **error) {
    if (!RegularFile(url) || ![url.pathExtension.lowercaseString isEqual:@"mp4"] || [url.lastPathComponent.lowercaseString hasSuffix:@".partial.mp4"]) {
        if (error) *error = [NSError errorWithDomain:@"BHRDDownloadStore" code:1 userInfo:@{NSLocalizedDescriptionKey:@"只能更改已完成视频的保留设置。"}];
        return NO;
    }
    const char value = '1';
    int result = permanent ? setxattr(url.fileSystemRepresentation, PermanentAttribute, &value, sizeof(value), 0, XATTR_NOFOLLOW) : removexattr(url.fileSystemRepresentation, PermanentAttribute, XATTR_NOFOLLOW);
    if (result != 0 && !(!permanent && errno == ENOATTR)) {
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        return NO;
    }
    [NSNotificationCenter.defaultCenter postNotificationName:@"BHRDDownloadsChanged" object:nil];
    return YES;
}
NSInteger BHRDDownloadRetentionDays(void) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:BHRDDownloadRetentionKey];
    if (![value isKindOfClass:NSNumber.class]) return 7;
    double days = [value doubleValue];
    return days == 0 || days == 7 || days == 30 ? (NSInteger)days : 7;
}
NSString *BHRDDownloadRetentionTitle(void) {
    NSInteger days = BHRDDownloadRetentionDays();
    return days ? [NSString stringWithFormat:@"%ld 天", (long)days] : @"永久";
}
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
    for (NSURL *url in files) if ([url.pathExtension isEqual:@"mp4"] && ![url.lastPathComponent hasSuffix:@".partial.mp4"] && RegularFile(url)) [result addObject:url];
    return [result sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *da=nil, *db=nil; [a getResourceValue:&da forKey:NSURLContentModificationDateKey error:nil]; [b getResourceValue:&db forKey:NSURLContentModificationDateKey error:nil];
        return [(db ?: NSDate.distantPast) compare:(da ?: NSDate.distantPast)];
    }];
}
void BHRDPruneDownloads(NSURL *directory, NSDate *now, NSSet<NSString *> *activePaths) {
    NSInteger days = BHRDDownloadRetentionDays();
    if (!days) return;
    NSMutableSet *canonical = [NSMutableSet set];
    for (NSString *path in activePaths) [canonical addObject:[NSURL fileURLWithPath:path].URLByResolvingSymlinksInPath.path];
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:@[NSURLContentModificationDateKey, NSURLIsRegularFileKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for (NSURL *url in files) {
        if (![url.pathExtension isEqual:@"mp4"] || [canonical containsObject:url.URLByResolvingSymlinksInPath.path] || !RegularFile(url) || BHRDDownloadIsPermanent(url)) continue;
        NSDate *date=nil; NSNumber *regular=nil;
        [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        if (regular.boolValue && date && [now timeIntervalSinceDate:date] > days*24*3600) [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }
}
void BHRDCleanSavedDownloads(void) {
    NSSet *active; @synchronized(ActivePaths()) { active = [ActivePaths() copy]; }
    BHRDPruneDownloads(BHRDDownloadDirectory(), NSDate.date, active);
}
void BHRDDiscardDownload(NSURL *url) {
    if (!url) return;
    @synchronized(ActivePaths()) { [ActivePaths() removeObject:url.path]; }
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:@"BHRDDownloadsChanged" object:nil];
}
void BHRDDiscardExportedDownload(NSURL *url) {
    if (!BHRDDownloadIsPermanent(url)) BHRDDiscardDownload(url);
}
