#import "BHRDSafety.h"
// Opt-in diagnostic build only; never included in the release package.
#import "BHRDRepostPresentation.h"
#import "BHRDConversationScope.h"
#import "BHRDContentFilter.h"
#import "BHRDAdFilter.h"
#import "BHRDManager.h"
#import "BHRDShareImageButton.h"
#import "BHRDSharePost.h"
#import "BHRDShareVisibleData.h"
#import "BHRDMediaResolver.h"
#import <objc/runtime.h>

// Record only the author-related shape of native X objects. Do not dump an
// object's description: it can include the entire post, account or request.
static void DumpAuthorModel(id source, NSString *path, NSUInteger depth, NSMutableSet *seen) {
    if (!source || source == NSNull.null || depth > 5 || seen.count >= 32) return;
    NSValue *address = [NSValue valueWithNonretainedObject:source];
    if ([seen containsObject:address]) return;
    [seen addObject:address];
    NSLog(@"[XSuixinDiag] MODEL path=%@ class=%@ statusID=%@", path, NSStringFromClass([source class]), BHRDMediaStatusIdentity(source));
    NSMutableArray *getters = [NSMutableArray array], *ivars = [NSMutableArray array];
    for (Class cls = [source class]; cls && cls != NSObject.class; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            NSString *lower = name.lowercaseString;
            if (![name containsString:@":"] && ([lower containsString:@"author"] || [lower containsString:@"user"] || [lower containsString:@"name"])) [getters addObject:name];
        }
        free(methods);
        Ivar *fields = class_copyIvarList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *name = @(ivar_getName(fields[i]));
            NSString *lower = name.lowercaseString;
            if ([lower containsString:@"author"] || [lower containsString:@"user"] || [lower containsString:@"name"]) [ivars addObject:name];
        }
        free(fields);
    }
    NSLog(@"[XSuixinDiag] MODEL_SHAPE path=%@ getters=%@ ivars=%@", path, [getters componentsJoinedByString:@","], [ivars componentsJoinedByString:@","]);
    for (NSString *key in @[@"name", @"displayName", @"displayFullName", @"fullName", @"screenName", @"screen_name", @"username", @"displayUsername", @"fromUserName", @"authorName", @"authorDisplayName", @"authorScreenName", @"userFullName", @"userScreenName"]) {
        id value = [source isKindOfClass:NSDictionary.class] ? source[key] : BHRDMediaObject(source, key);
        if (!value) continue;
        NSString *text = BHRDShareText(value);
        if (text.length > 100) text = [text substringToIndex:100];
        NSLog(@"[XSuixinDiag] FIELD path=%@.%@ class=%@ value=[%@]", path, key, NSStringFromClass([value class]), text ?: @"");
    }
    for (NSString *key in @[@"tweet", @"viewModel", @"status", @"coreStatus", @"statusModel", @"representedStatus", @"representedFromUser", @"fromUser", @"user", @"authorUser", @"statusUser", @"author", @"userViewModel", @"authorViewModel", @"userInfo", @"core", @"legacy"]) {
        id child = [source isKindOfClass:NSDictionary.class] ? source[key] : BHRDMediaObject(source, key);
        if (!child || [child isKindOfClass:NSString.class] || [child isKindOfClass:NSNumber.class]) continue;
        DumpAuthorModel(child, [path stringByAppendingFormat:@".%@", key], depth + 1, seen);
    }
}

