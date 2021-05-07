//
//  BHTdownloadManager.h
//  BHT
//
//  Created by BandarHelal on 24/12/1441 AH.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "./Classes/Utility/FLEXAlert.h"
#import "TWHeaders.h"
#import "JGProgressHUD/include/JGProgressHUD.h"
#import "HBPreferences/HBPreferences.h"
#import "HBPreferences/HBButtonCell.h"
#import "HBPreferences/HBSection.h"
#import "HBPreferences/HBTwitterCell.h"
#import "HBPreferences/HBSwitchCell.h"
#import "HBPreferences/HBGithubCell.h"
#import "HBPreferences/HBLinkCell.h"

@interface BHTManager : NSObject
+ (NSString *)getDownloadingPersent:(float)per;
+ (void)cleanCache;
+ (NSString *)getVideoQuality:(NSString *)url;
+ (BOOL)isVideoCell:(T1StatusInlineActionsView *)cell;
+ (bool)isDMVideoCell:(T1InlineMediaView *)view;
+ (BOOL)doesContainDigitsOnly:(NSString *)string;
+ (void)showSettings:(UIViewController *)_self;
+ (void)showSaveVC:(NSURL *)url;
+ (void)save:(NSURL *)url;

+ (BOOL)DownloadingVideos;
+ (BOOL)DirectSave;
+ (BOOL)VoiceFeature;
+ (BOOL)voice_in_replay;
+ (BOOL)tipjar;
+ (BOOL)LikeConfirm;
+ (BOOL)TweetConfirm;
+ (BOOL)HidePromoted;
+ (BOOL)FLEX;
@end
