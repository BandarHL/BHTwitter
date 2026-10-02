#import <Photos/Photos.h>
@implementation PHAssetResourceCreationOptions @end
@implementation PHAssetCreationRequest
+ (instancetype)creationRequestForAsset { return [self new]; }
- (void)addResourceWithType:(PHAssetResourceType)type data:(NSData *)data options:(PHAssetResourceCreationOptions *)options {
    NSCAssert(type==PHAssetResourceTypePhoto,@"Must add a photo"); PHPhotoLibrary.fixtureData=data; PHPhotoLibrary.fixtureOptions=options;
}
@end
static PHAuthorizationStatus status;
static PHAccessLevel photoAccess;
static NSUInteger queries,requests,commits;
static void (^permission)(PHAuthorizationStatus);
static void (^completion)(BOOL,NSError *);
static NSData *savedData;
static PHAssetResourceCreationOptions *savedOptions;
@implementation PHPhotoLibrary
+ (instancetype)sharedPhotoLibrary { static PHPhotoLibrary *library; static dispatch_once_t once; dispatch_once(&once,^{ library=[self new]; }); return library; }
+ (PHAuthorizationStatus)authorizationStatusForAccessLevel:(PHAccessLevel)value { photoAccess=value; queries++; return status; }
+ (void)requestAuthorizationForAccessLevel:(PHAccessLevel)value handler:(void (^)(PHAuthorizationStatus))handler { photoAccess=value; requests++; permission=[handler copy]; }
- (void)performChanges:(void (^)(void))changes completionHandler:(void (^)(BOOL,NSError *))handler { commits++; completion=[handler copy]; changes(); }
+ (PHAuthorizationStatus)fixtureStatus { return status; }
+ (void)setFixtureStatus:(PHAuthorizationStatus)value { status=value; }
+ (PHAccessLevel)fixtureAccess { return photoAccess; }
+ (void)setFixtureAccess:(PHAccessLevel)value { photoAccess=value; }
+ (NSUInteger)fixtureQueries { return queries; }
+ (void)setFixtureQueries:(NSUInteger)value { queries=value; }
+ (NSUInteger)fixtureRequests { return requests; }
+ (void)setFixtureRequests:(NSUInteger)value { requests=value; }
+ (NSUInteger)fixtureCommits { return commits; }
+ (void)setFixtureCommits:(NSUInteger)value { commits=value; }
+ (void (^)(PHAuthorizationStatus))fixturePermission { return permission; }
+ (void)setFixturePermission:(void (^)(PHAuthorizationStatus))value { permission=[value copy]; }
+ (void (^)(BOOL,NSError *))fixtureCompletion { return completion; }
+ (void)setFixtureCompletion:(void (^)(BOOL,NSError *))value { completion=[value copy]; }
+ (NSData *)fixtureData { return savedData; }
+ (void)setFixtureData:(NSData *)value { savedData=[value copy]; }
+ (PHAssetResourceCreationOptions *)fixtureOptions { return savedOptions; }
+ (void)setFixtureOptions:(PHAssetResourceCreationOptions *)value { savedOptions=value; }
@end
