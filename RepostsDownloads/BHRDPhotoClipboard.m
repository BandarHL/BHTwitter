#import "BHRDPhotoClipboard.h"
#import "BHRDPhotoCopyData.h"
#import <UIKit/UIKit.h>
BOOL BHRDWritePhotoClipboard(NSData *data, BOOL temporary) {
    NSString *type=BHRDPhotoPasteboardType(data);
    if (!type) return NO;
    NSDictionary *options=temporary ? @{UIPasteboardOptionLocalOnly:@YES,UIPasteboardOptionExpirationDate:[NSDate dateWithTimeIntervalSinceNow:600]} : @{};
    [UIPasteboard.generalPasteboard setItems:@[@{type:data}] options:options];
    return YES;
}
