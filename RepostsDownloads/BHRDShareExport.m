#import "BHRDShareExport.h"
#import "BHRDPhotoClipboard.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDPhotoLibrarySave.h"

static NSError *ExportError(NSString *message) {
    return [NSError errorWithDomain:@"com.caun.xsuixin.share-export" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}
@interface BHRDShareExport ()
@property(nonatomic) BOOL closed;
@property(nonatomic) BOOL busy;
@property(nonatomic) BHRDShareExportOutcome lastOutcome;
@property(nonatomic, strong) BHRDPhotoSaveJob *saveJob;
@property(nonatomic, strong) NSURL *shareFile;
@end
@implementation BHRDShareExport
- (void)finish:(BHRDShareExportOutcome)outcome error:(NSError *)error {
    if (!self.busy) return;
    self.busy = NO; self.lastOutcome = outcome; self.saveJob = nil;
    if (self.completion) self.completion(outcome, error);
}
- (void)copyPNG:(NSData *)png {
    if (self.closed || self.busy) return;
    self.busy = YES;
    BOOL copied = BHRDWritePhotoClipboard(png, NO);
    [self finish:copied ? BHRDShareExportCopied : BHRDShareExportFailed error:copied ? nil : ExportError(@"未能确认图片写入剪贴板，请重试。")];
}
- (void)savePNG:(NSData *)png hostInfo:(NSDictionary *)info {
    if (self.closed || self.busy) return;
    self.busy = YES;
    __weak BHRDShareExport *weakSelf = self;
    self.saveJob = [BHRDPhotoSaveJob saveData:png hostInfo:info stillCurrent:^BOOL {
        BHRDShareExport *session = weakSelf;
        return session && !session.closed;
    } completion:^(BOOL success, NSError *error) {
        BOOL cancelled = [error.domain isEqual:BHRDPhotoSaveErrorDomain] && error.code == BHRDPhotoSaveCancelled;
        [self finish:success ? BHRDShareExportSaved : cancelled ? BHRDShareExportCancelled : BHRDShareExportFailed error:error];
    }];
}
- (NSURL *)prepareSharePNG:(NSData *)png {
    if (self.closed || self.busy) return nil;
    self.busy = YES;
    if (![BHRDPhotoPasteboardType(png) isEqual:@"public.png"]) {
        [self finish:BHRDShareExportFailed error:ExportError(@"分享图片无效，请重新生成后重试。")]; return nil;
    }
    NSURL *file = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSString stringWithFormat:@"XSuixin-Share-%@.png", NSUUID.UUID.UUIDString]];
    NSError *error = nil;
    if (![png writeToURL:file options:NSDataWritingAtomic error:&error]) {
        [self finish:BHRDShareExportFailed error:ExportError(@"无法写入分享图片，请检查剩余存储空间。")]; return nil;
    }
    self.shareFile = file; return file;
}
- (void)completeShare:(BOOL)completed error:(NSError *)error {
    if (!self.shareFile) return;
    [[NSFileManager defaultManager] removeItemAtURL:self.shareFile error:nil]; self.shareFile = nil;
    [self finish:error ? BHRDShareExportFailed : completed ? BHRDShareExportShared : BHRDShareExportCancelled error:error];
}
- (void)close {
    self.closed = YES;
    [self.saveJob cancel];
    // A presented activity may still read its attachment. Its completion owns
    // cleanup and result reporting, even if the editor disappears meanwhile.
}
- (void)dealloc { if (_shareFile) [[NSFileManager defaultManager] removeItemAtURL:_shareFile error:nil]; }
@end
