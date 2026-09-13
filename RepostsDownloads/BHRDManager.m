#import "BHRDManager.h"
#import <Photos/Photos.h>
#import "BHRDDownloadStore.h"
#import "BHRDStreamJob.h"
#import <objc/message.h>
#import "../ffmpeg/FFmpegKit.h"
#import "../ffmpeg/FFprobeKit.h"
#import "../ffmpeg/MediaInformationSession.h"

UIViewController *BHRDTopViewController(void) {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    if (!window) window = UIApplication.sharedApplication.keyWindow;
    UIViewController *top = window.rootViewController;
    for (;;) {
        if (top.presentedViewController && !top.presentedViewController.isBeingDismissed) top = top.presentedViewController;
        else if ([top isKindOfClass:UINavigationController.class]) top = ((UINavigationController *)top).visibleViewController;
        else if ([top isKindOfClass:UITabBarController.class]) top = ((UITabBarController *)top).selectedViewController;
        else break;
    }
    return top;
}
void BHRDShowError(NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"X 随心" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [BHRDTopViewController() presentViewController:alert animated:YES completion:nil];
    });
}
@implementation BHRDManager
+ (BOOL)HideReposts { return BHRDPreference(BHRDHideRepostsKey); }
+ (BOOL)DownloadingVideos { return BHRDPreference(BHRDDownloadKey); }
+ (BOOL)DirectSave { return BHRDPreference(BHRDDirectSaveKey); }
+ (BOOL)DMDownload { return [self DownloadingVideos] && BHRDPreference(BHRDDMKey); }
+ (BOOL)isVideoCell:(id)model {
    for (NSString *name in @[@"isMediaEntityVideo", @"isGIF"]) {
        SEL selector = NSSelectorFromString(name);
        if ([model respondsToSelector:selector] && ((BOOL (*)(id, SEL))objc_msgSend)(model, selector)) return YES;
    }
    return NO;
}
+ (NSString *)getVideoQuality:(NSString *)url {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:/)([0-9]{2,5}x[0-9]{2,5})(?:/)" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:url options:0 range:NSMakeRange(0, url.length)];
    return match ? [NSString stringWithFormat:@"清晰度：%@", [[url substringWithRange:[match rangeAtIndex:1]] stringByReplacingOccurrencesOfString:@"x" withString:@" × "]] : @"下载视频 / 动图";
}
+ (NSString *)getDownloadingPersent:(float)progress {
    return [NSString stringWithFormat:@"%.0f%%", MAX(0, MIN(1, progress)) * 100];
}
+ (void)showSaveVC:(NSURL *)url {
    UIViewController *top = BHRDTopViewController();
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    sheet.popoverPresentationController.sourceView = top.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(top.view.bounds), CGRectGetMidY(top.view.bounds), 1, 1);
    sheet.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
        // Keep the file when the user cancels or the receiving activity fails.
        if (completed && !error) BHRDDiscardDownload(url);
    };
    [top presentViewController:sheet animated:YES completion:nil];
}
+ (void)save:(NSURL *)url {
    // Calling the Photos authorization API without a host usage string terminates the app.
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    if (![info[@"NSPhotoLibraryAddUsageDescription"] length] && ![info[@"NSPhotoLibraryUsageDescription"] length]) {
        [self showSaveVC:url];
        return;
    }
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self showSaveVC:url]; });
            return;
        }
        [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        } completionHandler:^(BOOL success, NSError *error) {
            if (success) {
                BHRDDiscardDownload(url);
                BHRDShowError(@"已保存到相册。");
            } else {
                NSLog(@"[BHRD] 相册保存失败：%@", error);
                BHRDShowError(@"无法保存到相册，请检查相册权限和剩余存储空间。可在 X 随心设置的“已下载的文件”中重试。");
            }
        }];
    }];
}
+ (UIAlertController *)newFFmpegDownloadSheet:(MediaInformation *)info downloadingURL:(NSURL *)url selection:(void (^)(NSNumber *index))selection {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"下载流媒体" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSMutableSet *seen = [NSMutableSet set];
    for (StreamInformation *stream in [info getStreams]) {
        NSNumber *width = [stream getWidth], *height = [stream getHeight], *index = [stream getIndex];
        if (!index || index.integerValue < 0 || ![[stream getType] isEqual:@"video"]) continue;
        if (width.integerValue <= 0 || height.integerValue <= 0) continue;
        NSString *resolution = [NSString stringWithFormat:@"%@x%@", width, height];
        if ([seen containsObject:resolution]) continue;
        [seen addObject:resolution];
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"清晰度：%@ × %@", width, height] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if ([self DownloadingVideos] && selection) selection(index);
        }]];
    }
    if (seen.count == 0) sheet.message = @"无法读取流媒体清晰度，请选择普通视频下载或刷新后重试。";
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    return sheet;
}
@end

__attribute__((constructor)) static void BHRDInstallDownloadMaintenance(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        BHRDCleanSavedDownloads();
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { BHRDCleanSavedDownloads(); }];
    });
}
