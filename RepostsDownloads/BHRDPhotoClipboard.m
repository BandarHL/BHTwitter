#import "BHRDPhotoClipboard.h"
#import "BHRDPhotoCopyData.h"
#import "BHRDPreferences.h"
#import <UIKit/UIKit.h>
static NSDictionary *PhotoClipboardOptions(BOOL temporary) {
    NSMutableDictionary *options=[NSMutableDictionary dictionary];
    if (temporary || BHRDPreference(BHRDCopyLocalOnlyKey)) options[UIPasteboardOptionLocalOnly]=@YES;
    if (temporary || BHRDPreference(BHRDCopyExpiresKey)) options[UIPasteboardOptionExpirationDate]=[NSDate dateWithTimeIntervalSinceNow:600];
    return options;
}
BOOL BHRDWritePhotoClipboard(NSData *data, BOOL temporary) {
    NSString *type=BHRDPhotoPasteboardType(data);
    if (!type) return NO;
    [UIPasteboard.generalPasteboard setItems:@[@{type:data}] options:PhotoClipboardOptions(temporary)];
    return YES;
}
BOOL BHRDWritePhotoLinkClipboard(NSURL *url) {
    NSURL *original=BHRDOriginalPhotoURL(url); if (!original) return NO;
    [UIPasteboard.generalPasteboard setItems:@[@{@"public.utf8-plain-text":original.absoluteString}] options:PhotoClipboardOptions(NO)];
    return YES;
}
