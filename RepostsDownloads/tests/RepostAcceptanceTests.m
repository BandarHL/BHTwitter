#import <UIKit/UIKit.h>
#import "../BHRDRepostPresentation.h"
#import "../BHRDAvatarDiagnostics.h"
#import "../BHRDAcceptance.h"

// This models controller identity and lifecycle callbacks, not UIKit navigation.
// Device acceptance still requires the actual hook and controller hierarchy.
@interface AcceptanceRepost : NSObject
@property(nonatomic) BOOL isRetweet;
@property(nonatomic,copy) NSString *statusID;
@property(nonatomic,strong) id retweetedStatus;
@end
@implementation AcceptanceRepost @end
@interface AcceptanceTimeline : NSObject
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) id model;
- (id)itemAtIndexPath:(NSIndexPath *)path;
@end
@implementation AcceptanceTimeline
- (id)itemAtIndexPath:(NSIndexPath *)path { return self.model; }
@end
@interface AcceptanceConversationViewController : NSObject
@property(nonatomic,strong) UIView *viewIfLoaded;
@property(nonatomic,copy) NSString *focalStatusID;
@property(nonatomic,strong) id viewModel;
@property(nonatomic,strong) id quotedStatus;
@end
@implementation AcceptanceConversationViewController @end
@interface AcceptanceGenericController : NSObject
@property(nonatomic,strong) UIView *viewIfLoaded;
@property(nonatomic,copy) NSString *statusID;
@end
@implementation AcceptanceGenericController @end
@interface AcceptanceSelection : NSObject
@property(nonatomic) NSUInteger selections;
@property(nonatomic,copy) void (^didSelect)(void);
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path;
@end
@implementation AcceptanceSelection
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path { self.selections++; if (self.didSelect) self.didSelect(); }
@end
static NSUInteger Checks;
static void Check(BOOL condition,NSString *message) { Checks++; if (!condition) { NSLog(@"FAIL: %@",message); exit(1); } }
static NSArray *Events(NSString *name) {
    BHRDAvatarDiagnosticFlush(); BHRDAcceptanceFlush();
    NSString *text=[NSString stringWithContentsOfFile:BHRDAvatarDiagnosticPath() encoding:NSUTF8StringEncoding error:NULL];
    NSMutableArray *events=[NSMutableArray array];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        id event=[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        if ([event isKindOfClass:NSDictionary.class] && [event[@"event"] isEqual:name]) [events addObject:event];
    }
    return events;
}
static UIView *Card(UITableViewCell *cell) {
    for (UIView *view in cell.subviews) if ([NSStringFromClass(view.class) isEqual:@"BHRDRepostOverlay"]) return view;
    return nil;
}
static NSDictionary *Tap(AcceptanceTimeline *timeline,UITableViewCell *cell) {
    BHRDRepostControllerDidAppear(timeline);
    BHRDConfigureRepostCell(cell,timeline.model,timeline);
    [(UIControl *)Card(cell) sendActionsForControlEvents:UIControlEventTouchUpInside];
    return Events(@"repost_detail_navigation").lastObject;
}
int main(void) { @autoreleasepool {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    id oldHide=[defaults objectForKey:BHRDHideRepostsKey],oldMode=[defaults objectForKey:BHRDRepostModeKey];
    [defaults setBool:YES forKey:BHRDHideRepostsKey]; [defaults setInteger:BHRDRepostModePreview forKey:BHRDRepostModeKey];
    NSString *acceptanceSession=BHRDAcceptanceBeginSession()[@"sessionID"];
    UIView *window=[UIView new]; AcceptanceTimeline *timeline=[AcceptanceTimeline new]; timeline.tableView=[UITableView new]; timeline.tableView.window=window;
    UITableViewCell *cell=[[UITableViewCell alloc] initWithFrame:CGRectMake(0,0,390,172)]; cell.window=window;
    UIView *native=[[UIView alloc] initWithFrame:cell.bounds]; [cell addSubview:native]; timeline.tableView.visibleCells=@[cell];
    AcceptanceRepost *post=[AcceptanceRepost new]; post.isRetweet=YES; post.statusID=@"2480001";
    post.retweetedStatus=@{@"id_str":@"2480002",@"user":@{@"screen_name":@"original_user",@"name":@"Original"}}; timeline.model=post;
    AcceptanceSelection *selection=[AcceptanceSelection new]; timeline.tableView.delegate=selection;
    NSDictionary *request=Tap(timeline,cell);
    Check([request[@"result"] isEqual:@"native_row_selection"] && [request[@"attempt"] length]>0,@"Native selection records one request identity");
    Check([request[@"acceptanceSession"] isEqual:acceptanceSession],@"Request retains the active acceptance session");
    Check([request[@"post"] isEqual:@"2480002"],@"Expected detail uses the original post identity instead of repost row ID");
    Check(selection.selections==1 && native.hidden && Card(cell),@"Observing the request does not expand or alter the native route");
    BHRDRepostControllerDidAppear(timeline);
    Check(Events(@"repost_detail_return").count==0,@"A timeline callback without a detail never reports a completed round trip");
    AcceptanceGenericController *generic=[AcceptanceGenericController new]; generic.viewIfLoaded=[UIView new]; generic.viewIfLoaded.window=window; generic.statusID=@"2480002";
    BHRDRepostControllerDidAppear(generic);
    Check(Events(@"repost_detail_visible").count==0,@"Matching ID on an unrelated controller cannot confirm detail appearance");
    AcceptanceConversationViewController *detail=[AcceptanceConversationViewController new]; detail.viewIfLoaded=[UIView new]; detail.focalStatusID=@"2480002";
    BHRDRepostControllerDidAppear(detail);
    Check(Events(@"repost_detail_visible").count==0,@"A detached detail cannot confirm appearance");
    UIView *otherWindow=[UIView new]; detail.viewIfLoaded.window=otherWindow; BHRDRepostControllerDidAppear(detail);
    Check(Events(@"repost_detail_visible").count==0,@"A detail in another window cannot satisfy the timeline request");
    detail.viewIfLoaded.window=window; detail.viewIfLoaded.hidden=YES; BHRDRepostControllerDidAppear(detail);
    Check(Events(@"repost_detail_visible").count==0,@"A hidden detail view cannot confirm appearance");
    detail.viewIfLoaded.hidden=NO; detail.focalStatusID=nil; detail.quotedStatus=@{@"id_str":@"2480002"};
    BHRDRepostControllerDidAppear(detail); NSDictionary *visible=Events(@"repost_detail_visible").lastObject;
    Check(![visible[@"confirmed"] boolValue] && [visible[@"result"] isEqual:@"detail_identity_unavailable"],@"Quoted identity is ignored and an unknown focal identity stays unconfirmed");
    Check([visible[@"attempt"] isEqual:request[@"attempt"]],@"Unconfirmed detail evidence stays attached to the same attempt");
    detail.focalStatusID=@"2480001"; BHRDRepostControllerDidAppear(detail); visible=Events(@"repost_detail_visible").lastObject;
    Check(![visible[@"confirmed"] boolValue] && [visible[@"result"] isEqual:@"detail_identity_mismatch"],@"The repost row ID does not substitute for the requested original detail");
    detail.focalStatusID=@"2480002"; BHRDRepostControllerDidAppear(detail); visible=Events(@"repost_detail_visible").lastObject;
    Check([visible[@"confirmed"] boolValue] && [visible[@"result"] isEqual:@"detail_identity_matched"],@"A visible recognized detail with the original focal identity is confirmed");
    Check([visible[@"attempt"] isEqual:request[@"attempt"]] && [visible[@"acceptanceSession"] isEqual:acceptanceSession],@"Confirmed detail is correlated to its request and session");
    NSUInteger count=Events(@"repost_detail_visible").count; BHRDRepostControllerDidAppear(detail);
    Check(Events(@"repost_detail_visible").count==count,@"Repeated nested appearance callbacks do not duplicate confirmed detail evidence");
    BHRDRepostControllerDidAppear(timeline); NSDictionary *returned=Events(@"repost_detail_return").lastObject;
    Check([returned[@"confirmed"] boolValue] && [returned[@"observable"] boolValue] && [returned[@"hiddenPreserved"] boolValue],@"Return confirms the actual bound visible row still has its hidden native subtree");
    Check([returned[@"attempt"] isEqual:request[@"attempt"]],@"Return evidence correlates to the completed request");
    count=Events(@"repost_detail_return").count; BHRDRepostControllerDidAppear(timeline);
    Check(Events(@"repost_detail_return").count==count,@"Repeated timeline callbacks do not recount the same return");
    request=Tap(timeline,cell); detail.focalStatusID=nil; detail.viewModel=@{@"focalStatus":@{@"id_str":@"2480002"}};
    BHRDRepostControllerDidAppear(detail); visible=Events(@"repost_detail_visible").lastObject;
    Check([visible[@"confirmed"] boolValue],@"Bounded focal view-model traversal recognizes the original detail");
    timeline.tableView.visibleCells=@[]; BHRDRepostControllerDidAppear(timeline); returned=Events(@"repost_detail_return").lastObject;
    Check(![returned[@"observable"] boolValue] && [returned[@"result"] isEqual:@"return_row_not_observable"],@"An offscreen target is explicitly unobservable instead of declared expanded");
    timeline.tableView.visibleCells=@[cell]; request=Tap(timeline,cell); detail.viewModel=nil; detail.focalStatusID=@"2480002"; BHRDRepostControllerDidAppear(detail);
    [defaults setBool:NO forKey:BHRDHideRepostsKey]; BHRDRepostControllerDidAppear(timeline); returned=Events(@"repost_detail_return").lastObject;
    Check([returned[@"observable"] boolValue] && [returned[@"confirmed"] boolValue] && ![returned[@"hiddenPreserved"] boolValue],@"A visible original row restored during return cannot falsely pass hidden preservation");
    [defaults setBool:YES forKey:BHRDHideRepostsKey]; request=Tap(timeline,cell);
    NSString *formerSession=request[@"acceptanceSession"],*nextSession=BHRDAcceptanceBeginSession()[@"sessionID"];
    BHRDRepostControllerDidAppear(detail); visible=Events(@"repost_detail_visible").lastObject;
    Check(![formerSession isEqual:nextSession] && [visible[@"acceptanceSession"] isEqual:formerSession],@"Starting a new acceptance cannot relabel an older asynchronous navigation");
    BHRDRepostControllerDidAppear(timeline);
    selection.didSelect=^{ BHRDRepostControllerDidAppear(detail); };
    request=Tap(timeline,cell); NSArray *allVisible=Events(@"repost_detail_visible"); visible=allVisible.lastObject;
    Check([visible[@"confirmed"] boolValue] && [visible[@"attempt"] isEqual:request[@"attempt"]],@"A synchronous host detail appearance is associated because request logging precedes dispatch");
    BHRDRepostControllerDidAppear(timeline); selection.didSelect=nil;
    BHRDRestoreRepostCell(cell);
    if (oldHide) [defaults setObject:oldHide forKey:BHRDHideRepostsKey]; else [defaults removeObjectForKey:BHRDHideRepostsKey];
    if (oldMode) [defaults setObject:oldMode forKey:BHRDRepostModeKey]; else [defaults removeObjectForKey:BHRDRepostModeKey];
    NSLog(@"PASS: %lu production repost acceptance observation checks",(unsigned long)Checks);
} return 0; }
