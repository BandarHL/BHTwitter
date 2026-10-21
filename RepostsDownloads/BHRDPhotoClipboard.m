#import "BHRDPhotoClipboard.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDPreferences.h"
#import "BHRDAvatarDiagnostics.h"
#import <UIKit/UIKit.h>
static NSDictionary *PhotoClipboardOptions(BOOL temporary) {
    NSMutableDictionary *options=[NSMutableDictionary dictionary];
    if (temporary || BHRDPreference(BHRDCopyLocalOnlyKey)) options[UIPasteboardOptionLocalOnly]=@YES;
    if (temporary || BHRDPreference(BHRDCopyExpiresKey)) options[UIPasteboardOptionExpirationDate]=[NSDate dateWithTimeIntervalSinceNow:600];
    return options;
}
// Only inspect our just-written item. A rejected write must not be mistaken
// for success merely because an older image remains on the pasteboard.
static BOOL ClipboardResult(BOOL success, NSString *reason, BOOL image) {
    (void)reason; (void)image;
    BHRDAvatarLog(@"photo_clipboard_result",@{@"success":@(success),@"reason":reason,@"image":@(image)});
    return success;
}
BOOL BHRDWritePhotoClipboard(NSData *data, BOOL temporary) {
    NSString *type=BHRDPhotoPasteboardType(data);
    if (!type) return ClipboardResult(NO,@"invalid_image_payload",YES);
    @try {
        UIPasteboard *board=UIPasteboard.generalPasteboard;
        NSInteger before=board.changeCount;
        [board setItems:@[@{type:data}] options:PhotoClipboardOptions(temporary)];
        NSInteger written=board.changeCount;
        if (written==before) return ClipboardResult(NO,@"write_not_observed",YES);
        if (![board containsPasteboardTypes:@[type]] || !board.hasImages)
            return ClipboardResult(NO,@"image_type_missing",YES);
        NSData *stored=[board dataForPasteboardType:type];
        if (board.changeCount!=written || ![stored isEqualToData:data])
            return ClipboardResult(NO,@"image_content_changed",YES);
        return ClipboardResult(YES,@"image_write_verified",YES);
    } @catch (__unused NSException *exception) {
        return ClipboardResult(NO,@"pasteboard_exception",YES);
    }
}
BOOL BHRDWritePhotoLinkClipboard(NSURL *url) {
    NSURL *original=BHRDOriginalPhotoURL(url); if (!original) return NO;
    @try {
        UIPasteboard *board=UIPasteboard.generalPasteboard;
        NSInteger before=board.changeCount;
        [board setItems:@[@{@"public.utf8-plain-text":original.absoluteString}] options:PhotoClipboardOptions(NO)];
        NSInteger written=board.changeCount;
        BOOL matches=written!=before && [board.string isEqual:original.absoluteString];
        BOOL success=matches && board.changeCount==written;
        return ClipboardResult(success,success ? @"link_write_verified" : @"link_write_unverified",NO);
    } @catch (__unused NSException *exception) {
        return ClipboardResult(NO,@"pasteboard_exception",NO);
    }
}
