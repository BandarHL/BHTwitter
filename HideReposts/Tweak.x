#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>

@interface TFNDataViewController : UIViewController
@property(readonly, nonatomic) UITableView *tableView;
@end

@interface TFNItemsDataViewController : TFNDataViewController
@property(copy, nonatomic) NSArray *sections;
- (id)itemAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface TFNItemsDataViewControllerBackingStore : NSObject
- (void)insertItem:(id)item atIndexPath:(NSIndexPath *)indexPath;
- (void)_tfn_insertItem:(id)item atIndexPath:(NSIndexPath *)indexPath;
@end

@interface T1URTTimelineStatusItemViewModel : NSObject
@property(nonatomic, readonly) BOOL isRetweet;
@end

static BOOL HRIsRepostItem(id item) {
    if (item == nil) {
        return NO;
    }

    Class statusItemClass = objc_getClass("T1URTTimelineStatusItemViewModel");
    return statusItemClass != Nil && [item isKindOfClass:statusItemClass] && ((T1URTTimelineStatusItemViewModel *)item).isRetweet;
}

static BOOL HRDataContainsUTF8String(NSData *data, const char *string) {
    if (![data isKindOfClass:NSData.class] || string == NULL) {
        return NO;
    }

    NSData *needle = [NSData dataWithBytes:string length:strlen(string)];
    return [data rangeOfData:needle options:0 range:NSMakeRange(0, data.length)].location != NSNotFound;
}

static BOOL HRShouldFilterRepostJSONData(NSData *data) {
    if (![data isKindOfClass:NSData.class] || data.length == 0) {
        return NO;
    }

    BOOL containsEntryID = HRDataContainsUTF8String(data, "\"entryId\"") || HRDataContainsUTF8String(data, "\"entry_id\"");
    return HRDataContainsUTF8String(data, "\"retweeted_status_result\"") && containsEntryID;
}

static void HRSetChanged(BOOL *changed) {
    if (changed != NULL) {
        *changed = YES;
    }
}

