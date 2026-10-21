#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../BHRDRepostPresentation.h"
#import "../BHRDAvatarDiagnostics.h"
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
@interface NativeSelectionDelegate : NSObject
@property(nonatomic,weak) PreviewController *controller;
@property(nonatomic) NSUInteger selections;
@property(nonatomic,strong) NSIndexPath *lastPath;
@property(nonatomic,strong) id selectedModel;
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path;
@end
@implementation NativeSelectionDelegate
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    self.selections++; self.lastPath=path; self.selectedModel=[self.controller itemAtIndexPath:path];
}
@end
@interface WrongSelectionDelegate : NSObject
@property(nonatomic) NSUInteger calls;
- (id)tableView:(id)table didSelectRowAtIndexPath:(id)path;
@end
@implementation WrongSelectionDelegate
- (id)tableView:(id)table didSelectRowAtIndexPath:(id)path { self.calls++; return nil; }
@end
@interface TestConversationContainerViewController : NSObject @end
@implementation TestConversationContainerViewController @end
@interface TUIAvatarImageView : UIImageView
@property(nonatomic,strong) id user;
@property(nonatomic,strong) id userViewModel;
@end
@implementation TUIAvatarImageView @end
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
    controller.model=Post(@"242-late-avatar",nil);
    [(PreviewPost *)controller.model setRepresentedFromUser:@{@"username":@"late_view_242",@"fullName":@"Late View"}];
    BHRDConfigureRepostCell(cell,controller.model,controller); requests=session.tasks.count;
    Check([Author(cell) isEqual:@"Late View · @late_view_242"],@"Avatar absence does not hide the resolved name");
    BHRDCacheRepostMetadata(@{@"__typename":@"User",@"rest_id":@"242-view",@"core":@{@"screen_name":@"late_view_242"},@"avatar":@{@"image_url":@"https://pbs.twimg.com/profile_images/242-view.jpg"}});
    BHRDRepostMetadataChanged();
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    Check(session.tasks.count==requests+1 && [session.tasks.lastObject.url.path hasSuffix:@"242-view.jpg"],@"Late profile response starts avatar loading on the visible row without navigation");
    NSData *binary=[@"binary-avatar" dataUsingEncoding:NSUTF8StringEncoding];
    NSURLResponse *binaryResponse=[[NSURLResponse alloc] initWithURL:session.tasks.lastObject.url MIMEType:@"application/octet-stream" expectedContentLength:binary.length textEncodingName:nil];
    session.tasks.lastObject.completion(binary,binaryResponse,nil);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
    Check([Avatar(cell) isEqual:binary],@"Binary MIME response is passed through image decoding");
    controller.model=Post(@"242-auto-retry",@"auto_retry_242"); BHRDConfigureRepostCell(cell,controller.model,controller);
    AvatarTask *automatic=session.tasks.lastObject; requests=session.tasks.count;
    NSError *timeout=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    automatic.completion(nil,nil,timeout);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.15]];
    Check(session.tasks.count==requests+1,@"First failure retries automatically while the same row remains visible");
    session.tasks.lastObject.completion(nil,nil,timeout);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3.15]];
    Check(session.tasks.count==requests+2,@"Second failure uses a bounded delayed retry");
    session.tasks.lastObject.completion(nil,nil,timeout);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3.15]];
    Check(session.tasks.count==requests+2,@"Three failed attempts stop rather than looping indefinitely");
    controller.model=Post(@"242-cancel-backoff",@"backoff_242"); BHRDConfigureRepostCell(cell,controller.model,controller);
    session.tasks.lastObject.completion(nil,nil,timeout);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
    controller.model=Post(@"242-reused-backoff",@"reuse_242"); BHRDConfigureRepostCell(cell,controller.model,controller);
    requests=session.tasks.count; Complete(session.tasks.lastObject,@"reuse-242-bytes");
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.15]];
    Check(session.tasks.count==requests && [Avatar(cell) isEqual:[@"reuse-242-bytes" dataUsingEncoding:NSUTF8StringEncoding]],@"A discarded row's scheduled retry cannot restart its request or replace the new avatar");
    TUIAvatarImageView *nativeAvatar=[[TUIAvatarImageView alloc] initWithFrame:CGRectMake(10,10,47,47)]; [native addSubview:nativeAvatar];
    NSDictionary *nativeUser=@{@"userID":@24301,@"username":@"native243",@"fullName":@"Native Author"};
    PreviewPost *nativePost=Post(@"243-late-native",nil); nativePost.representedFromUser=nativeUser;
    nativeAvatar.user=nativeUser; controller.model=nativePost;
    BHRDConfigureRepostCell(cell,controller.model,controller); requests=session.tasks.count;
    Check(![Avatar(cell) isEqual:[@"native-243" dataUsingEncoding:NSUTF8StringEncoding]],@"Missing native bitmap starts as placeholder");
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.7]];
    nativeAvatar.image=[UIImage imageWithData:[@"native-243" dataUsingEncoding:NSUTF8StringEncoding]];
    // No setImage hook notification: the bounded poll must find the late image.
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    Check([Avatar(cell) isEqual:[@"native-243" dataUsingEncoding:NSUTF8StringEncoding]],@"No-URL polling displays a late bitmap from the verified native user");
    Check(session.tasks.count==requests,@"Native fallback does not invent an avatar network request");
    nativeAvatar.image=[UIImage imageWithData:[@"native-new-243" dataUsingEncoding:NSUTF8StringEncoding]];
    BHRDRepostNativeImageChanged(nativeAvatar);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
    Check([Avatar(cell) isEqual:[@"native-new-243" dataUsingEncoding:NSUTF8StringEncoding]],@"Native image notification updates an already displayed avatar");
    BHRDRestoreRepostCell(cell); BHRDRepostControllerDidAppear(controller);
    Check([Avatar(cell) isEqual:[@"native-new-243" dataUsingEncoding:NSUTF8StringEncoding]],@"Return uses the matching image assignment stamp without losing avatar");
    NSDictionary *secondUser=@{@"userID":@24302,@"username":@"second243",@"fullName":@"Second Author"};
    nativeAvatar.user=secondUser;
    nativePost=Post(@"243-reused-native",nil); nativePost.representedFromUser=secondUser; controller.model=nativePost;
    BHRDConfigureRepostCell(cell,controller.model,controller);
    Check(![Avatar(cell) isEqual:[@"native-new-243" dataUsingEncoding:NSUTF8StringEncoding]],@"New user binding alone cannot authorize the previous user's pixels");
    nativeAvatar.image=[UIImage imageWithData:[@"second-243" dataUsingEncoding:NSUTF8StringEncoding]]; BHRDRepostNativeImageChanged(nativeAvatar);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
    Check([Avatar(cell) isEqual:[@"second-243" dataUsingEncoding:NSUTF8StringEncoding]],@"Reused row displays the new image only after matching assignment");
    nativePost=Post(@"243-conflicting-native",nil); nativePost.representedFromUser=nativeUser; controller.model=nativePost;
    nativeAvatar.user=@{@"userID":@24399,@"username":@"native243"};
    BHRDConfigureRepostCell(cell,controller.model,controller);
    nativeAvatar.image=[UIImage imageWithData:[@"wrong-id-243" dataUsingEncoding:NSUTF8StringEncoding]]; BHRDRepostNativeImageChanged(nativeAvatar);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
    Check(![Avatar(cell) isEqual:[@"wrong-id-243" dataUsingEncoding:NSUTF8StringEncoding]],@"Matching handle never overrides conflicting native numeric user ID");
    nativeAvatar.user=nil; nativeAvatar.userViewModel=@{@"user":nativeUser};
    nativeAvatar.image=[UIImage imageWithData:[@"view-model-243" dataUsingEncoding:NSUTF8StringEncoding]]; BHRDRepostNativeImageChanged(nativeAvatar);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
    Check([Avatar(cell) isEqual:[@"view-model-243" dataUsingEncoding:NSUTF8StringEncoding]],@"Native userViewModel.user can prove avatar identity");
    nativePost=Post(@"243-no-native-owner",nil); nativePost.representedFromUser=nativeUser; controller.model=nativePost;
    nativeAvatar.userViewModel=nil; BHRDConfigureRepostCell(cell,controller.model,controller);
    nativeAvatar.image=[UIImage imageWithData:[@"unowned-243" dataUsingEncoding:NSUTF8StringEncoding]]; BHRDRepostNativeImageChanged(nativeAvatar);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
    Check(![Avatar(cell) isEqual:[@"unowned-243" dataUsingEncoding:NSUTF8StringEncoding]],@"Avatar class and geometry cannot substitute for native account identity");
    nativeAvatar.user=nativeUser; nativeAvatar.image=nil; BHRDRepostNativeImageChanged(nativeAvatar);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]]; BHRDLayoutRepostCell(cell);
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(NULL,32,32,8,0,space,(CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGImageRef cgimage=CGBitmapContextCreateImage(context); nativeAvatar.layer.contents=(__bridge id)cgimage;
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]]; BHRDLayoutRepostCell(cell);
    UIImage *layerAvatar=[(UIImageView *)[Overlay(cell) valueForKey:@"avatar"] image];
    Check(layerAvatar.CGImage==cgimage,@"Layer-only late native avatar works with the same identity guard");
    CGImageRelease(cgimage); CGContextRelease(context); CGColorSpaceRelease(space);
    // Tap the actual production overlay and call the same selection boundary
    // that a normal host row uses. No test-only navigation implementation.
    BHRDRestoreRepostCell(cell); controller.model=Post(@"245-detail-card",@"detail_author");
    NativeSelectionDelegate *navigation=[NativeSelectionDelegate new]; navigation.controller=controller; controller.tableView.delegate=navigation;
    BHRDConfigureRepostCell(cell,controller.model,controller); UIView *card=Overlay(cell); [card layoutSubviews];
