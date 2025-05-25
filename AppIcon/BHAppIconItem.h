// BHAppIconItem.h
// BHTwitter
//
// Revised to hold Info.plist icon key & file list
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BHAppIconItem : NSObject

/// the key used in Info.plist (and passed to setAlternateIconName:)
@property (nonatomic, copy, readonly) NSString *bundleIconName;

/// the array of filenames (without “.png”) from CFBundleIconFiles
@property (nonatomic, copy, readonly) NSArray<NSString*> *bundleIconFiles;

/// is this the primary (default) icon?
@property (nonatomic, assign, readonly) BOOL isPrimaryIcon;

/// Designated initializer
- (instancetype)initWithBundleIconName:(NSString *)iconName
                        iconFileNames:(NSArray<NSString*>*)files
                         isPrimaryIcon:(BOOL)isPrimary;

@end

NS_ASSUME_NONNULL_END
