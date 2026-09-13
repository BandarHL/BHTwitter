#import "BHRDManager.h"
#import "BHRDConversationScope.h"
#import "BHRDAdFilter.h"
#import "BHRDContentFilter.h"
#import "BHRDRepostFilter.h"
#import "BHRDRepostPresentation.h"
#import "BHRDSharePost.h"
#import <objc/runtime.h>

%hook NSJSONSerialization
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)options error:(NSError **)error {
    id object = %orig;
    if (object && BHRDPreference(BHRDShowShareImageKey)) BHRDCacheSharePosts(object, data);
    // Author/user responses can arrive separately from timeline entries. Keep
    // their metadata even when filtering is off, ready for preview mode later.
    if (object && [BHRDManager HideReposts] && BHRDCurrentRepostMode() == BHRDRepostModePreview && BHRDDataMayContainRepostMetadata(data)) {
        BHRDCacheRepostMetadata(object);
        BHRDRepostMetadataChanged();
    }
    if (!object || ![BHRDManager HideReposts] || !BHRDDataMayContainReposts(data)) return object;
    // Preview/bar retain the full model so the user can reveal it without a refetch.
    if (BHRDCurrentRepostMode() != BHRDRepostModeHidden) return object;
    BOOL changed = NO;
    return BHRDJSONObjectByFilteringReposts(object, &changed);
}
%end

// Image downloads can finish without triggering a cell layout. The callback
// acts only on native views inside an active repost preview, excluding ours.
%hook UIImageView
- (void)setImage:(UIImage *)image {
    %orig(image);
    BHRDRepostNativeImageChanged(self);
}
%end

%hook TFNItemsDataViewController
- (void)setSections:(NSArray *)sections {
    if (BHRDIsConversationContext(self)) { %orig; return; }
    sections = BHRDFilterRecommendations(sections, self);
    if (BHRDPreference(BHRDHideAdsKey)) sections = BHRDSectionsByRemovingAds(sections);
    if ([BHRDManager HideReposts] && BHRDCurrentRepostMode() == BHRDRepostModeHidden) sections = BHRDSectionsByRemovingReposts(sections);
    %orig(sections);
}
- (void)updateSections:(NSArray *)sections withRowAnimation:(long long)animation {
    if (BHRDIsConversationContext(self)) { %orig; return; }
    sections = BHRDFilterRecommendations(sections, self);
    if (BHRDPreference(BHRDHideAdsKey)) sections = BHRDSectionsByRemovingAds(sections);
    if ([BHRDManager HideReposts] && BHRDCurrentRepostMode() == BHRDRepostModeHidden) sections = BHRDSectionsByRemovingReposts(sections);
    %orig(sections, animation);
}
- (id)tableViewCellForItem:(id)item atIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = %orig;
    BHRDConfigureRepostCell(cell, [self itemAtIndexPath:indexPath] ?: item, self);
    return cell;
}
- (double)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    double original = %orig;
    return BHRDRepostRowHeight(self, [self itemAtIndexPath:indexPath], original);
}
%end

// Scope generic cell hooks to cells carrying our associated presentation state.
%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    BHRDLayoutRepostCell(self);
}
- (void)prepareForReuse {
    BHRDRestoreRepostCell(self);
    %orig;
}
%end

%group BHRDActualCellFactory
%hook TFNItemsDataViewController
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = %orig;
    BHRDConfigureRepostCell(cell, [self itemAtIndexPath:indexPath], self);
    return cell;
}
%end
%end
%group BHRDCellDisplay
%hook TFNItemsDataViewController
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    %orig;
    BHRDConfigureRepostCell(cell, [self itemAtIndexPath:indexPath], self);
}
%end
%end
%group BHRDEstimatedRepostHeight
%hook TFNItemsDataViewController
- (double)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    double original = %orig;
    return BHRDRepostRowHeight(self, [self itemAtIndexPath:indexPath], original);
}
%end
%end
%group BHRDModernSections
%hook TFNItemsDataViewController
- (void)setSections:(NSArray *)sections restoreScrollPosition:(BOOL)restore {
    if (BHRDIsConversationContext(self)) { %orig; return; }
    sections = BHRDFilterRecommendations(sections, self);
    if (BHRDPreference(BHRDHideAdsKey)) sections = BHRDSectionsByRemovingAds(sections);
    if ([BHRDManager HideReposts] && BHRDCurrentRepostMode() == BHRDRepostModeHidden) sections = BHRDSectionsByRemovingReposts(sections);
    %orig(sections, restore);
}
%end
%end
%group BHRDModernUpdates
%hook TFNItemsDataViewController
- (void)updateSections:(NSArray *)sections reconfigureItemIdentifiers:(NSArray *)identifiers withRowAnimation:(long long)animation completion:(id)completion {
    if (BHRDIsConversationContext(self)) { %orig; return; }
    sections = BHRDFilterRecommendations(sections, self);
    if (BHRDPreference(BHRDHideAdsKey)) sections = BHRDSectionsByRemovingAds(sections);
    if ([BHRDManager HideReposts] && BHRDCurrentRepostMode() == BHRDRepostModeHidden) sections = BHRDSectionsByRemovingReposts(sections);
    %orig(sections, identifiers, animation, completion);
}
%end
%end
%ctor {
    %init;
    Class cls = objc_getClass("TFNItemsDataViewController");
    if (class_getInstanceMethod(cls, @selector(setSections:restoreScrollPosition:))) { %init(BHRDModernSections); }
    if (class_getInstanceMethod(cls, @selector(updateSections:reconfigureItemIdentifiers:withRowAnimation:completion:))) { %init(BHRDModernUpdates); }
    if (class_getInstanceMethod(cls, @selector(tableView:cellForRowAtIndexPath:))) { %init(BHRDActualCellFactory); }
    if (class_getInstanceMethod(cls, @selector(tableView:willDisplayCell:forRowAtIndexPath:))) { %init(BHRDCellDisplay); }
    if (class_getInstanceMethod(cls, @selector(tableView:estimatedHeightForRowAtIndexPath:))) { %init(BHRDEstimatedRepostHeight); }
}
