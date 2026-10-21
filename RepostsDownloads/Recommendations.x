#import "BHRDSafety.h"
#import "BHRDPreferences.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
%group PremiumProfile
%hook T1ProfileSummaryView
- (BOOL)shouldShowGetVerifiedButton { return BHRDPreference(BHRDHidePremiumKey) ? NO : %orig; }
%end
%end
%group PremiumHome
%hook THFHomeTimelineContainerViewController
- (void)_t1_showPremiumUpsellIfNeeded { if (!BHRDPreference(BHRDHidePremiumKey)) { %orig; } }
%end
%end
%group PremiumHomeScribe
%hook THFHomeTimelineContainerViewController
- (void)_t1_showPremiumUpsellIfNeededWithScribing:(BOOL)scribe { if (!BHRDPreference(BHRDHidePremiumKey)) { %orig(scribe); } }
%end
%end
// Upstream iPad recommendation sidebar surface. Restore our changes when disabled.
static char SidebarStateKey;
%group RecommendationSidebar
%hook UIView
- (void)didMoveToWindow {
    %orig;
    NSArray *previous = objc_getAssociatedObject(self, &SidebarStateKey);
    BOOL hide = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad && BHRDPreference(BHRDHideWhoKey) && [self.accessibilityIdentifier isEqual:@"T1UserRecommendationsViewController"];
    if (hide) {
        if (!previous) objc_setAssociatedObject(self, &SidebarStateKey, @[@(self.hidden), @(self.userInteractionEnabled)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.hidden = YES; self.userInteractionEnabled = NO;
    } else if (previous) {
        self.hidden = [previous[0] boolValue]; self.userInteractionEnabled = [previous[1] boolValue];
        objc_setAssociatedObject(self, &SidebarStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
%end
%end
%ctor {
    if (!BHRDFeatureHooksEnabledAtLaunch()) return;
    %init(RecommendationSidebar);
    if (class_getInstanceMethod(objc_getClass("T1ProfileSummaryView"), @selector(shouldShowGetVerifiedButton))) { %init(PremiumProfile); }
    if (class_getInstanceMethod(objc_getClass("THFHomeTimelineContainerViewController"), @selector(_t1_showPremiumUpsellIfNeeded))) { %init(PremiumHome); }
    if (class_getInstanceMethod(objc_getClass("THFHomeTimelineContainerViewController"), @selector(_t1_showPremiumUpsellIfNeededWithScribing:))) { %init(PremiumHomeScribe); }
}
