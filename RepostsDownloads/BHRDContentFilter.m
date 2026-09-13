#import "BHRDContentFilter.h"
#import "BHRDModelAccess.h"
#import "BHRDPreferences.h"
static id Read(id object, NSString *key) {
    return BHRDModelValue(object, key);
}
BOOL BHRDContentPolicy(NSString *name, NSString *banner, NSDictionary *scribe, NSString *location, NSSet *enabled) {
    // Explicit recommendation policy; broader Premium/carousel rules are documented in settings.
    if ([enabled containsObject:BHRDHideTopicsKey] && [banner isEqual:@"TFNTwitterURTTimelineStatusTopicBanner"]) return YES;
    if ([location isEqual:@"PROFILE_TWEETS"] && [enabled containsObject:BHRDHideWhoKey] && [name isEqual:@"T1URTTimelineUserItemViewModel"]) return YES;
    if ([enabled containsObject:BHRDHideSuggestedTopicsKey] && [@[@"T1TwitterSwift.URTTimelineTopicCollectionViewModel", @"TwitterURT.URTTimelineTopicCollectionViewModel"] containsObject:name ?: @""]) return YES;
    if ([enabled containsObject:BHRDHideTrendVideosKey] && [location isEqual:@"OTHER"] && [name isEqual:@"T1TwitterSwift.URTTimelineCarouselViewModel"]) return YES;
    if (![scribe isKindOfClass:NSDictionary.class]) return NO;
    NSDictionary *markers = @{BHRDHideTopicsKey:@[@"suggest_topic", @"topic_recommendation"], BHRDHideWhoKey:@[@"who_to_follow", @"suggest_who_to_follow"], BHRDHideSuggestedTopicsKey:@[@"topics_to_follow", @"suggest_topics_to_follow"], BHRDHidePremiumKey:@[@"premium_upsell", @"premium_signup", @"blue_upsell"], BHRDHideTrendVideosKey:@[@"trending_videos", @"trend_videos", @"explore_video_carousel"]};
    for (NSString *key in enabled) for (NSString *field in @[@"component", @"element", @"entity_id"])
        if ([markers[key] containsObject:scribe[field] ?: NSNull.null]) return YES;
    return NO;
}
static id Unwrap(id model) {
    return BHRDUnwrapModel(model);
}
static NSString *ModelClass(id model) { return NSStringFromClass([Unwrap(model) classForCoder]); }
static BOOL Header(id model) { return [ModelClass(model) isEqual:@"TwitterURT.URTModuleHeaderViewModel"]; }
static BOOL Footer(id model) { return [ModelClass(model) isEqual:@"TwitterURT.URTModuleFooterViewModel"]; }
// Same hierarchy traversal used by upstream; bounded for malformed host graphs.
static BOOL InProfile(id controller) {
    Class target = NSClassFromString(@"T1ProfileViewController");
    NSHashTable *visited = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (NSUInteger i = 0; controller && i < 32; i++) {
        if (target && [controller isKindOfClass:target]) return YES;
        if ([visited containsObject:controller]) break;
        [visited addObject:controller];
        controller = Read(controller,@"parentViewController") ?: Read(controller,@"navigationController") ?: Read(controller,@"presentingViewController");
    }
    return NO;
}
BOOL BHRDShouldHideRecommendation(id model, id controller) {
    model = Unwrap(model);
    NSMutableSet *enabled = [NSMutableSet set];
    for (NSString *key in @[BHRDHideTopicsKey,BHRDHideWhoKey,BHRDHideSuggestedTopicsKey,BHRDHidePremiumKey,BHRDHideTrendVideosKey]) if (BHRDPreference(key)) [enabled addObject:key];
    if (!enabled.count) return NO;
    if ([enabled containsObject:BHRDHideWhoKey] && InProfile(controller) && [ModelClass(model) isEqual:@"T1TwitterSwift.URTTimelineCarouselViewModel"]) return YES;
    // Upstream premium filtering removes timeline message view models.
    if ([enabled containsObject:BHRDHidePremiumKey] && [ModelClass(model) isEqual:@"TwitterURT.URTTimelineMessageItemViewModel"]) return YES;
    NSString *entry = Read(model, @"entryID");
    if ([enabled containsObject:BHRDHideWhoKey] && [entry isKindOfClass:NSString.class] && [entry containsString:@"who-to-follow"]) return YES;
    id raw = Read(model, @"scribeItem");
    NSMutableDictionary *scribe = [raw isKindOfClass:NSDictionary.class] ? [raw mutableCopy] : [NSMutableDictionary dictionary];
    id component = Read(model, @"scribeComponent");
    if ([component isKindOfClass:NSString.class]) scribe[@"component"] = component;
    return BHRDContentPolicy(ModelClass(model), ModelClass(Read(model,@"banner")), scribe, Read(controller,@"adDisplayLocation"), enabled);
}
NSArray *BHRDFilterRecommendations(NSArray *sections, id controller) {
    if (![sections isKindOfClass:NSArray.class]) return sections;
    BOOL enabled = NO;
    for (NSString *key in @[BHRDHideTopicsKey,BHRDHideWhoKey,BHRDHideSuggestedTopicsKey,BHRDHidePremiumKey,BHRDHideTrendVideosKey]) enabled |= BHRDPreference(key);
    if (!enabled) return sections;
    BOOL changed = NO; NSMutableArray *result = [NSMutableArray array];
    for (id section in sections) {
        if (![section isKindOfClass:NSArray.class]) { [result addObject:section]; continue; }
        NSArray *items = section;
        NSMutableIndexSet *removed = [NSMutableIndexSet indexSet];
        for (NSUInteger i = 0; i < items.count; i++) if (BHRDShouldHideRecommendation(items[i], controller)) [removed addIndex:i];
        // Remove only chrome around an entirely removed, bounded module.
        for (NSUInteger i = 0; i < items.count; i++) {
            if ([removed containsIndex:i] || !Header(items[i])) continue;
            NSUInteger end = i + 1;
            BOOL all = YES;
            while (end < items.count && !Header(items[end]) && !Footer(items[end])) {
                if (![removed containsIndex:end]) all = NO;
                end++;
            }
            if (end > i + 1 && all) {
                [removed addIndex:i];
                if (end < items.count && Footer(items[end])) [removed addIndex:end];
            }
        }
        if (!removed.count) { [result addObject:section]; continue; }
        changed = YES;
        NSMutableArray *rows = [items mutableCopy]; [rows removeObjectsAtIndexes:removed];
        if (rows.count) [result addObject:[rows copy]];
    }
    return changed ? [result copy] : sections;
}
