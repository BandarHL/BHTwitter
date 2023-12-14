//
//  BHTBundle.m
//  BHTwitter
//
//  Created by BandarHelal on 07/08/2022.
//

#import "BHTBundle.h"

@interface BHTBundle ()
@property (nonatomic, strong) NSBundle *mainBundle;
@end

@implementation BHTBundle
+ (instancetype)sharedBundle {
    static BHTBundle *sharedBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *bundlePath = [NSURL new];
        if ([fileManager fileExistsAtPath:@"/Library/Application Support/BHT/BHTwitter.bundle"]) {
            bundlePath = [NSURL fileURLWithPath:@"/Library/Application Support/BHT/BHTwitter.bundle"];
        } else if ([fileManager fileExistsAtPath:@"/var/jb/Library/Application Support/BHT/BHTwitter.bundle"]) {
            bundlePath = [NSURL fileURLWithPath:@"/var/jb/Library/Application Support/BHT/BHTwitter.bundle"];
        } else {
            bundlePath = [[NSBundle mainBundle] URLForResource:@"BHTwitter" withExtension:@"bundle"];
        }
        
        sharedBundle = [[self alloc] initWithBundlePath:bundlePath];
    });
    return sharedBundle;
}
- (instancetype)initWithBundlePath:(NSURL *)bundlePath {
    if (self = [super init]) {
        self.mainBundle = [NSBundle bundleWithPath:[bundlePath path]];
    }
    
    return self;
}

- (NSString *)localizedStringForKey:(NSString *)key {
    return [self.mainBundle localizedStringForKey:key value:key table:nil];
}
- (NSURL *)pathForFile:(NSString *)fileName {
    return [self.mainBundle URLForResource:fileName withExtension:nil];
}
- (NSString *)BHTwitterVersion {
    return [self.mainBundle objectForInfoDictionaryKey:@"BHTVersion"];
}
@end
