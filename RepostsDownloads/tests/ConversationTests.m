#import <Foundation/Foundation.h>
#import "../BHRDConversationScope.h"
#import "../BHRDRepostFilter.h"
@interface ScopeFixture : NSObject
@property(nonatomic, strong) id parentViewController;
@property(nonatomic, strong) id nextResponder;
@property(nonatomic, strong) id presentingViewController;
@property(nonatomic, copy) NSString *adDisplayLocation;
@end
@implementation ScopeFixture @end
@interface T1TweetDetailsViewController : ScopeFixture @end
@implementation T1TweetDetailsViewController @end
@interface T1ConversationContainerViewController : ScopeFixture @end
@implementation T1ConversationContainerViewController @end
@interface DetailSubclass : T1TweetDetailsViewController @end
@implementation DetailSubclass @end
@interface T1ConversationFocalStatusView : ScopeFixture @end
@implementation T1ConversationFocalStatusView @end
static NSUInteger undefinedReads;
@interface MissingScopeProperties : NSObject @end
@implementation MissingScopeProperties
- (id)valueForUndefinedKey:(NSString *)key { undefinedReads++; return [super valueForUndefinedKey:key]; }
@end
static int checks;
static void Check(BOOL value, NSString *message) {
    checks++; if (!value) { NSLog(@"FAIL: %@", message); exit(1); }
}
int main(void) { @autoreleasepool {
    Check(!BHRDIsConversationContext([MissingScopeProperties new]), @"Unknown model remains outside conversation");
    Check(undefinedReads == 0, @"Layout scope probes must not throw KVC exceptions for missing properties");
    ScopeFixture *home = [ScopeFixture new]; home.adDisplayLocation = @"TIMELINE_HOME";
    Check(!BHRDIsConversationContext(home), @"Home keeps filtering");
    Check(!BHRDIsConversationContext(nil), @"Unknown context keeps existing behavior");
    Check(BHRDIsConversationContext([DetailSubclass new]), @"Detail subclasses preserve content");
    Check(BHRDIsConversationContext([T1ConversationContainerViewController new]), @"Live X conversation container preserves focal post");
    ScopeFixture *child = [ScopeFixture new]; child.parentViewController = [T1TweetDetailsViewController new];
    Check(BHRDIsConversationContext(child), @"Embedded detail list preserves content");
    child.parentViewController = [T1ConversationContainerViewController new];
    Check(BHRDIsConversationContext(child), @"Live conversation child list preserves sections and height");
    ScopeFixture *cell = [ScopeFixture new]; cell.nextResponder = child;
    Check(BHRDIsConversationContext(cell), @"Cell responder chain protects native content");
    cell.nextResponder = home;
    Check(!BHRDIsConversationContext(cell), @"Reusing a cell on home restores filtering scope");
    Check(BHRDIsConversationContext([T1ConversationFocalStatusView new]), @"Focal status protects unknown detail controller");
    home.presentingViewController = child;
    Check(!BHRDIsConversationContext(home), @"Inactive presenting detail does not disable home filtering");
    ScopeFixture *cycle = [ScopeFixture new]; cycle.parentViewController = cycle;
    Check(!BHRDIsConversationContext(cycle), @"Malformed hierarchy terminates"); cycle.parentViewController = nil;
    home.adDisplayLocation = @"TWEET_DETAILS";
    Check(BHRDIsConversationContext(home), @"Semantic detail location supports unknown host classes");
    NSDictionary *repost = @{@"entryId":@"tweet-1", @"content":@{@"itemContent":@{@"tweet_results":@{@"result":@{@"legacy":@{@"retweeted_status_id_str":@"99"}}}}}};
    NSDictionary *original = @{@"entryId":@"tweet-2", @"content":@{@"itemContent":@{@"tweet_results":@{@"result":@{@"legacy":@{@"full_text":@"quoted post"}}}}}};
    NSArray *entries = @[repost, original];
    for (NSString *key in @[@"threaded_conversation_with_injections_v2", @"threaded_conversation_with_injections", @"tweet_detail", @"tweetDetail"]) {
        NSDictionary *response = @{@"data":@{key:@{@"entries":entries}}}; BOOL changed = NO;
        Check(BHRDJSONObjectByFilteringReposts(response, &changed) == response && !changed, @"Detail response retains focal post and replies");
    }
    NSDictionary *mixed = @{@"data":@{@"threaded_conversation_with_injections_v2":@{@"entries":entries}, @"home":@{@"entries":entries}}};
    BOOL changed = NO; NSDictionary *filtered = BHRDJSONObjectByFilteringReposts(mixed, &changed);
    Check(changed && [filtered[@"data"][@"home"][@"entries"] isEqual:@[original]], @"Sibling home timeline still hides reposts");
    Check(filtered[@"data"][@"threaded_conversation_with_injections_v2"] == mixed[@"data"][@"threaded_conversation_with_injections_v2"], @"Conversation subtree remains intact");
    NSLog(@"Passed %d conversation checks", checks);
} return 0; }
