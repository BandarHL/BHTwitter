#import <Foundation/Foundation.h>
#import "../BHRDContentFilter.h"
#import "../BHRDPreferences.h"
#import "../BHRDConfirmationGate.h"
#import <objc/runtime.h>
@interface Fixture : NSObject
@property(nonatomic, strong) id parentViewController;
@property(nonatomic, copy) NSString *entryID;
@property(nonatomic, copy) NSString *scribeComponent;
@end
@implementation Fixture @end
@interface TFNDataViewItem : NSObject
@property(nonatomic, strong) id item;
@end
@implementation TFNDataViewItem @end
static id Wrapped(id item) { TFNDataViewItem *w = [TFNDataViewItem new]; w.item = item; return w; }
static id Chrome(const char *name) {
    Class cls = objc_getClass(name);
    if (!cls) { cls = objc_allocateClassPair(NSObject.class,name,0); objc_registerClassPair(cls); }
    return [cls new];
}
static int checks;
static void Check(BOOL v) { checks++; if (!v) { NSLog(@"FAIL %d", checks); exit(1); } }
int main(void) { @autoreleasepool {
    NSArray *keys=@[BHRDHideTopicsKey,BHRDHideWhoKey,BHRDHideSuggestedTopicsKey,BHRDHidePremiumKey,BHRDHideTrendVideosKey];
    NSArray *markers=@[@"topic_recommendation",@"who_to_follow",@"topics_to_follow",@"premium_upsell",@"trending_videos"];
    for (NSUInteger i=0;i<keys.count;i++) {
        NSSet *enabled=[NSSet setWithObject:keys[i]];
        Check(BHRDContentPolicy(@"Module",nil,@{@"component":markers[i]},@"OTHER",enabled));
        Check(!BHRDContentPolicy(@"Module",nil,@{@"component":markers[i]},@"OTHER",[NSSet set]));
        Check(!BHRDContentPolicy(@"Module",nil,@{@"component":markers[(i+1)%5]},@"OTHER",enabled));
    }
    NSSet *all=[NSSet setWithArray:keys];
    Check(BHRDContentPolicy(@"Tweet",@"TFNTwitterURTTimelineStatusTopicBanner",nil,@"TIMELINE_HOME",all));
    Check(BHRDContentPolicy(@"T1URTTimelineUserItemViewModel",nil,nil,@"PROFILE_TWEETS",all));
    Check(!BHRDContentPolicy(@"T1URTTimelineUserItemViewModel",nil,nil,@"SEARCH",all));
    Check(BHRDContentPolicy(@"T1TwitterSwift.URTTimelineTopicCollectionViewModel",nil,nil,@"PROFILE_TWEETS",all));
    for (NSString *name in @[@"TwitterURT.URTModuleHeaderViewModel",@"TwitterURT.URTModuleFooterViewModel",@"T1URTTimelineMessageItemViewModel",@"OrganicTweet"]) {
        Check(!BHRDContentPolicy(name,nil,@{@"text":@"premium_upsell who_to_follow trending_videos"},@"OTHER",all));
    }
    Check(BHRDContentPolicy(@"T1TwitterSwift.URTTimelineCarouselViewModel",nil,nil,@"OTHER",all));
    Check(!BHRDContentPolicy(@"T1TwitterSwift.URTTimelineCarouselViewModel",nil,nil,@"TIMELINE_HOME",all));
    Check(!BHRDContentPolicy(@"T1TwitterSwift.URTTimelineCarouselViewModel",nil,nil,@"OTHER",[NSSet set]));
    Check(!BHRDContentPolicy(nil,nil,(id)NSNull.null,nil,all));
    BHRDConfirmationGate *gate=[BHRDConfirmationGate new]; __block int actions=0;
    Check([gate begin]); Check(![gate begin]); [gate cancel];
    [gate approve:^{ actions++; }]; Check(actions==0);
    Check([gate begin]); [gate approve:^{ Check(gate.depth==1); actions++; }];
    Check(actions==1 && gate.depth==0 && !gate.pending);
    [gate approve:^{ actions++; }]; Check(actions==1);
    [gate begin]; @try { [gate approve:^{ @throw [NSException exceptionWithName:@"test" reason:nil userInfo:nil]; }]; } @catch (__unused NSException *e) {}
    Check(gate.depth==0 && !gate.pending);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id previous = [defaults objectForKey:BHRDHideWhoKey];
    [defaults setBool:YES forKey:BHRDHideWhoKey];
    Fixture *who = [Fixture new]; who.scribeComponent = @"suggest_who_to_follow";
    Fixture *entry = [Fixture new]; entry.entryID = @"who-to-follow-123-user-456";
    Fixture *ordinary = [Fixture new]; ordinary.entryID = @"tweet-123";
    id controller = @{@"adDisplayLocation":@"TIMELINE_HOME"};
    Check(BHRDShouldHideRecommendation(Wrapped(who),controller));
    Check(BHRDShouldHideRecommendation(Wrapped(entry),controller));
    Check(!BHRDShouldHideRecommendation(Wrapped(ordinary),controller));
    id header=Wrapped(Chrome("TwitterURT.URTModuleHeaderViewModel"));
    id footer=Wrapped(Chrome("TwitterURT.URTModuleFooterViewModel"));
    NSArray *section=@[header,Wrapped(who),Wrapped(entry),footer,ordinary];
    NSArray *filtered=BHRDFilterRecommendations(@[section],controller);
    Check([filtered isEqual:@[@[ordinary]]]);
    Check(section.count==5);
    Check(BHRDFilterRecommendations(@[@[header,Wrapped(who),footer]],controller).count==0);
    Check([BHRDFilterRecommendations(@[@[header,Wrapped(who),ordinary,footer]],controller)[0] count]==3);
    Check([BHRDFilterRecommendations(@[@[header,Wrapped(who),ordinary]],controller)[0] count]==2);
    Check(BHRDFilterRecommendations(filtered,controller)==filtered);
    id profile = Chrome("T1ProfileViewController");
    Fixture *child = [Fixture new]; child.parentViewController = profile;
    id carousel = Chrome("T1TwitterSwift.URTTimelineCarouselViewModel");
    Check(BHRDShouldHideRecommendation(Wrapped(carousel), child));
    Check(!BHRDShouldHideRecommendation(Wrapped(carousel), controller));
    Check(BHRDFilterRecommendations(@[@[header,Wrapped(who)]],controller).count==0);
    Fixture *cycle = [Fixture new]; cycle.parentViewController = cycle;
    Check(!BHRDShouldHideRecommendation(ordinary,cycle)); cycle.parentViewController=nil;
    id oldPremium=[defaults objectForKey:BHRDHidePremiumKey];
    [defaults setBool:YES forKey:BHRDHidePremiumKey];
    Check(BHRDShouldHideRecommendation(Wrapped(Chrome("TwitterURT.URTTimelineMessageItemViewModel")),controller));
    [defaults setBool:NO forKey:BHRDHidePremiumKey];
    Check(!BHRDShouldHideRecommendation(Wrapped(Chrome("TwitterURT.URTTimelineMessageItemViewModel")),controller));
    if (oldPremium) [defaults setObject:oldPremium forKey:BHRDHidePremiumKey]; else [defaults removeObjectForKey:BHRDHidePremiumKey];
    [defaults setBool:NO forKey:BHRDHideWhoKey];
    NSArray *untouched=@[section]; Check(BHRDFilterRecommendations(untouched,controller)==untouched);
    if (previous) [defaults setObject:previous forKey:BHRDHideWhoKey]; else [defaults removeObjectForKey:BHRDHideWhoKey];
    NSLog(@"PASS: %d recommendation and confirmation checks",checks);
} return 0; }
