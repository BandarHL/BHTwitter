#import "BHRDAdFilter.h"
#import "BHRDModelAccess.h"
#import <objc/runtime.h>
static id Read(id object, NSString *key) {
    if (!object || object == NSNull.null) return nil;
    return BHRDModelValue(object, key);
}
static NSString *Trim(id value) {
    return [value isKindOfClass:NSString.class] ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : nil;
}
BOOL BHRDAdLabel(NSString *text) {
    return [@[@"广告", @"推广", @"Ad", @"Promoted", @"Publicidad", @"Anúncio", @"広告", @"광고"] containsObject:Trim(text) ?: @""];
}
BOOL BHRDStandaloneAdIdentifier(NSString *identifier) {
    return [identifier isKindOfClass:NSString.class] && ([identifier hasSuffix:@"SspAd"] || [identifier hasSuffix:@"impression-pixel"]);
}
BOOL BHRDPremiumTitle(NSString *text) {
    return [@[@"订阅 Premium", @"訂閱 Premium", @"Subscribe to Premium", @"プレミアムにサブスクライブ", @"Premium 구독하기"] containsObject:Trim(text) ?: @""];
}
BOOL BHRDPremiumSignupAction(id value, NSString *title) {
    NSURL *url = [value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
    BOOL host = !url.host.length || [@[@"x.com", @"www.x.com", @"twitter.com", @"www.twitter.com"] containsObject:url.host.lowercaseString];
    if (!host || ![url.path isEqual:@"/i/premium_sign_up"]) return NO;
    return [@[@"订阅", @"訂閱", @"Subscribe", @"サブスクライブ", @"구독하기"] containsObject:Trim(title) ?: @""];
}
BOOL BHRDShouldDisableAdFeature(NSString *key) {
    return [key isKindOfClass:NSString.class] && ([key hasPrefix:@"ad_formats_"] || [key hasPrefix:@"ad_"] || [key containsString:@"_ads_"] || [key isEqual:@"ads_enabled"]);
}
static BOOL Nonempty(id value) {
    if ([value isKindOfClass:NSString.class]) return [value length] > 0 && ![value isEqual:@"0"];
    if ([value isKindOfClass:NSNumber.class]) return [value unsignedLongLongValue] > 0;
    if ([value isKindOfClass:NSDictionary.class] || [value isKindOfClass:NSArray.class]) return [value count] > 0;
    return value && value != NSNull.null;
}
static BOOL Marked(id object) {
    id promoted=Read(object, @"isPromoted");
    if ([promoted isKindOfClass:NSNumber.class] && [promoted boolValue]) return YES;
    if (Nonempty(Read(Read(object, @"scribeItem"), @"promoted_id"))) return YES;
    for (NSString *key in @[@"promotedMetadata", @"promoted_metadata"]) if (Nonempty(Read(object, key))) return YES;
    for (NSString *key in @[@"accessibilityIdentifier", @"testID", @"testId"]) if (BHRDStandaloneAdIdentifier(Read(object,key))) return YES;
    // Dedicated annotation fields only: ordinary tweet body text is never inspected.
    for (NSString *key in @[@"promotedLabel", @"adLabel", @"disclosureText"]) if (BHRDAdLabel(Read(object,key))) return YES;
    NSString *name=NSStringFromClass([object classForCoder]);
    BOOL upsell=[name containsString:@"Upsell"] || [name containsString:@"Premium"] || [name containsString:@"Subscription"];
    if (upsell && BHRDPremiumTitle(Read(object,@"title"))) return YES;
    return BHRDPremiumSignupAction(Read(object,@"url"),Read(object,@"title"));
}
static char NativeAdKey;
void BHRDSetNativeAdEvidence(id model, BOOL ad) {
    model=BHRDUnwrapModel(model);
    if (model) objc_setAssociatedObject(model,&NativeAdKey,ad ? @YES : nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
BOOL BHRDIsPromotedModel(id model) {
    model = BHRDUnwrapModel(model);
    if ([objc_getAssociatedObject(model,&NativeAdKey) boolValue]) return YES;
    // Traverse only wrappers of this item, never quoted posts or arbitrary descendants.
    NSMutableArray *pending=[NSMutableArray array]; if (model) [pending addObject:model];
    NSHashTable *seen=[NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (NSUInteger i=0; i<pending.count && i<24; i++) {
        id item=pending[i]; if ([seen containsObject:item]) continue; [seen addObject:item];
        if (Marked(item)) return YES;
        for (NSString *key in @[@"status",@"viewModel",@"tweet",@"itemContent",@"content"]) { id child=Read(item,key); if (child && child!=NSNull.null) [pending addObject:child]; }
    }
    return NO;
}
NSArray *BHRDSectionsByRemovingAds(NSArray *sections) {
    if (![sections isKindOfClass:NSArray.class]) return sections;
    BOOL changed = NO;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:sections.count];
    for (id section in sections) {
        if (![section isKindOfClass:NSArray.class]) { [result addObject:section]; continue; }
        NSMutableArray *rows = [NSMutableArray array];
        for (id model in section) {
            if (BHRDIsPromotedModel(model)) changed = YES;
            else [rows addObject:model];
        }
        [result addObject:[rows copy]];
    }
    return changed ? [result copy] : sections;
}
