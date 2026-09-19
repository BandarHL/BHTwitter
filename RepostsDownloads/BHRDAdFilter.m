#import "BHRDAdFilter.h"
#import "BHRDModelAccess.h"
static id Read(id object, NSString *key) {
    if (!object || object == NSNull.null) return nil;
    return BHRDModelValue(object, key);
}
static BOOL Marked(id object) {
    id promoted = Read(object, @"isPromoted");
    if ([promoted isKindOfClass:NSNumber.class] && [promoted boolValue]) return YES;
    id marker = Read(Read(object, @"scribeItem"), @"promoted_id");
    return ([marker isKindOfClass:NSString.class] && [marker length] > 0) ||
           ([marker isKindOfClass:NSNumber.class] && [marker unsignedLongLongValue] > 0);
}
BOOL BHRDIsPromotedModel(id model) {
    model = BHRDUnwrapModel(model);
    return Marked(model) || Marked(Read(model, @"status"));
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
