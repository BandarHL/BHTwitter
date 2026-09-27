#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../BHRDRepostPresentation.h"
@interface PreviewPost : NSObject
@property(nonatomic) BOOL isRetweet;
@property(nonatomic,copy) NSString *statusID;
@property(nonatomic,strong) id representedFromUser;
@property(nonatomic,strong) id fromUser;
@property(nonatomic,strong) id user;
@end
@implementation PreviewPost @end
@interface PreviewController : NSObject
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) id model;
@property(nonatomic,strong) id parentViewController;
- (id)itemAtIndexPath:(NSIndexPath *)path;
@end
@implementation PreviewController
- (id)itemAtIndexPath:(NSIndexPath *)path { (void)path; return self.model; }
@end
@interface TestConversationContainerViewController : NSObject @end
@implementation TestConversationContainerViewController @end
@interface AvatarTask : NSObject
@property(nonatomic,strong) NSURL *url;
@property(nonatomic,copy) void (^completion)(NSData *,NSURLResponse *,NSError *);
@property(nonatomic) BOOL cancelled;
- (void)resume;
- (void)cancel;
@end
@implementation AvatarTask
- (void)resume {}
- (void)cancel { self.cancelled=YES; }
@end
@interface AvatarSession : NSObject
@property(nonatomic,strong) NSMutableArray<AvatarTask *> *tasks;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *,NSURLResponse *,NSError *))completion;
@end
@implementation AvatarSession
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *,NSURLResponse *,NSError *))completion {
    AvatarTask *task=[AvatarTask new]; task.url=url; task.completion=completion; [self.tasks addObject:task]; return (NSURLSessionDataTask *)task;
}
@end
static NSUInteger checks;
static void Check(BOOL ok,NSString *message) { checks++; if (!ok) { NSLog(@"FAIL: %@",message); exit(1); } }
static PreviewPost *Post(NSString *identity,NSString *handle) {
    PreviewPost *post=[PreviewPost new]; post.statusID=identity; post.isRetweet=YES;
    if (handle) post.representedFromUser=@{@"username":handle,@"fullName":[handle uppercaseString],@"profileImageURL":[NSString stringWithFormat:@"https://pbs.twimg.com/profile_images/%@.jpg",handle]};
    post.user=post.representedFromUser;
    post.fromUser=@{@"username":@"retweeter",@"fullName":@"Retweeter",@"profileImageURL":@"https://pbs.twimg.com/profile_images/retweeter.jpg"};
    return post;
}
static UIView *Overlay(UITableViewCell *cell) {
    for (UIView *view in cell.subviews) if ([NSStringFromClass(view.class) isEqual:@"BHRDRepostOverlay"]) return view;
    return nil;
}
static NSString *Author(UITableViewCell *cell) { return [(UILabel *)[Overlay(cell) valueForKey:@"author"] text]; }
static NSData *Avatar(UITableViewCell *cell) { return [(UIImage *)[(UIImageView *)[Overlay(cell) valueForKey:@"avatar"] image] fixtureData]; }
static void Complete(AvatarTask *task,NSString *content) {
    NSURLResponse *response=[[NSURLResponse alloc] initWithURL:task.url MIMEType:@"image/jpeg" expectedContentLength:content.length textEncodingName:nil];
    task.completion([content dataUsingEncoding:NSUTF8StringEncoding],response,nil);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
}
int main(void) { @autoreleasepool {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    id oldHide=[defaults objectForKey:BHRDHideRepostsKey],oldMode=[defaults objectForKey:BHRDRepostModeKey];
    [defaults setBool:YES forKey:BHRDHideRepostsKey]; [defaults setInteger:BHRDRepostModePreview forKey:BHRDRepostModeKey];
    AvatarSession *session=[AvatarSession new]; session.tasks=[NSMutableArray array];
    Method shared=class_getClassMethod(NSURLSession.class,@selector(sharedSession));
    IMP replacement=imp_implementationWithBlock(^id(__unused id cls) { return session; });
    IMP original=method_setImplementation(shared,replacement);
    PreviewController *controller=[PreviewController new]; controller.tableView=[UITableView new]; controller.tableView.window=controller.tableView;
    UITableViewCell *cell=[[UITableViewCell alloc] initWithFrame:CGRectMake(0,0,390,172)]; cell.window=controller.tableView;
    UIView *native=[UIView new]; [cell addSubview:native];
    UILabel *staleLabel=[[UILabel alloc] initWithFrame:CGRectMake(60,10,220,24)]; staleLabel.text=@"ALICE @alice"; [native addSubview:staleLabel];
    UIImageView *staleAvatar=[[UIImageView alloc] initWithFrame:CGRectMake(10,10,40,40)]; staleAvatar.image=[UIImage imageWithData:[@"wrong-avatar" dataUsingEncoding:NSUTF8StringEncoding]]; [native addSubview:staleAvatar];
    controller.tableView.visibleCells=@[cell]; controller.model=Post(@"presentation-a",@"alice");
    BHRDConfigureRepostCell(cell,controller.model,controller);
    Check([Author(cell) isEqual:@"ALICE · @alice"],@"Production cell configuration ignores stale native author text");
    Check(![Avatar(cell) isEqual:[(UIImage *)staleAvatar.image fixtureData]],@"Matching header text cannot authorize a stale bitmap from another author");
    Check(native.hidden,@"Native row is hidden while preview overlay is active");
    AvatarTask *a=session.tasks.lastObject; Check([a.url.path hasSuffix:@"alice.jpg"],@"Avatar request belongs to the resolved original");
    Complete(a,@"alice-bytes"); Check([Avatar(cell) isEqual:[@"alice-bytes" dataUsingEncoding:NSUTF8StringEncoding]],@"Matching avatar response fills the preview");
    controller.model=Post(@"presentation-b",@"bob");
    BHRDConfigureRepostCell(cell,controller.model,controller); AvatarTask *b=session.tasks.lastObject;
    Check(a.cancelled && [b.url.path hasSuffix:@"bob.jpg"],@"Reuse cancels the old avatar and requests the new author's URL");
    Complete(b,@"bob-bytes"); Complete(a,@"late-alice-bytes");
    Check([Author(cell) isEqual:@"BOB · @bob"] && [Avatar(cell) isEqual:[@"bob-bytes" dataUsingEncoding:NSUTF8StringEncoding]],@"Late previous-row callback cannot combine Alice avatar with Bob name");
    controller.parentViewController=[TestConversationContainerViewController new]; BHRDLayoutRepostCell(cell);
    Check(!Overlay(cell) && !native.hidden,@"Entering detail restores native row and removes preview");
    controller.parentViewController=nil; controller.model=Post(@"presentation-b",nil); NSUInteger requests=session.tasks.count;
    BHRDRepostControllerDidAppear(controller);
    Check([Author(cell) isEqual:@"BOB · @bob"],@"Returning to timeline with a rebuilt partial model retains original name/handle");
    Check([Avatar(cell) isEqual:[@"bob-bytes" dataUsingEncoding:NSUTF8StringEncoding]],@"Returning to timeline restores the matching cached avatar");
    Check(session.tasks.count==requests,@"Return reuses cached author avatar without an unrelated download");
    for (NSUInteger i=0;i<3;i++) {
        BHRDRestoreRepostCell(cell); controller.model=Post(@"presentation-b",nil); BHRDRepostControllerDidAppear(controller);
        Check([Author(cell) isEqual:@"BOB · @bob"],@"Repeated view return does not regress to placeholder author");
    }
    controller.model=Post(@"presentation-c",nil); BHRDConfigureRepostCell(cell,controller.model,controller);
    Check([Author(cell) isEqual:@"转推作者"],@"Unknown different tweet cannot inherit a cached neighboring author's name");
    Check(![Avatar(cell) isEqual:[@"bob-bytes" dataUsingEncoding:NSUTF8StringEncoding]],@"Unknown different tweet cannot inherit neighboring avatar");
    controller.model=Post(@"presentation-correction",@"pending_old"); BHRDConfigureRepostCell(cell,controller.model,controller);
    AvatarTask *beforeCorrection=session.tasks.lastObject;
    controller.model=Post(@"presentation-correction",@"corrected"); BHRDConfigureRepostCell(cell,controller.model,controller);
    AvatarTask *afterCorrection=session.tasks.lastObject;
    Check(beforeCorrection.cancelled,@"Correcting author within the same tweet invalidates the previous avatar request");
    Complete(afterCorrection,@"corrected-bytes"); Complete(beforeCorrection,@"wrong-late-bytes");
    Check([Author(cell) isEqual:@"CORRECTED · @corrected"] && [Avatar(cell) isEqual:[@"corrected-bytes" dataUsingEncoding:NSUTF8StringEncoding]],@"Same-row author correction and reversed response order stay coherent");
    BHRDRestoreRepostCell(cell); controller.model=Post(@"presentation-correction",nil); BHRDRepostControllerDidAppear(controller);
    Check([Author(cell) isEqual:@"CORRECTED · @corrected"],@"Return after author correction cannot resurrect the former author");
    controller.model=Post(@"presentation-retry",@"retry"); BHRDConfigureRepostCell(cell,controller.model,controller);
    AvatarTask *failed=session.tasks.lastObject;
    failed.completion(nil,nil,[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
    Check([Author(cell) isEqual:@"RETRY · @retry"],@"Avatar download failure never removes the known author text");
    NSUInteger beforeRetry=session.tasks.count; BHRDRepostControllerDidAppear(controller);
    Check(session.tasks.count==beforeRetry+1,@"Returning to timeline retries a failed avatar request");
    Complete(session.tasks.lastObject,@"retry-bytes"); Complete(failed,@"stale-failed-request");
    Check([Avatar(cell) isEqual:[@"retry-bytes" dataUsingEncoding:NSUTF8StringEncoding]],@"Older callback cannot overwrite a successful retry on the same state");
    BHRDRestoreRepostCell(cell); BHRDRepostControllerDidAppear(controller);
    Check([Avatar(cell) isEqual:[@"retry-bytes" dataUsingEncoding:NSUTF8StringEncoding]],@"Late obsolete responses cannot poison the avatar cache used on the next return");
    BHRDRestoreRepostCell(cell); method_setImplementation(shared,original); imp_removeBlock(replacement);
    if (oldHide) [defaults setObject:oldHide forKey:BHRDHideRepostsKey]; else [defaults removeObjectForKey:BHRDHideRepostsKey];
    if (oldMode) [defaults setObject:oldMode forKey:BHRDRepostModeKey]; else [defaults removeObjectForKey:BHRDRepostModeKey];
    NSLog(@"PASS: %lu production repost presentation lifecycle checks",(unsigned long)checks);
} return 0; }
