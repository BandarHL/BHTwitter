#import <Foundation/Foundation.h>
#import "../BHRDPreferences.h"
#import "../BHRDSettingsList.h"
#include <stdlib.h>

static NSUInteger checks;
static void Check(BOOL pass, NSString *name) {
    checks++;
    if (!pass) { NSLog(@"FAIL: %@", name); exit(1); }
}
#define ACTION_CLASS(name) @interface name : NSObject @end @implementation name @end
ACTION_CLASS(TTAStatusInlineReplyButton)
ACTION_CLASS(TTAStatusInlineRetweetButton)
ACTION_CLASS(TTAStatusInlineFavoriteButton)
ACTION_CLASS(TTAStatusInlineAnalyticsButton)
ACTION_CLASS(TTAStatusInlineBookmarkButton)
ACTION_CLASS(TTAStatusInlineShareButton)
ACTION_CLASS(T1StatusInlineFavoriteButton)
ACTION_CLASS(BHRDDownloadButton)
ACTION_CLASS(UnknownHostButton)
@interface HostReplySubclass : TTAStatusInlineReplyButton @end
@implementation HostReplySubclass @end

@interface MockStore : NSObject
@property(nonatomic, strong) NSMutableArray *sections;
@property(nonatomic) NSUInteger insertions;
- (void)insertItem:(id)item atIndexPath:(NSIndexPath *)path;
@end
@implementation MockStore
- (void)insertItem:(id)item atIndexPath:(NSIndexPath *)path {
    NSMutableArray *rows = self.sections[[path indexAtPosition:0]];
    [rows insertObject:item atIndex:[path indexAtPosition:1]];
    self.insertions++;
}
@end
@interface LegacyStore : NSObject
@property(nonatomic, strong) NSMutableArray *sections;
- (void)_tfn_insertItem:(id)item atIndexPath:(NSIndexPath *)path;
@end
@implementation LegacyStore
- (void)_tfn_insertItem:(id)item atIndexPath:(NSIndexPath *)path {
    [self.sections[[path indexAtPosition:0]] insertObject:item atIndex:[path indexAtPosition:1]];
}
@end
@interface MockController : NSObject
@property(nonatomic, strong) id backingStore;
@property(nonatomic, strong) NSArray *sections;
@end
@implementation MockController @end
static NSIndexPath *Path(NSUInteger section, NSUInteger row) {
    NSUInteger indexes[] = {section, row};
    return [NSIndexPath indexPathWithIndexes:indexes length:2];
}
int main(void) {
    @autoreleasepool {
        NSString *suite = [@"BHRDTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        NSArray *keys = BHRDSettingsKeys(), *titles = BHRDSettingsTitles();
        Check(keys.count == 7 && titles.count == 7, @"Settings include image copy privacy policy");
        for (NSUInteger section = 0; section < keys.count; section++) {
            Check([keys[section] count] == [titles[section] count], @"Every setting has a Chinese label");
            for (NSString *key in keys[section]) {
                if (section >= 2 && ![key isEqualToString:BHRDHideHomeAddKey] && ![key isEqualToString:BHRDShowShareImageKey] && ![key isEqual:BHRDCopyLocalOnlyKey]) Check(!BHRDReadPreference(defaults, key), @"Existing optional hide settings remain off by default");
            }
        }
        Check(BHRDReadPreference(defaults, BHRDDownloadKey) && BHRDReadPreference(defaults, BHRDHideRepostsKey), @"Keep 1.0 defaults");
        Check(BHRDReadPreference(defaults, BHRDHideHomeAddKey) && BHRDReadPreference(defaults, BHRDFloatingDownloadKey), @"Requested add-tab hiding and independent fullscreen download start enabled");
        Check(!BHRDReadPreference(defaults, BHRDDirectSaveKey), @"Direct saving stays off by default");
        [defaults setBool:NO forKey:BHRDDownloadKey];
        [defaults setBool:YES forKey:BHRDHideViewsKey];
        [defaults setBool:NO forKey:BHRDHideRepostsKey];
        Check(!BHRDReadPreference(defaults, BHRDDownloadKey) && !BHRDReadPreference(defaults, BHRDHideRepostsKey), @"Persist explicit disabled settings across upgrade");
        Check(BHRDReadPreference(defaults, BHRDHideViewsKey), @"Persist enabled new setting");
        Check(!BHRDReadPreference(defaults, @"unknown_future_key"), @"Unknown preferences are not enabled");
        [defaults removePersistentDomainForName:suite];

        NSArray *actions = @[TTAStatusInlineReplyButton.class, TTAStatusInlineRetweetButton.class,
                             TTAStatusInlineFavoriteButton.class, TTAStatusInlineAnalyticsButton.class,
                             TTAStatusInlineBookmarkButton.class, TTAStatusInlineShareButton.class,
                             BHRDDownloadButton.class, UnknownHostButton.class];
        Check(BHRDFilterInlineActionClasses(actions, [NSSet set]) == actions, @"Disabled options preserve original list");
        NSArray *eachKey = @[BHRDHideReplyKey, BHRDHideRetweetKey, BHRDHideLikeKey, BHRDHideViewsKey, BHRDHideBookmarkKey];
        for (NSUInteger i = 0; i < eachKey.count; i++) {
            NSMutableArray *expected = [actions mutableCopy];
            [expected removeObjectAtIndex:i];
            NSArray *actual = BHRDFilterInlineActionClasses(actions, [NSSet setWithObject:eachKey[i]]);
            Check([actual isEqual:expected], @"Each action switch removes only the selected button");
        }
        NSArray *allHidden = BHRDFilterInlineActionClasses(actions, [NSSet setWithArray:eachKey]);
        Check([allHidden isEqual:@[TTAStatusInlineShareButton.class, BHRDDownloadButton.class, UnknownHostButton.class]], @"Keep share, download and unknown host buttons in order");
        Check(actions.count == 8, @"Do not mutate host action array");
        Check([BHRDFilterInlineActionClasses(@[T1StatusInlineFavoriteButton.class], [NSSet setWithObject:BHRDHideLikeKey]) count] == 0, @"Support older T1 action classes");
        Check([BHRDFilterInlineActionClasses(@[HostReplySubclass.class], [NSSet setWithObject:BHRDHideReplyKey]) count] == 0, @"Support subclasses of known buttons");
        Check(BHRDFilterInlineActionClasses(nil, [NSSet setWithArray:eachKey]) == nil, @"Handle missing action list");
        Check([BHRDFilterInlineActionClasses(@[NSNull.null], [NSSet setWithArray:eachKey]) isEqual:@[NSNull.null]], @"Keep unexpected non-class host values");
        NSArray *pages = @[@"home", @"guide", @"grok", @"ntab", @"messages"];
        for (NSUInteger i = 0; i < pages.count; i++) Check([BHRDPreferenceKeyForTabPage(pages[i]) isEqual:keys[3][i]], @"Map the original project's five tab identifiers");
        Check(BHRDPreferenceKeyForTabPage(@"communities") == nil && BHRDPreferenceKeyForTabPage(nil) == nil, @"Do not hide unrelated tabs");

        MockController *controller = [MockController new];
        MockStore *store = [MockStore new];
        store.sections = [NSMutableArray arrayWithObject:[NSMutableArray arrayWithArray:@[@"你的账号", @"隐私与安全", @"通知"]]];
        controller.sections = store.sections;
        controller.backingStore = store;
        NSObject *entry = [NSObject new];
        Check(BHRDInsertSettingsListItem(controller, entry, 1), @"Insert a real settings list item");
        Check([store.sections[0] isEqual:@[entry, @"你的账号", @"隐私与安全", @"通知"]], @"Preserve all original settings and their order");
        Check(!BHRDInsertSettingsListItem(controller, entry, 1) && store.insertions == 1, @"Returning to settings does not duplicate the entry");
        Check(BHRDSettingsItemAtIndexPath(controller, Path(0, 0)) == entry, @"Identify our row by object identity");
        Check([BHRDSettingsItemAtIndexPath(controller, Path(0, 1)) isEqual:@"你的账号"], @"Original rows remain identifiable");
        Check(BHRDSettingsItemAtIndexPath(controller, Path(4, 0)) == nil, @"Ignore out-of-range section");
        [store.sections[0] removeObjectIdenticalTo:entry];
        Check(BHRDInsertSettingsListItem(controller, entry, 1) && store.insertions == 2, @"Restore entry after host rebuilds its data");
        [store.sections[0] removeObjectIdenticalTo:entry];
        Check(!BHRDInsertSettingsListItem(controller, entry, 2), @"Do not insert on unrelated subpages");
        LegacyStore *legacy = [LegacyStore new];
        legacy.sections = [NSMutableArray arrayWithArray:@[[NSMutableArray array], [NSMutableArray arrayWithObject:@"旧版设置"]]];
        controller.sections = legacy.sections;
        controller.backingStore = legacy;
        Check(BHRDInsertSettingsListItem(controller, entry, 2), @"Support legacy underscore-prefixed insertion");
        Check(BHRDSettingsItemAtIndexPath(controller, Path(0, 0)) == entry && [legacy.sections[1] count] == 1, @"Legacy injection keeps other sections untouched");
        controller.backingStore = [NSObject new];
        [legacy.sections[0] removeAllObjects];
        Check(!BHRDInsertSettingsListItem(controller, entry, 2), @"Unsupported store safely skips insertion");
        NSLog(@"PASS: %lu customization checks", (unsigned long)checks);
    }
    return 0;
}
