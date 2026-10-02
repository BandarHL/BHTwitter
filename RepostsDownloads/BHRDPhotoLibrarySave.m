#import "BHRDPhotoLibrarySave.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDAvatarDiagnostics.h"
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>
NSString * const BHRDPhotoSaveErrorDomain=@"com.caun.xsuixin.photo-save";
static NSDictionary *Formats(void) {
    return @{@"public.jpeg":@"jpg",@"public.png":@"png",@"com.compuserve.gif":@"gif",@"public.heic":@"heic",@"public.heif":@"heif"};
}
NSData *BHRDPhotoLibraryPayload(NSData *data) {
    NSString *type=BHRDPhotoPasteboardType(data); if (!type) return nil;
    if (Formats()[type]) return [data copy];
    CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,NULL);
    if (!source) return nil;
    if (CGImageSourceGetCount(source)!=1) { CFRelease(source); return nil; }
    NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,NULL));
    NSNumber *maximum=@(MAX([properties[(__bridge NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue],
                           [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue]));
    NSDictionary *options=@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:maximum};
    CGImageRef image=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)options); CFRelease(source);
    if (!image) return nil;
    NSMutableData *png=[NSMutableData data];
    CGImageDestinationRef destination=CGImageDestinationCreateWithData((__bridge CFMutableDataRef)png,CFSTR("public.png"),1,NULL);
    BOOL success=NO;
    if (destination) { CGImageDestinationAddImage(destination,image,NULL); success=CGImageDestinationFinalize(destination); CFRelease(destination); }
    CGImageRelease(image);
    return success && BHRDPhotoPasteboardType(png) ? [png copy] : nil;
}
static NSError *SaveError(BHRDPhotoSaveError code,NSString *message) {
    return [NSError errorWithDomain:BHRDPhotoSaveErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}
@interface BHRDPhotoSaveJob ()
@property(nonatomic) BOOL committed;
@property(nonatomic) BOOL finished;
@property(nonatomic,strong) NSData *data;
@property(nonatomic,copy) NSDictionary *info;
@property(nonatomic,copy) BOOL (^stillCurrent)(void);
@property(nonatomic,copy) void (^completion)(BOOL,NSError *);
@end
@implementation BHRDPhotoSaveJob
+ (instancetype)saveData:(NSData *)data hostInfo:(NSDictionary *)info stillCurrent:(BOOL (^)(void))stillCurrent completion:(void (^)(BOOL,NSError *))completion {
    BHRDPhotoSaveJob *job=[self new]; job.data=[data copy]; job.info=[info copy]; job.stillCurrent=stillCurrent; job.completion=completion;
    dispatch_async(dispatch_get_main_queue(),^{ [job start]; }); return job;
}
- (void)finish:(BOOL)success error:(NSError *)error {
    if (self.finished) return; self.finished=YES;
    BHRDAvatarLog(@"photo_save_result",@{@"success":@(success),@"committed":@(self.committed),@"errorDomain":error.domain ?: @"",@"errorCode":@(error.code)});
    void (^completion)(BOOL,NSError *)=self.completion; self.completion=nil; self.stillCurrent=nil; self.data=nil; self.info=nil;
    if (completion) completion(success,error);
}
- (BOOL)validateSelection {
    if (self.finished) return NO;
    if (self.stillCurrent && self.stillCurrent()) return YES;
    [self finish:NO error:SaveError(BHRDPhotoSaveCancelled,@"图片已切换或已退出全屏，保存已取消")]; return NO;
}
- (void)start {
    if (![self validateSelection]) return;
    NSString *type=BHRDPhotoPasteboardType(self.data);
    if (!type || !Formats()[type]) { [self finish:NO error:SaveError(BHRDPhotoSaveInvalidData,@"图片无效或格式不受支持")]; return; }
    id add=self.info[@"NSPhotoLibraryAddUsageDescription"], read=self.info[@"NSPhotoLibraryUsageDescription"];
    if (!([add isKindOfClass:NSString.class] && [add length]) && !([read isKindOfClass:NSString.class] && [read length])) {
        [self finish:NO error:SaveError(BHRDPhotoSaveMissingUsage,@"当前 X 未提供照片权限说明，请使用 X 自带的分享菜单保存图片")]; return;
    }
    PHAuthorizationStatus status=[PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
    if (status==PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus result) {
            dispatch_async(dispatch_get_main_queue(),^{ [self authorize:result]; });
        }];
    } else [self authorize:status];
}
- (void)authorize:(PHAuthorizationStatus)status {
    if (self.committed) return;
    if (![self validateSelection]) return;
    BHRDAvatarLog(@"photo_save_authorization",@{@"status":@(status),@"access":@"add_only"});
    if (status!=PHAuthorizationStatusAuthorized && status!=PHAuthorizationStatusLimited) {
        [self finish:NO error:SaveError(BHRDPhotoSaveDenied,@"请在系统设置中允许 X 添加照片，然后重试")]; return;
    }
    self.committed=YES;
    NSData *data=self.data; NSString *type=BHRDPhotoPasteboardType(data);
    BHRDAvatarLog(@"photo_save_committed",@{@"bytes":@(data.length),@"type":type ?: @""});
    // The selection was checked on main before this irreversible submission.
    // Keep the chosen bytes and Photos completion alive even if the viewer exits.
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        PHAssetResourceCreationOptions *options=[PHAssetResourceCreationOptions new]; options.uniformTypeIdentifier=type;
        options.originalFilename=[NSString stringWithFormat:@"XSuixin-图片-%@.%@",NSUUID.UUID.UUIDString,Formats()[type]];
        [[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypePhoto data:data options:options];
    } completionHandler:^(BOOL success,NSError *error) {
        dispatch_async(dispatch_get_main_queue(),^{
            [self finish:success error:success ? nil : (error ?: SaveError(BHRDPhotoSaveFailed,@"无法保存到照片，请检查权限和可用存储空间"))];
        });
    }];
}
- (void)cancel {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{ [self cancel]; }); return; }
    if (!self.finished && !self.committed) [self finish:NO error:SaveError(BHRDPhotoSaveCancelled,@"保存已取消")];
}
@end
