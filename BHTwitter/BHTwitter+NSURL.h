//
//  BHTwitter+NSURL.h
//  BHTwitter
//
//  Created by BandarHelal on 11/10/2021.
//

#import <UIKit/UIKit.h>

@interface NSURL (bhtwitter)
+ (NSURL *)bhtwitter_fileURLWithPath:(NSString *)path;
@end

@implementation NSURL (bhtwitter)
+ (NSURL *)bhtwitter_fileURLWithPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:@"/Library/Application Support/BHT/Ressources.bundle"]) {
        return [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Library/Application Support/BHT/Ressources.bundle/%@", path]];
    } else {
        NSURL *ressourcesBundle = [[NSBundle mainBundle] URLForResource:@"Ressources" withExtension:@"bundle"];
//        return [NSURL fileURLWithPath:[NSString stringWithFormat:@"Ressources.bundle/%@", path]];
        return [ressourcesBundle URLByAppendingPathComponent:path];
    }
}
@end
