#import <Foundation/Foundation.h>
static inline NSString *BHRDLocalized(NSString *key) {
    NSDictionary *strings = @{
        @"DOWNLOAD_MENU_TITLE": @"下载视频 / 动图",
        @"FFMPEG_DOWNLOAD_OPTION_TITLE": @"下载流媒体视频",
        @"PROGRESS_DOWNLOADING_STATUS_TITLE": @"正在下载…",
        @"FETCHING_PROGRESS_TITLE": @"正在读取清晰度…",
        @"CANCEL_BUTTON_TITLE": @"取消",
        @"OK_BUTTON_TITLE": @"好"
    };
    return strings[key] ?: key;
}

// Do not expose locale-dependent English NSError descriptions in the plugin UI.
static inline NSString *BHRDDownloadErrorMessage(NSError *error) {
    if ([error.domain isEqualToString:@"BHRDBusy"]) return @"已有下载任务进行中，请等待完成或点击进度提示取消。";
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        switch (error.code) {
            case NSURLErrorTimedOut: return @"下载超时，请检查网络后重试。";
            case NSURLErrorNotConnectedToInternet: return @"当前没有网络连接，请连接网络后重试。";
            case NSURLErrorNetworkConnectionLost: return @"下载期间网络连接中断，请重试。";
            case NSURLErrorCannotFindHost:
            case NSURLErrorCannotConnectToHost:
            case NSURLErrorDNSLookupFailed: return @"无法连接视频服务器，请检查网络后重试。";
            case NSURLErrorCancelled: return @"下载已取消。";
            case NSURLErrorSecureConnectionFailed:
            case NSURLErrorServerCertificateUntrusted: return @"无法建立安全连接，请检查网络和设备时间。";
            default: return [NSString stringWithFormat:@"视频下载失败，请刷新推文后重试。（错误码 %ld）", (long)error.code];
        }
    }
    if ([error.domain isEqualToString:@"BHRDDownload"]) {
        return [NSString stringWithFormat:@"服务器未返回视频文件，请刷新推文后重试。（状态码 %ld）", (long)error.code];
    }
    return [NSString stringWithFormat:@"无法保存下载文件，请检查剩余存储空间后重试。（错误码 %ld）", (long)error.code];
}
