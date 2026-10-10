#import "BHRDRepostFilter.h"
#import <string.h>

static BOOL BHDataContainsUTF8String(NSData *data, const char *string) {
    if (![data isKindOfClass:NSData.class] || string == NULL) {
        return false;
    }

    NSData *needle = [NSData dataWithBytes:string length:strlen(string)];
    return [data rangeOfData:needle options:0 range:NSMakeRange(0, data.length)].location != NSNotFound;
}

static void BHSetChanged(BOOL *changed) {
    if (changed != NULL) {
        *changed = true;
    }
}

static NSDictionary *BHDictionaryValue(NSDictionary *dictionary, NSString *key) {
    id value = [dictionary objectForKey:key];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *BHArrayValue(NSDictionary *dictionary, NSString *key) {
    id value = [dictionary objectForKey:key];
    return [value isKindOfClass:NSArray.class] ? value : nil;
}

static BOOL BHDictionaryContainsRepost(NSDictionary *dictionary) {
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return false;
    }

    for (NSString *key in @[@"retweeted_status_result", @"retweeted_status", @"retweeted_status_id", @"retweeted_status_id_str"]) {
        id value = dictionary[key];
        if (value != nil && value != NSNull.null && ![value isEqual:@0] && ![value isEqual:@"0"]) return YES;
    }
    return NO;
}

static BOOL BHTweetResultContainsRepost(NSDictionary *result) {
    if (![result isKindOfClass:NSDictionary.class]) {
        return false;
    }

    if (BHDictionaryContainsRepost(result) || BHDictionaryContainsRepost(BHDictionaryValue(result, @"legacy"))) {
        return true;
    }

    // TweetWithVisibilityResults 等包装模型会把实际推文放在 tweet 中。
    NSDictionary *tweet = BHDictionaryValue(result, @"tweet");
    return tweet != result && BHTweetResultContainsRepost(tweet);
}

static BOOL BHItemContentContainsRepost(NSDictionary *itemContent) {
    NSDictionary *tweetResults = BHDictionaryValue(itemContent, @"tweet_results");
    return BHTweetResultContainsRepost(BHDictionaryValue(tweetResults, @"result"));
}

static BOOL BHModuleItemContainsRepost(NSDictionary *moduleItem) {
    if (![moduleItem isKindOfClass:NSDictionary.class]) {
        return false;
    }

    if (BHItemContentContainsRepost(BHDictionaryValue(moduleItem, @"itemContent"))) {
        return true;
    }

    NSDictionary *item = BHDictionaryValue(moduleItem, @"item");
    return BHItemContentContainsRepost(BHDictionaryValue(item, @"itemContent"));
}

static NSString *BHModuleItemsKey(NSDictionary *content) {
    for (NSString *key in @[@"items", @"moduleItems", @"module_items"]) {
        if (BHArrayValue(content, key) != nil) {
            return key;
        }
    }
    return nil;
}

static NSDictionary *BHTimelineEntryByFilteringReposts(NSDictionary *entry,
                                                        BOOL *removed,
                                                        BOOL *changed) {
    if (removed != NULL) {
        *removed = false;
    }

    NSDictionary *content = BHDictionaryValue(entry, @"content");
    if (BHItemContentContainsRepost(BHDictionaryValue(content, @"itemContent"))) {
        if (removed != NULL) {
            *removed = true;
        }
        BHSetChanged(changed);
        return nil;
    }

    NSString *moduleItemsKey = BHModuleItemsKey(content);
    if (moduleItemsKey == nil) {
        return entry;
    }
    NSArray *moduleItems = BHArrayValue(content, moduleItemsKey);
    if (moduleItems == nil) {
        return entry;
    }

    NSMutableArray *filteredItems = [NSMutableArray arrayWithCapacity:moduleItems.count];
    BOOL moduleChanged = false;
    for (id moduleItem in moduleItems) {
        if ([moduleItem isKindOfClass:NSDictionary.class] &&
            BHModuleItemContainsRepost(moduleItem)) {
            moduleChanged = true;
            continue;
        }
        [filteredItems addObject:moduleItem];
    }

    if (!moduleChanged) {
        return entry;
    }

    BHSetChanged(changed);
    if (filteredItems.count == 0) {
        if (removed != NULL) {
            *removed = true;
        }
        return nil;
    }

    NSMutableDictionary *filteredContent = [content mutableCopy];
    [filteredContent setObject:filteredItems forKey:moduleItemsKey];
    NSMutableDictionary *filteredEntry = [entry mutableCopy];
    [filteredEntry setObject:filteredContent forKey:@"content"];
    return filteredEntry;
}

id BHRDJSONObjectByFilteringReposts(id object, BOOL *changed) {
    if ([object isKindOfClass:NSArray.class]) {
        NSArray *array = object;
        NSMutableArray *filteredArray = nil;

        for (NSUInteger index = 0; index < array.count; index++) {
            id item = array[index];
            id filteredItem = item;
            BOOL itemChanged = false;
            BOOL includeItem = true;
            BOOL isTimelineEntry = [item isKindOfClass:NSDictionary.class] && ([(NSDictionary *)item objectForKey:@"entryId"] != nil || [(NSDictionary *)item objectForKey:@"entry_id"] != nil);
            if (isTimelineEntry) {
                BOOL entryRemoved = false;
                filteredItem = BHTimelineEntryByFilteringReposts(
                    item, &entryRemoved, &itemChanged) ?: item;
                includeItem = !entryRemoved;
            } else {
                filteredItem = BHRDJSONObjectByFilteringReposts(
                    item, &itemChanged) ?: item;
            }

            if (itemChanged) {
                BHSetChanged(changed);
                if (filteredArray == nil) {
                    filteredArray = [NSMutableArray arrayWithCapacity:array.count];
                    if (index > 0) {
                        [filteredArray addObjectsFromArray:
                            [array subarrayWithRange:NSMakeRange(0, index)]];
                    }
                }
            }

            if (filteredArray != nil && includeItem) {
                [filteredArray addObject:filteredItem];
            }
        }

        return filteredArray ?: object;
    }

    if ([object isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = object;
        NSMutableDictionary *filteredDictionary = nil;

        for (id key in dictionary) {
            // Preserve the conversation response before any rows are removed.
            // Recursion still filters sibling home/profile timelines normally.
            if ([@[@"threaded_conversation_with_injections_v2", @"threaded_conversation_with_injections",
                   @"tweet_detail", @"tweetDetail"] containsObject:key]) continue;
            id value = [dictionary objectForKey:key];
            BOOL valueChanged = false;
            id filteredValue = BHRDJSONObjectByFilteringReposts(value, &valueChanged);
            if (valueChanged) {
                BHSetChanged(changed);
                if (filteredDictionary == nil) {
                    filteredDictionary = [dictionary mutableCopy];
                }
                [filteredDictionary setObject:filteredValue ?: value forKey:key];
            }
        }

        return filteredDictionary ?: object;
    }

    return object;
}

BOOL BHRDDataMayContainReposts(NSData *data) {
    return (BHDataContainsUTF8String(data, "\"entryId\"") || BHDataContainsUTF8String(data, "\"entry_id\"")) &&
           BHDataContainsUTF8String(data, "\"retweeted_status");
}
