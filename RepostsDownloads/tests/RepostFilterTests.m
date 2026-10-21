#import <Foundation/Foundation.h>
#import "../BHRDRepostFilter.h"
#include <stdlib.h>

static NSUInteger checks;
static void Check(BOOL pass, NSString *name) {
    checks++;
    if (!pass) { NSLog(@"FAIL: %@", name); exit(1); }
}
static NSDictionary *Item(NSDictionary *result) {
    return @{@"tweet_results": @{@"result": result}};
}
static NSDictionary *Entry(NSString *key, NSString *identifier, NSDictionary *result) {
    return @{key: identifier, @"content": @{@"itemContent": Item(result)}};
}
int main(void) {
    @autoreleasepool {
        NSDictionary *plain = @{@"legacy": @{@"full_text": @"Original tweet"}};
        NSDictionary *repost = @{@"legacy": @{@"retweeted_status_result": @{@"result": plain}}};
        NSDictionary *normalEntry = Entry(@"entryId", @"tweet-1", plain);
        NSDictionary *repostEntry = Entry(@"entryId", @"tweet-2", repost);
        NSDictionary *cursor = @{@"entryId": @"cursor-bottom", @"content": @{@"cursorType": @"Bottom", @"value": @"next-page"}};
        NSArray *entries = @[normalEntry, repostEntry, cursor];
        NSDictionary *response = @{@"data": @{@"home": @{@"instructions": @[@{@"type": @"TimelineAddEntries", @"entries": entries}]}}};
        BOOL changed = NO;
        id filtered = BHRDJSONObjectByFilteringReposts(response, &changed);
        NSArray *resultEntries = filtered[@"data"][@"home"][@"instructions"][0][@"entries"];
        Check(changed && [resultEntries isEqual:@[normalEntry, cursor]], @"Remove retweets; preserve originals, ordering and pagination cursor");
        Check([response[@"data"][@"home"][@"instructions"][0][@"entries"] count] == 3, @"Never mutate input response");
        NSDictionary *quote = @{@"legacy": @{@"full_text": @"Quoted comment"}, @"quoted_status_result": @{@"result": repost}};
        NSArray *quoteEntries = @[Entry(@"entryId", @"quote-1", quote)];
        changed = NO;
        Check(BHRDJSONObjectByFilteringReposts(quoteEntries, &changed) == quoteEntries && !changed, @"Preserve quote tweets, including quoted retweets");
        NSArray *wrapped = @[Entry(@"entry_id", @"tweet-3", @{@"tweet": repost})];
        Check([BHRDJSONObjectByFilteringReposts(wrapped, NULL) count] == 0, @"Support snake_case entry IDs and visibility wrappers");
        for (NSString *key in @[@"retweeted_status_result", @"retweeted_status", @"retweeted_status_id", @"retweeted_status_id_str"]) {
            NSArray *legacy = @[Entry(@"entryId", @"legacy", @{@"legacy": @{key: @"42"}})];
            Check([BHRDJSONObjectByFilteringReposts(legacy, NULL) count] == 0, [@"Support legacy marker: " stringByAppendingString:key]);
            for (id absent in @[NSNull.null, @0, @"0"]) {
                NSArray *nonReposts = @[Entry(@"entryId", @"original", @{@"legacy": @{key: absent}})];
                changed = NO;
                Check(BHRDJSONObjectByFilteringReposts(nonReposts, &changed) == nonReposts && !changed, @"Null / zero markers do not hide originals");
            }
        }
        for (NSString *itemsKey in @[@"items", @"moduleItems", @"module_items"]) {
            NSDictionary *originalItem = @{@"item": @{@"itemContent": Item(plain)}};
            NSDictionary *repostItem = @{@"item": @{@"itemContent": Item(repost)}};
            NSDictionary *module = @{@"entryId": @"module-1", @"content": @{itemsKey: @[originalItem, repostItem, originalItem, originalItem, repostItem]}};
            NSArray *modules = BHRDJSONObjectByFilteringReposts(@[module], NULL);
            Check([modules[0][@"content"][itemsKey] isEqual:@[originalItem, originalItem, originalItem]], @"Filter every module item; preserve unrelated items");
            NSDictionary *emptyModule = @{@"entryId": @"module-2", @"content": @{itemsKey: @[repostItem]}};
            Check([BHRDJSONObjectByFilteringReposts(@[emptyModule], NULL) count] == 0, @"Remove modules only when all items were reposts");
        }
        NSArray *malformed = @[NSNull.null, @1, @"text", @{@"entryId": @"odd", @"content": @"invalid"}];
        changed = NO;
        Check(BHRDJSONObjectByFilteringReposts(malformed, &changed) == malformed && !changed, @"Preserve unsupported and malformed entries");
        changed = NO;
        Check(BHRDJSONObjectByFilteringReposts(plain, &changed) == plain && !changed, @"Unrelated payload identity is preserved");
        NSData *data = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
        Check(BHRDDataMayContainReposts(data), @"Detect timeline payload before traversal");
        Check(!BHRDDataMayContainReposts([@"{\"retweeted_status\":1}" dataUsingEncoding:NSUTF8StringEncoding]), @"Skip non-timeline payloads");
        Check(!BHRDDataMayContainReposts(nil), @"Skip nil data");
        NSLog(@"PASS: %lu repost-filter checks", (unsigned long)checks);
    }
    return 0;
}
