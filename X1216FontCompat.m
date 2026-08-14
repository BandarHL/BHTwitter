#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// X 12.16 removed TAEStandardFontGroup, but BHTwitter's legacy download menu
// still uses it to obtain the title font. Recreate only the tiny interface
// BHTwitter needs so the existing TFN menu/download pipeline can keep working.

static id BHTCompatSharedFontGroup(id self, SEL _cmd) {
    static id shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

static UIFont *BHTCompatHeadline2BoldFont(id self, SEL _cmd) {
    // Closest stable UIKit replacement for the removed Twitter font provider.
    return [UIFont boldSystemFontOfSize:17.0];
}

__attribute__((constructor)) static void BHTInstallX1216FontCompat(void) {
    if (objc_getClass("TAEStandardFontGroup")) {
        return;
    }

    Class compatClass = objc_allocateClassPair([NSObject class], "TAEStandardFontGroup", 0);
    if (!compatClass) {
        return;
    }

    Class metaClass = object_getClass(compatClass);

    class_addMethod(metaClass,
                    NSSelectorFromString(@"sharedFontGroup"),
                    (IMP)BHTCompatSharedFontGroup,
                    "@@:");

    class_addMethod(compatClass,
                    NSSelectorFromString(@"headline2BoldFont"),
                    (IMP)BHTCompatHeadline2BoldFont,
                    "@@:");

    objc_registerClassPair(compatClass);
    NSLog(@"[BHTwitter][X12.16] Installed TAEStandardFontGroup compatibility shim");
}
