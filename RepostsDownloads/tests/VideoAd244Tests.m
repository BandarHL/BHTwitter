#import <Foundation/Foundation.h>
#import "../BHRDAdFilter.h"
static NSUInteger checks;
static void Check(BOOL value, NSString *message) { checks++; if (!value) { NSLog(@"FAIL: %@",message); exit(1); } }
static NSDictionary *Entry(NSString *key, NSDictionary *body) {
    return @{@"entryId":key,@"sortIndex":@"99",@"content":@{@"entryType":@"TimelineTimelineItem",@"itemContent":body}};
}
static id Filter(id object,BOOL enabled,BOOL *changed) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    return BHRDFilterAdResponse(object,data,enabled,changed);
}
@interface VideoItem244 : NSObject
@property(nonatomic,strong) id representedStatus;
@end
@implementation VideoItem244 @end
int main(void) { @autoreleasepool {
    NSDictionary *organic=Entry(@"tweet-1",@{@"itemType":@"TimelineTweet",@"text":@"promoted-tweet-999 广告 ad_",@"promotedMetadata":NSNull.null});
    NSDictionary *ad=Entry(@"tweet-2",@{@"itemType":@"TimelineTweet",@"promotedMetadata":@{@"advertiser_results":@{}}});
    NSDictionary *idAd=Entry(@"promoted-tweet-3",@{@"itemType":@"TimelineTweet"});
    NSDictionary *cursor=@{@"entryId":@"cursor-bottom-1",@"content":@{@"entryType":@"TimelineTimelineCursor",@"cursorType":@"Bottom",@"value":@"next-video-page",@"promotedMetadata":@{@"ignored":@YES}}};
    NSDictionary *quote=Entry(@"tweet-4",@{@"itemType":@"TimelineTweet",@"quoted_status_result":ad});
    NSDictionary *instruction=@{@"type":@"TimelineAddEntries",@"entries":@[organic,ad,idAd,quote,cursor]};
    NSDictionary *response=@{@"data":@{@"video_timeline":@{@"instructions":@[instruction]}},@"extensions":@{@"other":@1}};
    BOOL changed=NO; NSDictionary *filtered=Filter(response,YES,&changed);
    NSArray *rows=filtered[@"data"][@"video_timeline"][@"instructions"][0][@"entries"];
    Check(changed,@"Video timeline response is filtered before pager construction");
    Check([rows isEqual:@[organic,quote,cursor]],@"Only promoted slots disappear; organic order and cursor remain");
    Check(rows[0]==organic && rows.lastObject==cursor,@"Untouched entries retain identity");
    Check([instruction[@"entries"] count]==5,@"Input response is never mutated");
    Check(filtered[@"extensions"]==response[@"extensions"],@"Unrelated response fields remain untouched");
    Check(Filter(response,NO,&changed)==response && !changed,@"Disabling hide-ads bypasses response changes");
    Check(Filter(filtered,YES,&changed)==filtered && !changed,@"Already clean response is returned unchanged");
    Check(!BHRDIsPromotedModel(organic),@"Ad words in text do not count as promotion");
    Check(!BHRDIsPromotedModel(quote),@"Quoted promotion does not classify its organic parent");
    Check(BHRDIsPromotedModel(ad),@"Nested itemContent promotion metadata is recognized");
    Check(BHRDIsPromotedModel(@{@"tweet":@{@"promoted_metadata":@{@"advertiser_id":@5}}}),@"Native tweet wrapper and snake-case metadata are covered");
    VideoItem244 *native=[VideoItem244 new]; native.representedStatus=@{@"isPromoted":@YES};
    Check(BHRDIsPromotedModel(native),@"Signature-checked representedStatus wrapper is covered");
    native.representedStatus=native; Check(!BHRDIsPromotedModel(native),@"Native wrapper cycles terminate");
    for (NSString *identifier in @[@"not-promoted-x",@"unpromoted-1",@"promoted-deal",@"tweet-1-promoted-tweet-2",@"promoted-tweet-no-id"])
        Check(!BHRDIsPromotedModel(Entry(identifier,@{})),@"Look-alike identifiers are preserved");
    for (NSString *identifier in @[@"promoted-tweet-10-hash",@"conversationthread-1-promoted-tweet-2-hash",@"search-conversation-1-promoted-tweet-2"])
        Check(BHRDIsPromotedModel(Entry(identifier,@{})),@"Explicit promoted entry identifier grammar is recognized");
    NSDictionary *moduleAd=@{@"entryId":@"module-ad",@"item":@{@"itemContent":@{@"itemType":@"TimelineTweet",@"promotedMetadata":@{@"id":@1}}}};
    NSDictionary *moduleGood=@{@"entryId":@"module-good",@"item":@{@"itemContent":@{@"itemType":@"TimelineTweet"}}};
    NSDictionary *module=@{@"entryId":@"module-1",@"content":@{@"entryType":@"TimelineTimelineModule",@"items":@[moduleAd,moduleGood]}};
    NSDictionary *modules=Filter(@{@"entries":@[module]},YES,&changed);
    Check([modules[@"entries"][0][@"content"][@"items"] isEqual:@[moduleGood]],@"Module filtering retains organic child entries");
    NSDictionary *empty=@{@"entryId":@"module-2",@"content":@{@"entryType":@"TimelineTimelineModule",@"items":@[moduleAd]}};
    Check([Filter(@{@"entries":@[empty,cursor]},YES,NULL)[@"entries"] isEqual:@[cursor]],@"All-ad modules are removed without removing the pagination cursor");
    NSDictionary *replace=@{@"type":@"TimelineReplaceEntry",@"entryIdToReplace":@"tweet-1",@"entry":ad};
    Check([Filter(@{@"instructions":@[replace,instruction]},YES,NULL)[@"instructions"] count]==1,@"Ad replacement instruction cannot insert a promoted page later");
    NSDictionary *addModule=@{@"type":@"TimelineAddToModule",@"moduleEntryId":@"module-1",@"moduleItems":@[moduleAd,moduleGood]};
    Check([Filter(@{@"instructions":@[addModule]},YES,NULL)[@"instructions"][0][@"moduleItems"] isEqual:@[moduleGood]],@"Incremental video module updates are filtered");
    NSDictionary *unknown=@{@"items":@[@{@"isPromoted":@YES,@"body":@"not a timeline slot"}]};
    Check(Filter(unknown,YES,&changed)==unknown && !changed,@"Non-timeline arrays are not rewritten");
    Check(!BHRDIsPromotedModel(@{@"promotedMetadata":@{},@"isPromoted":@NO}),@"Empty metadata and false flags do not hide a post");
    NSData *data=[NSJSONSerialization dataWithJSONObject:response options:0 error:NULL];
    NSMutableDictionary *mutable=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
    id mutableResult=Filter(mutable,YES,NULL);
    Check([mutableResult isKindOfClass:NSMutableDictionary.class],@"Requested mutable JSON containers remain mutable");
    Check([mutableResult[@"data"][@"video_timeline"][@"instructions"] isKindOfClass:NSMutableArray.class],@"Rebuilt nested arrays preserve mutable mode");
    id deep=response; for (NSUInteger i=0;i<55;i++) deep=@{@"wrapped":deep};
    Check(Filter(deep,YES,&changed)==deep && !changed,@"Depth exhaustion keeps the full original response");
    Check(BHRDFilterAdResponse(response,[NSMutableData dataWithLength:8*1024*1024+1],YES,&changed)==response && !changed,@"Oversized payload is left unchanged");
    Check([BHRDSectionsByRemovingAds(@[@[native,ad,organic]])[0] isEqual:@[native,organic]],@"Native section filtering shares wrapper detection without dropping organic entries");
    NSLog(@"PASS: %lu video ad response and model checks",(unsigned long)checks);
} return 0; }
