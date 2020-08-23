//
//  BHTdownloadManager.h
//  BHT
//
//  Created by BandarHelal on 24/12/1441 AH.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "FLEXAlert.h"
#import "TWHeaders.h"
#import "JGProgressHUD/include/JGProgressHUD.h"
#import "HBPreferences/HBPreferences.h"
#import "HBPreferences/HBButtonCell.h"
#import "HBPreferences/HBSection.h"
#import "HBPreferences/HBTwitterCell.h"
#import "HBPreferences/HBSwitchCell.h"
#import "HBPreferences/HBGithubCell.h"
#import "HBPreferences/HBLinkCell.h"
#import "FCFileManager.h"

@interface BHTdownloadManager : NSObject
+ (void)DownloadVideoWithURL:(NSString *)url completionHandler:(void (^)(NSURL *filePath, NSError *error))completionHandler;
+ (BOOL)isVideoCell:(T1StatusInlineActionsView *)cell;
+ (BOOL)isDMVideoCell:(T1InlineMediaView *)cell;
+ (BOOL)doesContainDigitsOnly:(NSString *)string;
+ (void)showSettings:(UIViewController *)_self;
+ (void)showSaveingViewController:(NSURL *)url;
+ (BOOL)isLTR;
@end
