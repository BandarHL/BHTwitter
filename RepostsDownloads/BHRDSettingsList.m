#import "BHRDSettingsList.h"

@interface NSObject (BHRDSettingsStoreAccess)
- (id)backingStore;
- (NSArray *)sections;
- (id)itemAtIndexPath:(NSIndexPath *)indexPath;
- (void)insertItem:(id)item atIndexPath:(NSIndexPath *)indexPath;
- (void)_tfn_insertItem:(id)item atIndexPath:(NSIndexPath *)indexPath;
@end

id BHRDSettingsItemAtIndexPath(id controller, NSIndexPath *indexPath) {
    if (indexPath.length != 2 || ![controller respondsToSelector:@selector(sections)]) return nil;
    NSArray *sections = [controller sections];
    NSUInteger section = [indexPath indexAtPosition:0], row = [indexPath indexAtPosition:1];
    if (![sections isKindOfClass:NSArray.class] || section >= sections.count) return nil;
    id rows = sections[section];
    if ([rows isKindOfClass:NSArray.class]) return row < [rows count] ? rows[row] : nil;
    if ([controller respondsToSelector:@selector(itemAtIndexPath:)]) {
        @try { return [controller itemAtIndexPath:indexPath]; }
        @catch (__unused NSException *exception) { return nil; }
    }
    return nil;
}
BOOL BHRDInsertSettingsListItem(id controller, id item, NSUInteger expectedSections) {
    if (!item || ![controller respondsToSelector:@selector(backingStore)] || ![controller respondsToSelector:@selector(sections)]) return NO;
    NSArray *sections = [controller sections];
    if (![sections isKindOfClass:NSArray.class] || !sections.count) return NO;
    for (id section in sections) {
        if ([section isKindOfClass:NSArray.class] && [section indexOfObjectIdenticalTo:item] != NSNotFound) return NO;
    }
    NSUInteger indexes[] = {0, 0};
    NSIndexPath *first = [NSIndexPath indexPathWithIndexes:indexes length:2];
    if (BHRDSettingsItemAtIndexPath(controller, first) == item) return NO;
    // Match the original project's root-page guard; do not inject into unrelated subpages.
    if (sections.count != expectedSections) return NO;
    id store = [controller backingStore];
    if ([store respondsToSelector:@selector(insertItem:atIndexPath:)]) [store insertItem:item atIndexPath:first];
    else if ([store respondsToSelector:@selector(_tfn_insertItem:atIndexPath:)]) [store _tfn_insertItem:item atIndexPath:first];
    else return NO;
    return YES;
}
