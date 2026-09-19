#import "BHRDAdPresentation.h"
#import "BHRDAdFilter.h"
#import "BHRDModelAccess.h"
#import "BHRDPreferences.h"
#import <objc/runtime.h>
static BOOL Excluded(UIView *view) {
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    for (NSString *part in @[@"tweettext",@"statustext",@"richtext",@"textview",@"quote",@"username",@"author",@"inlineactions",@"bhrd"]) if ([name containsString:part]) return YES;
    return [view.accessibilityIdentifier isEqual:@"tweetText"];
}
static BOOL PromotionalContainer(UIView *view) {
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    return [name containsString:@"upsell"] || [name containsString:@"sspad"] || [name containsString:@"promoted"] || [name containsString:@"premiumbanner"];
}
BOOL BHRDAdViewEvidence(UIView *root) {
    if (!root) return NO;
    NSMutableArray *pending=[NSMutableArray arrayWithObject:root]; NSUInteger budget=180;
    while (pending.count && budget--) {
        UIView *view=pending.lastObject; [pending removeLastObject];
        if (Excluded(view)) continue;
        if (BHRDStandaloneAdIdentifier(view.accessibilityIdentifier)) return YES;
        NSString *text=BHRDModelValue(view,@"text");
        if ([text isKindOfClass:NSAttributedString.class]) text=[(NSAttributedString *)text string];
        if (BHRDAdLabel(text) && ([view isKindOfClass:UILabel.class] || PromotionalContainer(view))) return YES;
        if (PromotionalContainer(view)) {
            if (BHRDPremiumTitle(view.accessibilityLabel) || BHRDPremiumTitle(text)) return YES;
            id model=BHRDModelValue(view,@"viewModel");
            if (BHRDIsPromotedModel(model)) return YES;
        }
        // A subscription heading inside a verified upsell container is structural metadata.
        if (BHRDPremiumTitle(text) && PromotionalContainer(root)) return YES;
        NSString *title=BHRDModelValue(view,@"currentTitle") ?: text;
        id url=BHRDModelValue(view,@"URL") ?: BHRDModelValue(view,@"url");
        if (BHRDPremiumSignupAction(url,title)) return YES;
        [pending addObjectsFromArray:view.subviews];
    }
    return NO;
}
static char HiddenKey;
static NSHashTable *Observed(void) {
    static NSHashTable *views; static dispatch_once_t once;
    dispatch_once(&once, ^{ views=[NSHashTable weakObjectsHashTable]; }); return views;
}
void BHRDUpdateStandaloneAdView(UIView *view) {
    NSNumber *previous=objc_getAssociatedObject(view,&HiddenKey);
    if (!previous && !PromotionalContainer(view) && !BHRDStandaloneAdIdentifier(view.accessibilityIdentifier)) return;
    [Observed() addObject:view];
    BOOL hide=BHRDPreference(BHRDHideAdsKey) && BHRDAdViewEvidence(view);
    if (hide) {
        if (!previous) objc_setAssociatedObject(view,&HiddenKey,@(view.hidden),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.hidden=YES;
    } else if (previous) {
        view.hidden=previous.boolValue;
        objc_setAssociatedObject(view,&HiddenKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
void BHRDAdAnnotationDidChange(UIView *view, NSString *text) {
    if (!BHRDAdLabel(text) && !BHRDPremiumTitle(text) && !BHRDStandaloneAdIdentifier(view.accessibilityIdentifier)) return;
    for (UIView *p=view; p; p=p.superview) {
        if ([p isKindOfClass:UITableViewCell.class]) { BHRDInvalidateAdCell((UITableViewCell *)p); break; }
        BHRDUpdateStandaloneAdView(p);
    }
}
__attribute__((constructor)) static void InstallAdRestoration(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:NSUserDefaults.standardUserDefaults queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        for (UIView *view in Observed().allObjects) BHRDUpdateStandaloneAdView(view);
    }];
}
