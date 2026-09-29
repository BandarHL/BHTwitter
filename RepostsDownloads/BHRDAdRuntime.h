#import <Foundation/Foundation.h>
#import <objc/runtime.h>
typedef NS_ENUM(NSUInteger, BHRDAdReadKind) {
    BHRDAdReadBool, BHRDAdReadInteger, BHRDAdReadNumber, BHRDAdReadRaw, BHRDAdReadHasOverride
};
id BHRDAdSwitchReplacement(NSString *key, id original, BHRDAdReadKind kind, BOOL enabled);
typedef void (*BHRDAdMessageHook)(Class cls, SEL selector, IMP replacement, IMP *original);
void BHRDInstallAdRuntimeHooks(BHRDAdMessageHook hook);
