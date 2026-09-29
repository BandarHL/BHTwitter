#import "BHRDAdRuntime.h"
#import "BHRDPreferences.h"
#import "BHRDAvatarDiagnostics.h"
#import <objc/message.h>
#import <dlfcn.h>
#import <string.h>

static BOOL AdKey(NSString *key) {
    return [key isKindOfClass:NSString.class] && ([key hasPrefix:@"ssp_ads_"] || [key hasPrefix:@"ad_formats_"] ||
        [key hasPrefix:@"ad_"] || [key containsString:@"_ads_"] || [key isEqual:@"ads_enabled"] ||
        [key isEqual:@"video_configurations_dynamic_ad_enabled"]);
}
static BOOL UnitKey(NSString *key) { return [key hasPrefix:@"ssp_ads_"] && [key hasSuffix:@"_ad_unit_id"]; }
static BOOL BooleanKey(NSString *key) {
    return AdKey(key) && ([key hasSuffix:@"_enabled"] || [key isEqual:@"ssp_ads_immersive"] || [key isEqual:@"ssp_ads_tweet_details"]);
}
id BHRDAdSwitchReplacement(NSString *key, id original, BHRDAdReadKind kind, BOOL enabled) {
    if (!enabled || !AdKey(key)) return nil;
    if (kind==BHRDAdReadHasOverride) return BooleanKey(key) || UnitKey(key) ? @YES : nil;
    if (kind==BHRDAdReadRaw && UnitKey(key)) return !original || [original isKindOfClass:NSString.class] ? @"" : nil;
    if (UnitKey(key)) return nil;
    if (kind==BHRDAdReadBool) return @NO;
    // Never zero spacing, timeouts, sizes or other numeric configuration.
    if (!BooleanKey(key)) return nil;
    if (kind==BHRDAdReadInteger) return @0;
    return !original || [original isKindOfClass:NSNumber.class] ? @NO : nil;
}
static NSMethodSignature *Signature(Class cls, SEL selector, NSUInteger arguments) {
    Method method=class_getInstanceMethod(cls,selector); if (!method) return nil;
    NSMethodSignature *sig=[NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    return sig.numberOfArguments==arguments ? sig : nil;
}
static BOOL BooleanReturn(NSMethodSignature *sig) { return sig && (sig.methodReturnType[0]=='B' || sig.methodReturnType[0]=='c'); }
static id Object(id object, SEL selector) {
    NSMethodSignature *sig=Signature([object class],selector,2);
    return sig && sig.methodReturnType[0]=='@' ? ((id(*)(id,SEL))objc_msgSend)(object,selector) : nil;
}
static void LogRead(id object,SEL selector,NSString *key,id original,id replacement) {
    if (!AdKey(key)) return;
#if BHRD_AVATAR_DIAGNOSTICS
    // Keep default-on diagnostics cheap even if a flag is read every frame.
    static NSMutableDictionary *samples; static dispatch_once_t once;
    dispatch_once(&once,^{ samples=[NSMutableDictionary dictionary]; });
    NSString *sampleKey=[NSString stringWithFormat:@"%@/%@/%@/%d",NSStringFromClass([object class]),NSStringFromSelector(selector),key,replacement!=nil];
    @synchronized(samples) {
        NSArray *sample=samples[sampleKey]; NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;
        NSUInteger count=(sample && now-[sample[0] doubleValue]<60) ? [sample[1] unsignedIntegerValue] : 0;
        if (count>=8) return;
        if (samples.count>=512 && !sample) [samples removeAllObjects];
        samples[sampleKey]=@[(count ? sample[0] : @(now)),@(count+1)];
    }
#endif
    BHRDAvatarLog(@"ad_switch_read",@{@"class":NSStringFromClass([object class]),@"selector":NSStringFromSelector(selector),@"key":key,
        @"originalType":original ? NSStringFromClass([original class]) : @"nil",@"overridden":@(replacement!=nil),
        @"result":replacement ? ([replacement isKindOfClass:NSString.class] ? @"empty_string" : [replacement stringValue]) : @"unchanged"});
}
static char PendingGoogleRequestKey;
static BOOL FailureDelegate(id delegate) {
    NSMethodSignature *sig=Signature([delegate class],NSSelectorFromString(@"adLoader:didFailToReceiveAdWithError:"),4);
    return sig && sig.methodReturnType[0]=='v' && [sig getArgumentTypeAtIndex:2][0]=='@' && [sig getArgumentTypeAtIndex:3][0]=='@';
}
static void BlockGoogleRequest(id loader) {
    id delegate=Object(loader,NSSelectorFromString(@"delegate")); NSString *token=NSUUID.UUID.UUIDString;
    objc_setAssociatedObject(loader,&PendingGoogleRequestKey,token,OBJC_ASSOCIATION_COPY_NONATOMIC);
    BHRDAvatarLog(@"google_ad_request_blocked",@{@"class":NSStringFromClass([loader class]),@"canNotify":@(FailureDelegate(delegate))});
    __weak id weakLoader=loader, weakDelegate=delegate;
    dispatch_async(dispatch_get_main_queue(),^{
        id current=weakLoader, target=weakDelegate;
        if (!current || ![objc_getAssociatedObject(current,&PendingGoogleRequestKey) isEqual:token] ||
            Object(current,NSSelectorFromString(@"delegate"))!=target || !FailureDelegate(target)) return;
        NSString *domain=@"com.google.admob";
        NSString * __unsafe_unretained *symbol=(NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT,"GADErrorDomain");
        if (symbol && [*symbol isKindOfClass:NSString.class]) domain=*symbol;
        NSError *error=[NSError errorWithDomain:domain code:1 userInfo:@{NSLocalizedDescriptionKey:@"Native advertising disabled by X Suixin"}];
        ((void(*)(id,SEL,id,id))objc_msgSend)(target,NSSelectorFromString(@"adLoader:didFailToReceiveAdWithError:"),current,error);
        // A delegate may start a new request during failure. Never finish it.
        NSMethodSignature *finish=Signature([target class],NSSelectorFromString(@"adLoaderDidFinishLoading:"),3);
        if ([objc_getAssociatedObject(current,&PendingGoogleRequestKey) isEqual:token] && finish &&
            finish.methodReturnType[0]=='v' && [finish getArgumentTypeAtIndex:2][0]=='@')
            ((void(*)(id,SEL,id))objc_msgSend)(target,NSSelectorFromString(@"adLoaderDidFinishLoading:"),current);
        BHRDAvatarLog(@"google_ad_no_fill",@{@"class":NSStringFromClass([current class]),@"errorCode":@1});
    });
}
void BHRDInstallAdRuntimeHooks(BHRDAdMessageHook hook) {
    if (!hook) return;
    static NSMutableSet *installed;
    @synchronized(NSClassFromString(@"NSUserDefaults")) {
        if (!installed) installed=[NSMutableSet set];
        // Instrumented switches are optional compatibility coverage. Guard each ABI.
        for (NSString *name in @[@"TPSTwitterFeatureSwitches",@"TFSFeatureSwitches",@"TFSInstrumentedFeatureSwitches"]) {
            Class cls=NSClassFromString(name); if (!cls) continue;
            for (NSString *method in @[@"boolForKey:",@"unsafePeekBoolForKey:",@"integerForKey:",@"unsafePeekIntegerForKey:",@"numberForKey:",@"rawValueForKey:",@"hasNonDefaultValueForKey:"]) {
                SEL sel=NSSelectorFromString(method); NSString *key=[name stringByAppendingString:method];
                NSMethodSignature *sig=Signature(cls,sel,3);
                if (!sig || [sig getArgumentTypeAtIndex:2][0]!='@' || [installed containsObject:key]) continue;
                BOOL has=[method isEqual:@"hasNonDefaultValueForKey:"];
                BOOL boolean=[method containsString:@"Bool"] || [method isEqual:@"boolForKey:"] || has;
                BOOL integer=[method containsString:@"Integer"] || [method isEqual:@"integerForKey:"];
                BHRDAdReadKind kind=has ? BHRDAdReadHasOverride : boolean ? BHRDAdReadBool : integer ? BHRDAdReadInteger : [method isEqual:@"numberForKey:"] ? BHRDAdReadNumber : BHRDAdReadRaw;
                __block IMP original=NULL; IMP replacement=NULL;
                if (boolean && BooleanReturn(sig)) replacement=imp_implementationWithBlock(^BOOL(id object,NSString *feature) {
                    BOOL result=((BOOL(*)(id,SEL,id))original)(object,sel,feature);
                    id value=BHRDAdSwitchReplacement(feature,@(result),kind,BHRDPreference(BHRDHideAdsKey));
                    LogRead(object,sel,feature,@(result),value); return value ? [value boolValue] : result;
                });
                else if (integer && strcmp(sig.methodReturnType,@encode(NSInteger))==0) replacement=imp_implementationWithBlock(^NSInteger(id object,NSString *feature) {
                    NSInteger result=((NSInteger(*)(id,SEL,id))original)(object,sel,feature);
                    id value=BHRDAdSwitchReplacement(feature,@(result),kind,BHRDPreference(BHRDHideAdsKey));
                    LogRead(object,sel,feature,@(result),value); return value ? [value integerValue] : result;
                });
                else if (!boolean && !integer && sig.methodReturnType[0]=='@') replacement=imp_implementationWithBlock(^id(id object,NSString *feature) {
                    id result=((id(*)(id,SEL,id))original)(object,sel,feature);
                    id value=BHRDAdSwitchReplacement(feature,result,kind,BHRDPreference(BHRDHideAdsKey));
                    LogRead(object,sel,feature,result,value); return value ?: result;
                });
                if (replacement) { hook(cls,sel,replacement,&original); [installed addObject:key]; }
            }
        }
        Class loader=NSClassFromString(@"GADAdLoader");
        for (NSString *method in @[@"loadRequest:",@"loadWithAdResponseString:"]) {
            SEL sel=NSSelectorFromString(method); NSString *key=[@"GADAdLoader" stringByAppendingString:method];
            NSMethodSignature *sig=Signature(loader,sel,3);
            if (!sig || sig.methodReturnType[0]!='v' || [sig getArgumentTypeAtIndex:2][0]!='@' || [installed containsObject:key]) continue;
            __block IMP original=NULL;
            IMP replacement=imp_implementationWithBlock(^(id object,id request) {
                if (BHRDPreference(BHRDHideAdsKey)) { BlockGoogleRequest(object); return; }
                objc_setAssociatedObject(object,&PendingGoogleRequestKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                ((void(*)(id,SEL,id))original)(object,sel,request);
            });
            hook(loader,sel,replacement,&original); [installed addObject:key];
        }
        unsigned count=0; Class *classes=objc_copyClassList(&count); NSMutableArray *adClasses=[NSMutableArray array];
        SEL selector=NSSelectorFromString(@"showSSPAdWhenNoPromotedMetadata");
        for (unsigned i=0;i<count;i++) {
            Class cls=classes[i]; NSString *name=NSStringFromClass(cls);
            if ([name containsString:@"GoogleNativeAd"] || [name containsString:@"ImmersiveGoogle"] || [name containsString:@"AdManager"]) [adClasses addObject:name];
            NSMethodSignature *sig=Signature(cls,selector,2);
            if (!BooleanReturn(sig) || class_getMethodImplementation(cls,selector)==class_getMethodImplementation(class_getSuperclass(cls),selector)) continue;
            NSString *key=[name stringByAppendingString:NSStringFromSelector(selector)]; if ([installed containsObject:key]) continue;
            __block IMP original=NULL;
            IMP replacement=imp_implementationWithBlock(^BOOL(id object) {
                BOOL result=((BOOL(*)(id,SEL))original)(object,selector);
                return BHRDPreference(BHRDHideAdsKey) ? NO : result;
            });
            hook(cls,selector,replacement,&original); [installed addObject:key];
        }
        free(classes);
        BHRDAvatarLog(@"ad_runtime_inventory",@{@"classes":adClasses,@"hooks":installed.allObjects});
    }
}
