//
//  BHTwitter+UIImage.h
//  BHTwitter
//
//  Created by BandarHelal on 11/10/2021.
//

#import <UIKit/UIKit.h>

@interface UIImage (bhtwitter)
+ (UIImage *)bhtwitter_imageNamed:(NSString *)name;
@end

@implementation UIImage (bhtwitter)
+ (UIImage *)bhtwitter_imageNamed:(NSString *)name {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:@"/Library/Application Support/BHT/Ressources.bundle"]) {
        return [UIImage imageNamed:[NSString stringWithFormat:@"/Library/Application Support/BHT/Ressources.bundle/%@", name]];
    } else {
        return [UIImage imageNamed:[NSString stringWithFormat:@"Ressources.bundle/%@", name]];
    }
}
@end
