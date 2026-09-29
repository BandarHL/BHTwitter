#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../BHRDAdRuntime.h"
#import "../BHRDAdFilter.h"
#import "../BHRDPreferences.h"
#import "../BHRDAvatarDiagnostics.h"
@interface FeatureBase245 : NSObject
- (BOOL)boolForKey:(NSString *)key;
- (BOOL)unsafePeekBoolForKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (NSInteger)unsafePeekIntegerForKey:(NSString *)key;
- (NSNumber *)numberForKey:(NSString *)key;
- (id)rawValueForKey:(NSString *)key;
- (BOOL)hasNonDefaultValueForKey:(NSString *)key;
@end
@implementation FeatureBase245
- (BOOL)boolForKey:(NSString *)key { return YES; }
- (BOOL)unsafePeekBoolForKey:(NSString *)key { return YES; }
- (NSInteger)integerForKey:(NSString *)key { return 7; }
- (NSInteger)unsafePeekIntegerForKey:(NSString *)key { return 7; }
- (NSNumber *)numberForKey:(NSString *)key { return @7; }
- (id)rawValueForKey:(NSString *)key { return [key hasSuffix:@"ad_unit_id"] ? @"/unit" : @YES; }
- (BOOL)hasNonDefaultValueForKey:(NSString *)key { return NO; }
@end
@interface TPSTwitterFeatureSwitches : FeatureBase245 @end
@implementation TPSTwitterFeatureSwitches @end
@interface TFSFeatureSwitches : FeatureBase245 @end
@implementation TFSFeatureSwitches @end
@interface TFSInstrumentedFeatureSwitches : FeatureBase245 @end
@implementation TFSInstrumentedFeatureSwitches @end
@interface Adapter245 : NSObject
- (BOOL)showSSPAdWhenNoPromotedMetadata;
@end
@implementation Adapter245
- (BOOL)showSSPAdWhenNoPromotedMetadata { return YES; }
@end
@interface WrongSignature245 : NSObject
- (id)showSSPAdWhenNoPromotedMetadata;
@end
@implementation WrongSignature245
- (id)showSSPAdWhenNoPromotedMetadata { return @"keep"; }
@end
@interface GADAdLoader : NSObject
@property(nonatomic,weak) id delegate;
@property(nonatomic) NSUInteger requests;
- (void)loadRequest:(id)request;
- (void)loadWithAdResponseString:(NSString *)response;
@end
@implementation GADAdLoader
- (void)loadRequest:(id)request { self.requests++; }
- (void)loadWithAdResponseString:(NSString *)response { self.requests++; }
@end
@interface Delegate245 : NSObject
@property(nonatomic) NSUInteger failures;
@property(nonatomic) NSUInteger finished;
@property(nonatomic,strong) NSError *error;
- (void)adLoader:(id)loader didFailToReceiveAdWithError:(NSError *)error;
- (void)adLoaderDidFinishLoading:(id)loader;
@end
@implementation Delegate245
- (void)adLoader:(id)loader didFailToReceiveAdWithError:(NSError *)error { self.failures++; self.error=error; }
- (void)adLoaderDidFinishLoading:(id)loader { self.finished++; }
@end
static NSUInteger checks,hooks;
static void Check(BOOL value,NSString *label) { checks++; if (!value) { NSLog(@"FAIL: %@",label); exit(1); } }
static void Hook(Class cls,SEL sel,IMP replacement,IMP *original) {
    Method method=class_getInstanceMethod(cls,sel); *original=method_getImplementation(method);
    class_replaceMethod(cls,sel,replacement,method_getTypeEncoding(method)); hooks++;
}
static void Drain(void) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.03]]; }
int main(void) { @autoreleasepool {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults; id prior=[defaults objectForKey:BHRDHideAdsKey];
    [defaults setBool:YES forKey:BHRDHideAdsKey];
    BHRDInstallAdRuntimeHooks(Hook); NSUInteger installed=hooks; BHRDInstallAdRuntimeHooks(Hook);
    Check(hooks==installed && hooks==24,@"Three switch classes, two SDK entrances and SSP getter install exactly once");
    for (Class cls in @[TPSTwitterFeatureSwitches.class,TFSFeatureSwitches.class,TFSInstrumentedFeatureSwitches.class]) {
        FeatureBase245 *switches=[cls new];
        Check(![switches boolForKey:@"ssp_ads_immersive"],@"SSP bool read disabled");
        Check(![switches unsafePeekBoolForKey:@"video_configurations_dynamic_ad_enabled"],@"Dynamic ad unsafe bool read disabled");
        Check([switches integerForKey:@"ssp_ads_immersive"]==0,@"Integer boolean bridge disabled");
        Check([switches unsafePeekIntegerForKey:@"ssp_ads_home_enabled"]==0,@"Unsafe integer boolean bridge disabled");
        Check([[switches numberForKey:@"ssp_ads_tweet_details"] isEqual:@NO],@"Number boolean bridge disabled");
        Check([[switches rawValueForKey:@"ssp_ads_immersive"] isEqual:@NO],@"Raw boolean bridge disabled");
        Check([switches hasNonDefaultValueForKey:@"ssp_ads_immersive"],@"Override presence consistent with returned flag");
        Check([[switches rawValueForKey:@"ssp_ads_google_dsp_immersive_ad_unit_id"] isEqual:@""],@"Ad unit remains a string");
        Check([switches integerForKey:@"ssp_ads_spacing"]==7,@"Spacing is never zeroed");
        Check([switches boolForKey:@"ordinary_feature"] && [[switches numberForKey:@"ordinary_feature"] isEqual:@7],@"Unrelated features unchanged");
    }
    Check([[FeatureBase245 new] boolForKey:@"ssp_ads_immersive"],@"Inherited hook does not modify untargeted base class");
    Check(![[Adapter245 new] showSSPAdWhenNoPromotedMetadata],@"No-metadata SSP display gate disabled");
    Check([[[WrongSignature245 new] showSSPAdWhenNoPromotedMetadata] isEqual:@"keep"],@"Non-boolean ABI is rejected");
    Check(!BHRDAdSwitchReplacement(@"ssp_ads_immersive",@"unexpected string",BHRDAdReadRaw,YES),@"Wrong raw type preserved");
    Check(!BHRDAdSwitchReplacement(@"ssp_ads_google_dsp_immersive_ad_unit_id",@{},BHRDAdReadRaw,YES),@"Structured ad-unit config is never replaced with boolean or string");
    GADAdLoader *loader=[GADAdLoader new]; Delegate245 *delegate=[Delegate245 new]; loader.delegate=delegate;
    [loader loadRequest:nil]; Check(loader.requests==0 && delegate.failures==0,@"Request blocked with asynchronous completion");
    Drain(); Check(delegate.failures==1 && delegate.finished==1 && delegate.error.code==1,@"No-fill failure and batch completion delivered");
    [loader loadWithAdResponseString:@"not logged"]; Drain();
    Check(loader.requests==0 && delegate.failures==2,@"Cached-response SDK load also blocked");
    [loader loadRequest:nil]; [loader loadRequest:nil]; Drain();
    Check(delegate.failures==3,@"Newer blocked request supersedes pending callback");
    [loader loadRequest:nil]; Delegate245 *replacement=[Delegate245 new]; loader.delegate=replacement; Drain();
    Check(delegate.failures==3 && replacement.failures==0,@"Delegate replacement cannot receive old request callback");
    [loader loadRequest:nil]; [defaults setBool:NO forKey:BHRDHideAdsKey]; [loader loadRequest:nil]; Drain();
    Check(loader.requests==1 && replacement.failures==0,@"Disabled preference restores SDK and invalidates obsolete blocked callback");
    Check([[TFSFeatureSwitches new] boolForKey:@"ssp_ads_immersive"] && [[Adapter245 new] showSSPAdWhenNoPromotedMetadata],@"Disabling preference restores original switch and SSP values");
    for (NSString *name in @[@"TwitterURT.URTTimelineGoogleNativeAdViewModel",@"_TtC14T1TwitterSwift35ImmersiveGoogleNativeAdCardViewModel"]) {
        Class cls=objc_allocateClassPair(NSObject.class,name.UTF8String,0); objc_registerClassPair(cls);
        id ad=[cls new]; NSDictionary *normal=@{@"statusID":@1}, *cursor=@{@"entryId":@"cursor-bottom",@"cursorType":@"Bottom"};
        Check(BHRDIsPromotedModel(ad),@"Native SSP model identified without promotion metadata");
        Check([BHRDSectionsByRemovingAds(@[@[normal,ad,cursor]]) isEqual:@[@[normal,cursor]]],@"Hydrated SSP row removed while neighbors and cursor retain order");
    }
    NSDictionary *clean=@{@"entries":@[]}; NSData *data=[NSJSONSerialization dataWithJSONObject:clean options:0 error:NULL]; BOOL changed=YES;
    Check(BHRDFilterAdResponse(clean,data,YES,&changed)==clean && !changed,@"Marker-free JSON preserved, diagnostic call still runs");
    if (prior) [defaults setObject:prior forKey:BHRDHideAdsKey]; else [defaults removeObjectForKey:BHRDHideAdsKey];
#if BHRD_AVATAR_DIAGNOSTICS
    BHRDAvatarDiagnosticFlush();
#endif
    NSLog(@"PASS: %lu SSP policy, installed runtime hook and SDK lifecycle checks",(unsigned long)checks);
} return 0; }
