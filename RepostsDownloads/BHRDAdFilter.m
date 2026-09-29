#import "BHRDAdFilter.h"
#import "BHRDModelAccess.h"
#import "BHRDAvatarDiagnostics.h"
static id Read(id object, NSString *key) {
    if (!object || object == NSNull.null) return nil;
    return BHRDModelValue(object, key);
}
static BOOL Marked(id object) {
    // Exact native model families observed in X 12.24.1. No invented JSON
    // payload schema: these can also be created after response hydration.
    for (Class cls=[object class]; cls && cls!=NSObject.class; cls=class_getSuperclass(cls)) {
        NSString *name=NSStringFromClass(cls);
        if ([name hasSuffix:@"URTTimelineGoogleNativeAdViewModel"] || [name hasSuffix:@"ImmersiveGoogleNativeAdCardViewModel"]) {
            BHRDAvatarLog(@"immersive_ad_model",@{@"class":name,@"recognized":@YES});
            return YES;
        }
    }
    id identifier=Read(object,@"entryId") ?: Read(object,@"entry_id");
    if (([identifier isKindOfClass:NSString.class] && [identifier hasPrefix:@"cursor-"]) || Read(object,@"cursorType") ||
        [Read(object,@"entryType") isEqual:@"TimelineTimelineCursor"] || [Read(object,@"__typename") isEqual:@"TimelineTimelineCursor"]) return NO;
    id promoted = Read(object, @"isPromoted");
    if ([promoted isKindOfClass:NSNumber.class] && [promoted boolValue]) return YES;
    id marker = Read(Read(object, @"scribeItem"), @"promoted_id");
    if (([marker isKindOfClass:NSString.class] && [marker length] > 0) ||
        ([marker isKindOfClass:NSNumber.class] && [marker unsignedLongLongValue] > 0)) return YES;
    for (NSString *key in @[@"promotedMetadata",@"promoted_metadata"]) {
        id metadata=Read(object,key);
        if ([metadata isKindOfClass:NSDictionary.class] && [metadata count]>0) return YES;
        if (metadata && ![metadata isKindOfClass:NSDictionary.class] &&
            [NSStringFromClass([metadata class]).lowercaseString containsString:@"promotedmetadata"]) return YES;
    }
    static NSRegularExpression *pattern; static dispatch_once_t once;
    dispatch_once(&once,^{ pattern=[NSRegularExpression regularExpressionWithPattern:@"^(?:(?:conversationthread|search-conversation)-[0-9]+-)?promoted-tweet-[0-9]+(?:-[A-Za-z0-9_]+)*$" options:0 error:NULL]; });
    for (NSString *key in @[@"entryId",@"entryID",@"entry_id"]) {
        id identifier=Read(object,key);
        if ([identifier isKindOfClass:NSString.class] && [identifier length]<=256 &&
            [pattern numberOfMatchesInString:identifier options:0 range:NSMakeRange(0,[identifier length])]) return YES;
    }
    return NO;
}
BOOL BHRDIsPromotedModel(id model) {
    model = BHRDUnwrapModel(model);
    if (!model) return NO;
    NSMutableArray *pending=[NSMutableArray arrayWithObject:model]; NSMutableSet *seen=[NSMutableSet set];
    while (pending.count && seen.count<32) {
        id item=pending.firstObject; [pending removeObjectAtIndex:0];
        NSValue *address=[NSValue valueWithNonretainedObject:item]; if ([seen containsObject:address]) continue;
        [seen addObject:address];
        if (Marked(item)) return YES;
        // Only wrappers of this entry, never quoted/reposted content, author,
        // captions, arbitrary descendants or a neighboring entry's metadata.
        for (NSString *key in @[@"status",@"tweet",@"representedStatus",@"viewModel",@"item",@"content",@"itemContent",@"item_content"]) {
            id child=Read(item,key);
            if (child && child!=item && ![child isKindOfClass:NSString.class] && ![child isKindOfClass:NSNumber.class] && ![child isKindOfClass:NSArray.class]) [pending addObject:child];
        }
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

static NSDictionary *Dictionary(id value) { return [value isKindOfClass:NSDictionary.class] ? value : nil; }
static BOOL TimelineItem(id value) {
    NSDictionary *item=Dictionary(value); if (!item) return NO;
    NSDictionary *content=Dictionary(item[@"content"]);
    NSString *identifier=item[@"entryId"] ?: item[@"entry_id"];
    if ([identifier isKindOfClass:NSString.class] && content) {
        // Cursor/control entries retain their original order and values even if
        // the server attaches extra metadata to them.
        if ([identifier hasPrefix:@"cursor-"] || content[@"cursorType"] ||
            [content[@"entryType"] isEqual:@"TimelineTimelineCursor"] || [content[@"__typename"] isEqual:@"TimelineTimelineCursor"]) return NO;
        return YES;
    }
    NSDictionary *body=Dictionary(item[@"itemContent"]) ?: Dictionary(Dictionary(item[@"item"])[@"itemContent"]);
    return [body[@"itemType"] isEqual:@"TimelineTweet"] || [body[@"__typename"] isEqual:@"TimelineTweet"];
}
static BOOL EmptyModule(id before, id after) {
    NSDictionary *old=Dictionary(Dictionary(before)[@"content"]), *current=Dictionary(Dictionary(after)[@"content"]);
    if (![old[@"entryType"] isEqual:@"TimelineTimelineModule"] && ![old[@"__typename"] isEqual:@"TimelineTimelineModule"]) return NO;
    for (NSString *key in @[@"items",@"moduleItems",@"module_items"])
        if ([old[key] isKindOfClass:NSArray.class] && [old[key] count]>0 && [current[key] isKindOfClass:NSArray.class] && [current[key] count]==0) return YES;
    return NO;
}
static id FilterJSON(id object, NSString *parentKey, NSUInteger depth, NSUInteger *budget, BOOL *exhausted, BOOL mutableContainers) {
    if (depth>48 || !*budget) { *exhausted=YES; return object; }
    (*budget)--;
    if ([object isKindOfClass:NSArray.class]) {
        BOOL entries=[@[@"entries",@"items",@"moduleItems",@"module_items"] containsObject:parentKey ?: @""];
        NSMutableArray *result=nil; NSUInteger index=0;
        for (id item in object) {
            BOOL remove=entries && TimelineItem(item) && BHRDIsPromotedModel(item);
            if ([parentKey isEqual:@"instructions"] && [Dictionary(item)[@"type"] isEqual:@"TimelineReplaceEntry"])
                remove=TimelineItem(item[@"entry"]) && BHRDIsPromotedModel(item[@"entry"]);
            if (remove) { if (!*budget) { *exhausted=YES; return object; } (*budget)--; }
            id filtered=remove ? item : FilterJSON(item,nil,depth+1,budget,exhausted,mutableContainers);
            if (*exhausted) return object;
            if (entries && !remove && EmptyModule(item,filtered)) remove=YES;
            if ((remove || filtered!=item) && !result) result=[[object subarrayWithRange:NSMakeRange(0,index)] mutableCopy];
            if (result && !remove) [result addObject:filtered];
            index++;
        }
        return result ? (mutableContainers ? result : [result copy]) : object;
    }
    if ([object isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *result=nil;
        for (NSString *key in object) {
            // Embedded posts are content, not slots in the current video feed.
            if ([@[@"quoted_status",@"quoted_status_result",@"retweeted_status",@"retweeted_status_result"] containsObject:key]) continue;
            id value=object[key];
            id filtered=FilterJSON(value,key,depth+1,budget,exhausted,mutableContainers);
            if (*exhausted) return object;
            if (filtered!=value) { if (!result) result=[object mutableCopy]; result[key]=filtered; }
        }
        return result ? (mutableContainers ? result : [result copy]) : object;
    }
    return object;
}
id BHRDFilterAdResponse(id object, NSData *data, BOOL enabled, BOOL *changed) {
    if (changed) *changed=NO;
    if (!enabled || !object || !data.length || data.length>8*1024*1024) {
        BHRDAvatarLog(@"ad_response_seen",@{@"bytes":@(data.length),@"eligible":@NO,@"enabled":@(enabled)});
        return object;
    }
    BOOL marker=NO;
    for (NSString *key in @[@"\"promotedMetadata\"",@"\"promoted_metadata\"",@"promoted-tweet-",@"\"isPromoted\"",@"\"promoted_id\""]) {
        NSData *needle=[key dataUsingEncoding:NSUTF8StringEncoding];
        if ([data rangeOfData:needle options:0 range:NSMakeRange(0,data.length)].location!=NSNotFound) { marker=YES; break; }
    }
    BHRDAvatarLog(@"ad_response_seen",@{@"bytes":@(data.length),@"eligible":@YES,@"enabled":@YES,@"marker":@(marker)});
    if (!marker) return object;
    NSUInteger budget=50000; BOOL exhausted=NO;
    BOOL mutableContainers=[object isKindOfClass:NSMutableDictionary.class] || [object isKindOfClass:NSMutableArray.class];
    id result=FilterJSON(object,nil,0,&budget,&exhausted,mutableContainers);
    if (exhausted) return object; // No partially filtered response on budget exhaustion.
    BHRDAvatarLog(@"ad_response_checked",@{@"bytes":@(data.length),@"changed":@(result!=object)});
    if (changed) *changed=result!=object;
    return result;
}
