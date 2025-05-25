// BHAppIconItem.m
// BHTwitter
//
// Revised to hold Info.plist icon key & file list
//

#import "BHAppIconItem.h"

@implementation BHAppIconItem

- (instancetype)initWithBundleIconName:(NSString *)iconName
                        iconFileNames:(NSArray<NSString*>*)files
                         isPrimaryIcon:(BOOL)isPrimary
{
    if (self = [super init]) {
        _bundleIconName  = [iconName copy];
        _bundleIconFiles = [files copy];
        _isPrimaryIcon   = isPrimary;
    }
    return self;
}

@end