static void DumpView(UIView *view, NSUInteger depth, NSUInteger *budget) {
    if (!view || !*budget || depth > 14) return;
    (*budget)--;
    NSLog(@"[XSuixinDiag] VIEW depth=%lu class=%@ ptr=%p hidden=%d alpha=%.2f frame=%@ control=%d", (unsigned long)depth, NSStringFromClass(view.class), view, view.hidden, view.alpha, NSStringFromCGRect(view.frame), [view isKindOfClass:UIControl.class]);
    for (UIView *child in view.subviews) DumpView(child, depth + 1, budget);
}
// Dump only the top of a share card (author header area). Body text lives much
// lower, so this intentionally never records post content.
static void DumpShareCard(UIView *view, UIView *root, NSUInteger depth, NSUInteger *budget) {
    if (!view || !*budget || depth > 18) return;
    (*budget)--;
    CGRect rect = [view convertRect:view.bounds toView:root];
    NSString *text = nil;
    NSString *className = NSStringFromClass(view.class).lowercaseString;
    BOOL content = [className containsString:@"body"] || [className containsString:@"textview"] || [className containsString:@"richtext"] || rect.size.height > 60;
    if (rect.origin.y <= 150 && !content) {
        text = BHRDShareText(view);
        if (!text.length) text = view.accessibilityLabel;
        if (text.length > 60) text = [[text substringToIndex:60] stringByAppendingString:@"…"];
    }
    NSLog(@"[XSuixinDiag] CARD depth=%lu class=%@ ptr=%p hidden=%d alpha=%.2f rect=%@ text=[%@]", (unsigned long)depth, NSStringFromClass(view.class), view, view.hidden, view.alpha, NSStringFromCGRect(rect), text ?: @"");
    for (UIView *child in view.subviews) DumpShareCard(child, root, depth + 1, budget);
}
static void DumpScreen(UIViewController *controller) {
    if (!controller.viewIfLoaded.window) return;
    NSString *name = NSStringFromClass(controller.class);
    if ([name isEqual:@"BHRDShareImageController"]) {
        id post = [controller valueForKey:@"post"];
        NSLog(@"[XSuixinDiag] SHARE authorPresent=%d handlePresent=%d authorEnabled=%d replyID=%@ contextPresent=%d", [[post valueForKey:@"author"] length] > 0, [[post valueForKey:@"handle"] length] > 0, [[[controller valueForKey:@"options"] objectForKey:@"author"] boolValue], [post valueForKey:@"replyToIdentifier"], [post valueForKey:@"replyContextPost"] != nil);
        return;
    }
    if (![name containsString:@"Conversation"] && ![name containsString:@"TweetDetail"]) return;
    NSLog(@"[XSuixinDiag] SCREEN %@ scope=%d", name, BHRDIsConversationContext(controller));
    NSUInteger budget = 220;
    DumpView(controller.viewIfLoaded, 0, &budget);
}
%group XSuixinDiagnostics
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    __weak UIViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ DumpScreen(weakSelf); });
}
%end
%hook TFNItemsDataViewController
- (id)tableViewCellForItem:(id)item atIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = %orig;
    id model = [self itemAtIndexPath:indexPath] ?: item;
    NSLog(@"[XSuixinDiag] CELL controller=%@ parent=%@ location=%@ row=%@ model=%@ cell=%@ ptr=%p scope=%d recommendation=%d promoted=%d repost=%d", NSStringFromClass([self class]), NSStringFromClass([[self parentViewController] class]), [self valueForKey:@"adDisplayLocation"], indexPath, NSStringFromClass([model class]), NSStringFromClass(cell.class), cell, BHRDIsConversationContext(self), BHRDShouldHideRecommendation(model,self), BHRDIsPromotedModel(model), BHRDIsRepostModel(model));
    return cell;
}
%end
%end
%group XSuixinShareDiagnostics
%hook BHRDShareImageButton
- (void)openShareImage:(UIButton *)sender {
    id model = BHRDMediaObject(self.delegate, @"viewModel") ?: self.viewModel;
    UIView *card = nil;
    for (UIView *view = self.superview; view; view = view.superview) {
        if (!model) model = BHRDMediaObject(view, @"viewModel");
        if ([view isKindOfClass:UITableViewCell.class]) { card = view; break; }
        if ([NSStringFromClass(view.class) containsString:@"StatusView"]) card = view;
    }
    NSLog(@"[XSuixinDiag] SHAREBTN model=%@ card=%@ delegate=%@ inWindow=%d", NSStringFromClass([model class]), NSStringFromClass(card.class), NSStringFromClass([self.delegate class]), self.window != nil);
    DumpAuthorModel(model, @"button.model", 0, [NSMutableSet set]);
    DumpAuthorModel(card, @"button.card", 0, [NSMutableSet set]);
    NSUInteger budget = 500;
    DumpShareCard(card, card, 0, &budget);
    BHRDSharePost *post = BHRDSharePostFromSource(model);
    NSLog(@"[XSuixinDiag] SHAREPOST before id=%@ author=[%@] handle=[%@] avatar=%d images=%lu", post.identifier, post.author, post.handle, (post.avatar != nil || post.avatarData != nil), (unsigned long)post.images.count);
    BHRDEnrichSharePostFromView(post, card);
    NSLog(@"[XSuixinDiag] SHAREPOST after id=%@ author=[%@] handle=[%@] avatar=%d quote=[%@]", post.identifier, post.author, post.handle, (post.avatar != nil || post.avatarData != nil), post.quotedPost.handle);
    %orig;
}
%end
%end
%ctor { if (!BHRDFeatureHooksEnabledAtLaunch()) return; %init(XSuixinDiagnostics); %init(XSuixinShareDiagnostics); NSLog(@"[XSuixinDiag] loaded diagnostic build"); }