#if BHRD_AVATAR_DIAGNOSTICS
    // A synthetic test emits all initial model/view samples in one burst.
    // Drain those before testing navigation events under the bounded log queue.
    BHRDAvatarDiagnosticFlush();
#endif
    NSUInteger reloads=controller.tableView.fixtureReloadCount;
    NSArray *points=@[@[@8,@8],@[@60,@26],@[@30,@66],@[@120,@66],@[@120,@120],@[@335,@28],@[@385,@168]];
    for (NSArray *point in points) {
        UIView *hit=[card hitTest:CGPointMake([point[0] doubleValue],[point[1] doubleValue]) withEvent:nil];
        Check(hit==card && [hit isKindOfClass:UIControl.class],@"Title, avatar, author, thumbnail, button, blank space and edge share one card action");
        NSUInteger before=navigation.selections;
        [(UIControl *)hit sendActionsForControlEvents:UIControlEventTouchUpInside];
        [(UIControl *)hit sendActionsForControlEvents:UIControlEventTouchUpInside];
        Check(navigation.selections==before+1 && navigation.selectedModel==controller.model && [navigation.lastPath isEqual:[controller.tableView indexPathForCell:cell]],@"Card dispatches one native selection for the bound post and suppresses duplicate taps");
        Check(Overlay(cell)==card && native.hidden && BHRDRepostRowHeight(controller,controller.model,500)==172,@"Navigation leaves the timeline card hidden at preview height");
        BHRDRepostControllerDidAppear(controller);
        Check(Overlay(cell)==card && native.hidden,@"Returning resets click readiness without revealing the post");
    }
    Check(controller.tableView.fixtureReloadCount==reloads,@"Opening details never reloads or expands the timeline row");
    Check([card hitTest:CGPointMake(-1,20) withEvent:nil]==nil,@"Overlay does not intercept outside its own row");
    NSUInteger before=navigation.selections; Check([card accessibilityActivate] && navigation.selections==before+1,@"Accessibility activation opens the same native details route");
    BHRDRepostControllerDidAppear(controller);
    UITableViewCell *neighbor=[UITableViewCell new]; controller.tableView.visibleCells=@[neighbor,cell];
    [(UIControl *)card sendActionsForControlEvents:UIControlEventTouchUpInside];
    Check([navigation.lastPath isEqual:[NSIndexPath indexPathWithIndex:1]],@"Insertion above the preview uses its current index path");
    BHRDRepostControllerDidAppear(controller); before=navigation.selections;
