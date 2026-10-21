#import "BHRDFileNaming.h"
NSString *BHRDVideoFilename(NSString *input) {
    if (![input isKindOfClass:NSString.class]) return nil;
    NSString *name=[input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([name.pathExtension.lowercaseString isEqual:@"mp4"]) name=name.stringByDeletingPathExtension;
    if (!name.length || name.length>80 || [name hasPrefix:@"."] || [name.lowercaseString hasSuffix:@".partial"]) return nil;
    if ([name rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\:"]].location!=NSNotFound || [name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound) return nil;
    return [name stringByAppendingPathExtension:@"mp4"];
}
NSURL *BHRDRenameVideoFile(NSURL *source, NSString *input, NSError **error) {
    NSString *name=BHRDVideoFilename(input);
    NSNumber *regular=nil,*link=nil;
    [source getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
    [source getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
    if (!name || !source.isFileURL || !regular.boolValue || link.boolValue || ![source.pathExtension.lowercaseString isEqual:@"mp4"] || [source.lastPathComponent.lowercaseString hasSuffix:@".partial.mp4"]) {
        if (error) *error=[NSError errorWithDomain:@"BHRDFileNaming" code:1 userInfo:@{NSLocalizedDescriptionKey:@"请输入 1～80 字的文件名，不含路径分隔符；仅能重命名已完成的视频。"}];
        return nil;
    }
    NSURL *target=[source.URLByDeletingLastPathComponent URLByAppendingPathComponent:name];
    if ([target.path isEqual:source.path]) return source;
    // moveItem fails on collisions instead of replacing another saved download.
    if (![NSFileManager.defaultManager moveItemAtURL:source toURL:target error:error]) return nil;
    [NSNotificationCenter.defaultCenter postNotificationName:@"BHRDDownloadsChanged" object:nil];
    return target;
}