static NSDictionary *HRDictionaryValue(NSDictionary *dictionary, NSString *key) {
    id value = [dictionary objectForKey:key];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *HRArrayValue(NSDictionary *dictionary, NSString *key) {
    id value = [dictionary objectForKey:key];
    return [value isKindOfClass:NSArray.class] ? value : nil;
}

static BOOL HRTweetResultContainsRepost(NSDictionary *result) {
    if (![result isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSDictionary *legacy = HRDictionaryValue(result, @"legacy");
    if ([legacy objectForKey:@"retweeted_status_result"] != nil) {
        return YES;
    }

    NSDictionary *tweet = HRDictionaryValue(result, @"tweet");
    NSDictionary *tweetLegacy = HRDictionaryValue(tweet, @"legacy");
    return [tweetLegacy objectForKey:@"retweeted_status_result"] != nil;
}

static BOOL HRItemContentContainsRepost(NSDictionary *itemContent) {
    NSDictionary *tweetResults = HRDictionaryValue(itemContent, @"tweet_results");
    return HRTweetResultContainsRepost(HRDictionaryValue(tweetResults, @"result"));
}

static BOOL HRTimelineEntryContainsRepost(NSDictionary *entry) {
    if (![entry isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    if ([entry objectForKey:@"entryId"] == nil && [entry objectForKey:@"entry_id"] == nil) {
        return NO;
    }

    NSDictionary *content = HRDictionaryValue(entry, @"content");
    if (HRItemContentContainsRepost(HRDictionaryValue(content, @"itemContent"))) {
        return YES;
    }

    NSArray *items = HRArrayValue(content, @"items");
    NSUInteger itemLimit = MIN(items.count, 4);
    for (NSUInteger index = 0; index < itemLimit; index++) {
        id moduleItem = items[index];
        if (![moduleItem isKindOfClass:NSDictionary.class]) {
            continue;
        }

        NSDictionary *item = HRDictionaryValue(moduleItem, @"item");
        if (HRItemContentContainsRepost(HRDictionaryValue(item, @"itemContent"))) {
            return YES;
        }
    }

    return NO;
}

static id HRJSONObjectByFilteringRepostEntries(id object, BOOL *changed) {
    if ([object isKindOfClass:NSArray.class]) {
        NSArray *array = object;
        BOOL arrayChanged = NO;
        NSMutableArray *filteredArray = [NSMutableArray arrayWithCapacity:array.count];

        for (id item in array) {
            BOOL isTimelineEntry = [item isKindOfClass:NSDictionary.class] &&
                ([(NSDictionary *)item objectForKey:@"entryId"] != nil || [(NSDictionary *)item objectForKey:@"entry_id"] != nil);
            if (isTimelineEntry && HRTimelineEntryContainsRepost(item)) {
                arrayChanged = YES;
                HRSetChanged(changed);
                continue;
            }

            if (isTimelineEntry) {
                [filteredArray addObject:item];
                continue;
            }

            BOOL itemChanged = NO;
            id filteredItem = HRJSONObjectByFilteringRepostEntries(item, &itemChanged);
            if (itemChanged) {
                arrayChanged = YES;
                HRSetChanged(changed);
            }
            [filteredArray addObject:filteredItem ?: item];
        }

        return arrayChanged ? filteredArray : object;
    }

    if ([object isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = object;
        BOOL dictionaryChanged = NO;
        NSMutableDictionary *filteredDictionary = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

        for (id key in dictionary) {
            id value = [dictionary objectForKey:key];
            BOOL valueChanged = NO;
            id filteredValue = HRJSONObjectByFilteringRepostEntries(value, &valueChanged);
            if (valueChanged) {
                dictionaryChanged = YES;
                HRSetChanged(changed);
            }
            [filteredDictionary setObject:filteredValue ?: value forKey:key];
        }

        return dictionaryChanged ? filteredDictionary : object;
    }

    return object;
}

static NSArray *HRSectionsByFilteringReposts(NSArray *sections) {
    if (![sections isKindOfClass:NSArray.class]) {
        return sections;
    }

    BOOL changed = NO;
    NSMutableArray *filteredSections = [NSMutableArray arrayWithCapacity:sections.count];
    for (id section in sections) {
        if (![section isKindOfClass:NSArray.class]) {
            [filteredSections addObject:section];
            continue;
        }

        BOOL sectionChanged = NO;
        NSMutableArray *filteredItems = [NSMutableArray arrayWithCapacity:[section count]];
        for (id item in section) {
            if (HRIsRepostItem(item)) {
                changed = YES;
                sectionChanged = YES;
                continue;
            }
            [filteredItems addObject:item];
        }

        [filteredSections addObject:sectionChanged ? filteredItems : section];
    }

    return changed ? filteredSections : sections;
}

static char HRRepostPurgeScheduledKey;

static void HRScheduleRepostSectionPurge(TFNItemsDataViewController *controller) {
    Class controllerClass = objc_getClass("TFNItemsDataViewController");
    if (controllerClass == Nil || ![controller isKindOfClass:controllerClass]) {
        return;
    }

    if ([objc_getAssociatedObject(controller, &HRRepostPurgeScheduledKey) boolValue]) {
        return;
    }

    objc_setAssociatedObject(controller, &HRRepostPurgeScheduledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(dispatch_get_main_queue(), ^{
        objc_setAssociatedObject(controller, &HRRepostPurgeScheduledKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        NSArray *sections = controller.sections;
        NSArray *filteredSections = HRSectionsByFilteringReposts(sections);
        if (filteredSections != sections) {
            controller.sections = filteredSections;
            [controller.tableView reloadData];
        }
    });
}

%hook NSJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)options error:(NSError **)error {
    id object = %orig;
    if (object != nil && HRShouldFilterRepostJSONData(data)) {
        BOOL changed = NO;
        id filteredObject = HRJSONObjectByFilteringRepostEntries(object, &changed);
        return changed ? filteredObject : object;
    }
    return object;
}

%end

%hook TFNItemsDataViewController

- (void)setSections:(NSArray *)sections {
    %orig(HRSectionsByFilteringReposts(sections));
}

- (void)updateSections:(NSArray *)sections withRowAnimation:(long long)animation {
    %orig(HRSectionsByFilteringReposts(sections), animation);
}

- (double)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    id timelineItem = [self itemAtIndexPath:indexPath];
    if (HRIsRepostItem(timelineItem)) {
        HRScheduleRepostSectionPurge(self);
        return 0;
    }
    return %orig;
}

%end

%hook TFNItemsDataViewControllerBackingStore

- (void)insertItem:(id)item atIndexPath:(NSIndexPath *)indexPath {
    if (HRIsRepostItem(item)) {
        return;
    }
    %orig;
}

- (void)_tfn_insertItem:(id)item atIndexPath:(NSIndexPath *)indexPath {
    if (HRIsRepostItem(item)) {
        return;
    }
    %orig;
}

%end
