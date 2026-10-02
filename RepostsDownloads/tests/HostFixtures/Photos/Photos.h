#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, PHAuthorizationStatus) {
    PHAuthorizationStatusNotDetermined,PHAuthorizationStatusRestricted,PHAuthorizationStatusDenied,
    PHAuthorizationStatusAuthorized,PHAuthorizationStatusLimited
};
typedef NS_ENUM(NSInteger, PHAccessLevel) { PHAccessLevelAddOnly=1,PHAccessLevelReadWrite };
typedef NS_ENUM(NSInteger, PHAssetResourceType) { PHAssetResourceTypePhoto=1 };
@interface PHAssetResourceCreationOptions : NSObject
@property(nonatomic,copy) NSString *uniformTypeIdentifier;
@property(nonatomic,copy) NSString *originalFilename;
@end
@interface PHAssetCreationRequest : NSObject
+ (instancetype)creationRequestForAsset;
- (void)addResourceWithType:(PHAssetResourceType)type data:(NSData *)data options:(PHAssetResourceCreationOptions *)options;
@end
@interface PHPhotoLibrary : NSObject
+ (instancetype)sharedPhotoLibrary;
+ (PHAuthorizationStatus)authorizationStatusForAccessLevel:(PHAccessLevel)access;
+ (void)requestAuthorizationForAccessLevel:(PHAccessLevel)access handler:(void (^)(PHAuthorizationStatus))handler;
- (void)performChanges:(void (^)(void))changes completionHandler:(void (^)(BOOL,NSError *))completion;
@property(class,nonatomic) PHAuthorizationStatus fixtureStatus;
@property(class,nonatomic) PHAccessLevel fixtureAccess;
@property(class,nonatomic) NSUInteger fixtureQueries;
@property(class,nonatomic) NSUInteger fixtureRequests;
@property(class,nonatomic) NSUInteger fixtureCommits;
@property(class,nonatomic,copy) void (^fixturePermission)(PHAuthorizationStatus);
@property(class,nonatomic,copy) void (^fixtureCompletion)(BOOL,NSError *);
@property(class,nonatomic,copy) NSData *fixtureData;
@property(class,nonatomic,strong) PHAssetResourceCreationOptions *fixtureOptions;
@end