#if BHRD_AVATAR_DIAGNOSTICS
    BHRDAvatarDiagnosticFlush();
#endif
    controller.tableView.hasUncommittedUpdates=YES; [(UIControl *)card sendActionsForControlEvents:UIControlEventTouchUpInside]; controller.tableView.hasUncommittedUpdates=NO;
    Check(navigation.selections==before && native.hidden,@"Batch updates cannot navigate an unstable row");
    controller.tableView.delegate=nil;
    [(UIControl *)card sendActionsForControlEvents:UIControlEventTouchUpInside];
    Check(navigation.selections==before && BHRDRepostRowHeight(controller,controller.model,500)==172,@"Missing native selection handler keeps content hidden");
    WrongSelectionDelegate *wrongHandler=[WrongSelectionDelegate new]; controller.tableView.delegate=wrongHandler;
    [(UIControl *)card sendActionsForControlEvents:UIControlEventTouchUpInside];
    Check(wrongHandler.calls==0 && native.hidden,@"Incorrect native method signature is rejected without revealing content");
    controller.tableView.delegate=navigation;
    controller.model=Post(@"245-changed-unconfigured",@"another_author");
    [(UIControl *)card sendActionsForControlEvents:UIControlEventTouchUpInside];
    Check(navigation.selections==before,@"A changed host model cannot be opened by an old row binding");
    id staleTarget=[[[card valueForKey:@"fixtureActions"] firstObject] valueForKey:@"target"];
    BHRDConfigureRepostCell(cell,controller.model,controller);
    [(UIControl *)card sendActionsForControlEvents:UIControlEventTouchUpInside];
    Check(staleTarget && navigation.selections==before,@"A retained action from a reused overlay cannot navigate the new cell state");
    UIView *newCard=Overlay(cell); [newCard layoutSubviews]; [(UIControl *)newCard sendActionsForControlEvents:UIControlEventTouchUpInside];
    Check(navigation.selections==before+1 && navigation.selectedModel==controller.model,@"New overlay navigates its own current model after reuse");
    controller.parentViewController=[TestConversationContainerViewController new]; BHRDLayoutRepostCell(cell);
    Check(!Overlay(cell) && !native.hidden,@"Detail scope restores complete native content");
    controller.parentViewController=nil; BHRDRepostControllerDidAppear(controller);
    Check(Overlay(cell) && native.hidden && BHRDRepostRowHeight(controller,controller.model,500)==172,@"Returning from detail recreates the hidden preview instead of full content");
    [defaults setInteger:BHRDRepostModeBar forKey:BHRDRepostModeKey];
    BHRDConfigureRepostCell(cell,controller.model,controller); before=navigation.selections;
    [(UIControl *)Overlay(cell) sendActionsForControlEvents:UIControlEventTouchUpInside];
    Check(navigation.selections==before+1 && BHRDRepostRowHeight(controller,controller.model,500)==60,@"Hidden bar also opens details and remains a hidden bar");
    BHRDRestoreRepostCell(cell); method_setImplementation(shared,original); imp_removeBlock(replacement);
    if (oldHide) [defaults setObject:oldHide forKey:BHRDHideRepostsKey]; else [defaults removeObjectForKey:BHRDHideRepostsKey];
    if (oldMode) [defaults setObject:oldMode forKey:BHRDRepostModeKey]; else [defaults removeObjectForKey:BHRDRepostModeKey];
    NSLog(@"PASS: %lu production repost presentation lifecycle checks",(unsigned long)checks);
} return 0; }
