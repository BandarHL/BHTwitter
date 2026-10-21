#import <UIKit/UIKit.h>
#import "../BHRDHomeHeaderView.h"
#import "../BHRDHomePaging.h"
#import "../BHRDHomeHeader.h"
#import "../BHRDPreferences.h"

@interface FixtureHomeTimelineContainerViewController : UIViewController @end
@implementation FixtureHomeTimelineContainerViewController @end
@interface FixtureProfileViewController : UIViewController @end
@implementation FixtureProfileViewController @end
@interface FixturePagingViewController : UIViewController
@property(nonatomic, copy) NSArray *pages;
@property(nonatomic) NSInteger selectedIndex;
@end
@implementation FixturePagingViewController @end
@interface FixtureHomePage : NSObject
@property(nonatomic, copy) NSString *identifier;
@end
@implementation FixtureHomePage @end
@interface HomeGraph : NSObject
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UIViewController *home;
@property(nonatomic, strong) UIView *header;
@property(nonatomic, strong) UIView *strip;
@property(nonatomic, strong) UILabel *first;
@property(nonatomic, strong) UILabel *second;
@property(nonatomic, strong) UIButton *add;
@property(nonatomic, strong) UIScrollView *scroll;
@end
@implementation HomeGraph @end
static NSUInteger checks;
static void Check(BOOL ok, NSString *message) { checks++; if (!ok) { NSLog(@"FAIL: %@",message); exit(1); } }
static void Attach(UIView *parent, UIView *child) { [parent addSubview:child]; child.window=parent.window; }
static UILabel *Label(UIView *parent, NSString *text, CGRect rect) {
    UILabel *label=[[UILabel alloc] initWithFrame:rect]; label.text=text; Attach(parent,label); return label;
}
static NSArray *Labels(HomeGraph *graph, BOOL includeAdd) {
    NSMutableArray *labels=[NSMutableArray array];
    for (UIView *view in includeAdd ? @[graph.first,graph.second,graph.add] : @[graph.first,graph.second]) {
        NSString *text=BHRDHomeHeaderViewText(view);
        if (text) [labels addObject:@{@"text":text,@"y":@(CGRectGetMidY([view convertRect:view.bounds toView:graph.window])),@"view":view}];
    }
    return labels;
}
static HomeGraph *Graph(BOOL homeController) {
    HomeGraph *graph=[HomeGraph new];
    graph.window=[[UIWindow alloc] initWithFrame:CGRectMake(0,0,430,932)]; graph.window.window=graph.window;
    graph.window.safeAreaInsets=(UIEdgeInsets){59,0,34,0};
    graph.home=homeController ? [FixtureHomeTimelineContainerViewController new] : [FixtureProfileViewController new];
    graph.home.view=[[UIView alloc] initWithFrame:graph.window.bounds]; Attach(graph.window,graph.home.view);
    [graph.home.view setFixtureNextResponder:graph.home];
    graph.header=[[UIView alloc] initWithFrame:CGRectMake(0,103,430,44)]; Attach(graph.home.view,graph.header);
    // Match the observed host: two small tab cells and a sibling image button.
    graph.strip=[[UIView alloc] initWithFrame:CGRectMake(44,0,342,44)]; Attach(graph.header,graph.strip);
    UICollectionViewCell *first=[[UICollectionViewCell alloc] initWithFrame:CGRectMake(0,0,171,44)]; Attach(graph.strip,first);
    UICollectionViewCell *second=[[UICollectionViewCell alloc] initWithFrame:CGRectMake(171,0,171,44)]; Attach(graph.strip,second);
    graph.first=Label(first,@"为你推荐",CGRectMake(44,12,65,20));
    graph.second=Label(second,@"正在关注",CGRectMake(53,12,65,20));
    graph.add=[[UIButton alloc] initWithFrame:CGRectMake(386,0,44,44)]; graph.add.accessibilityLabel=@"添加"; Attach(graph.header,graph.add);
    graph.scroll=[[UIScrollView alloc] initWithFrame:CGRectMake(0,147,430,700)]; Attach(graph.home.view,graph.scroll);
    graph.scroll.contentSize=CGSizeMake(1290,700); graph.scroll.contentOffset=CGPointMake(860,0); graph.scroll.bounces=YES;
    return graph;
}
static void Scan(HomeGraph *graph) {
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.27]];
    BHRDScheduleHomeHeaderUpdate(graph.window);
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}
static FixtureHomePage *Page(NSString *identifier) { FixtureHomePage *page=[FixtureHomePage new]; page.identifier=identifier; return page; }
int main(void) { @autoreleasepool {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults; id saved=[defaults objectForKey:BHRDHideHomeAddKey];
    [defaults setBool:YES forKey:BHRDHideHomeAddKey];
    HomeGraph *unknown=Graph(YES); CGRect firstFrame=unknown.first.superview.frame,secondFrame=unknown.second.superview.frame;
    UIButton *plus=[[UIButton alloc] initWithFrame:CGRectMake(0,0,44,44)]; plus.accessibilityLabel=@"+"; Attach(unknown.header,plus);
    UIButton *addAccount=[[UIButton alloc] initWithFrame:CGRectMake(0,0,44,44)]; addAccount.accessibilityLabel=@"添加账号"; Attach(unknown.header,addAccount);
    UIButton *otherRow=[[UIButton alloc] initWithFrame:CGRectMake(386,60,44,44)]; otherRow.accessibilityLabel=@"添加"; Attach(unknown.header,otherRow);
    Scan(unknown);
    Check(unknown.add.hidden && !unknown.add.userInteractionEnabled,@"Image-only accessible Add is hidden and cannot receive a tap with an unknown Swift pager");
    Check(!unknown.first.superview.hidden && !unknown.second.superview.hidden,@"Both original timeline tabs remain visible");
    Check(CGRectEqualToRect(firstFrame,unknown.first.superview.frame) && CGRectEqualToRect(secondFrame,unknown.second.superview.frame),@"Unknown pager leaves original tab geometry intact");
    Check(unknown.scroll.contentSize.width==1290 && unknown.scroll.contentOffset.x==860 && unknown.scroll.bounces,@"Unknown pager never clamps unverified native pages or selection");
    Check(!plus.hidden && plus.userInteractionEnabled && !addAccount.hidden && !otherRow.hidden,@"Standalone plus, add-account and a different row remain unaffected");
    Check([unknown.header hitTest:CGPointMake(408,22) withEvent:nil]!=unknown.add,@"Hidden Add is absent from actual view hit testing");
    Scan(unknown); Check(unknown.add.hidden && !unknown.add.userInteractionEnabled,@"A second scan retains the semantic action excluded by the visible-view scan");
    unknown.add.accessibilityLabel=@"添加账号"; Scan(unknown);
    Check(!unknown.add.hidden && unknown.add.userInteractionEnabled,@"Reusing the same control for another action restores its original state");
    unknown.add.accessibilityLabel=@"添加"; Scan(unknown);
    [defaults setBool:NO forKey:BHRDHideHomeAddKey]; Scan(unknown);
    Check(!unknown.add.hidden && unknown.add.userInteractionEnabled,@"Disabling the option restores image button visibility and touch handling");
    [defaults setBool:YES forKey:BHRDHideHomeAddKey];
    HomeGraph *profile=Graph(NO); Scan(profile);
    Check(!profile.add.hidden && profile.add.userInteractionEnabled,@"Matching labels and Add on a profile cannot substitute for a home controller");
    HomeGraph *large=Graph(YES); large.header.bounds=CGRectMake(0,0,430,200); Scan(large);
    Check(!large.add.hidden,@"A large common root is insufficient structural evidence");
    HomeGraph *missing=Graph(YES); missing.second.text=@"列表"; Scan(missing);
    Check(!missing.add.hidden,@"One primary tab cannot authorize hiding Add");
    HomeGraph *title=Graph(YES); title.add.accessibilityLabel=nil; [title.add setTitle:@"Add +" forState:UIControlStateNormal];
    title.first.text=@"For you"; title.second.text=@"Following"; Scan(title);
    Check(title.add.hidden && !title.add.userInteractionEnabled,@"Native UIButton title fallback and English primary tabs identify the same action");
    HomeGraph *collection=Graph(YES);
    UICollectionViewCell *addCell=[[UICollectionViewCell alloc] initWithFrame:collection.add.frame]; Attach(collection.header,addCell);
    [collection.add removeFromSuperview]; collection.add.frame=CGRectMake(0,0,44,44); collection.add.accessibilityLabel=@"+"; Attach(addCell,collection.add);
    Scan(collection);
    Check(addCell.hidden && !addCell.userInteractionEnabled,@"A trailing standalone plus inside a verified home tab collection cell hides its entire selectable hit area");
    Check([collection.header hitTest:CGPointMake(408,22) withEvent:nil]!=addCell,@"The enclosing collection cell cannot still open tab management after hiding only an icon");
    [defaults setBool:NO forKey:BHRDHideHomeAddKey]; Scan(collection);
    Check(!addCell.hidden && addCell.userInteractionEnabled,@"Disabling restores the native selectable Add cell");
    [defaults setBool:YES forKey:BHRDHideHomeAddKey];
    HomeGraph *accessible=Graph(YES);
    UIView *firstParent=accessible.first.superview,*secondParent=accessible.second.superview;
    CGRect firstLabelFrame=accessible.first.frame, secondLabelFrame=accessible.second.frame;
    [accessible.first removeFromSuperview]; [accessible.second removeFromSuperview];
    UIButton *firstButton=[[UIButton alloc] initWithFrame:firstLabelFrame],*secondButton=[[UIButton alloc] initWithFrame:secondLabelFrame];
    firstButton.accessibilityLabel=@"为你推荐"; secondButton.accessibilityLabel=@"正在关注";
    Attach(firstParent,firstButton); Attach(secondParent,secondButton); Scan(accessible);
    Check(accessible.add.hidden,@"Native accessible Swift tab controls need not be UILabel subclasses");
    HomeGraph *disabled=Graph(YES); disabled.add.userInteractionEnabled=NO; Scan(disabled);
    [defaults setBool:NO forKey:BHRDHideHomeAddKey]; Scan(disabled);
    Check(!disabled.add.hidden && !disabled.add.userInteractionEnabled,@"Restore preserves a host control that was already disabled");
    [defaults setBool:YES forKey:BHRDHideHomeAddKey];
    HomeGraph *legacy=Graph(YES); FixturePagingViewController *pager=[FixturePagingViewController new];
    FixtureHomePage *forYou=Page(@"for_you"),*following=Page(@"following"),*add=Page(@"add");
    NSArray *originalPages=@[forYou,following,add]; pager.pages=originalPages; pager.selectedIndex=2; legacy.home.childViewControllers=@[pager];
    BHRDUpdateHomePaging(legacy.window,Labels(legacy,YES));
    Check([pager.pages isEqual:@[forYou,following]] && pager.selectedIndex==1,@"Recognized legacy pager still retains only the two semantically identified home pages");
    Check(legacy.scroll.contentSize.width==860 && legacy.scroll.contentOffset.x==430 && !legacy.scroll.bounces,@"Recognized legacy paging keeps the existing scroll restriction");
    Check(BHRDHomePagingLimitScroll(legacy.scroll),@"Only a verified home scroll receives the page limiter");
    pager.pages=originalPages; Check(pager.pages.count==2,@"Subsequent native array rebuilds keep the legacy two-page limit");
    [defaults setBool:NO forKey:BHRDHideHomeAddKey]; BHRDUpdateHomePaging(legacy.window,nil);
    Check([pager.pages isEqual:originalPages] && legacy.scroll.contentSize.width==1290 && legacy.scroll.bounces,@"Disabling restores the legacy native page array and scroll width/bounces");
    Check(!legacy.add.hidden && legacy.add.userInteractionEnabled && !BHRDHomePagingLimitScroll(legacy.scroll),@"Legacy restoration also restores independent Add state and removes its scroll binding");
    [defaults setBool:YES forKey:BHRDHideHomeAddKey];
    HomeGraph *unknownPage=Graph(YES); FixturePagingViewController *unknownPager=[FixturePagingViewController new];
    NSArray *mixedPages=@[forYou,following,Page(@"unknown_custom_feed")]; unknownPager.pages=mixedPages; unknownPager.selectedIndex=2; unknownPage.home.childViewControllers=@[unknownPager];
    BHRDUpdateHomePaging(unknownPage.window,Labels(unknownPage,YES));
    Check(unknownPager.pages==mixedPages && unknownPager.selectedIndex==2,@"Even identified primary pages never authorize removal of an unidentified third page");
    Check(unknownPage.scroll.contentSize.width==1290 && unknownPage.add.hidden,@"Unidentified third page keeps native paging while the confirmed Add action is independently hidden");
    [defaults setBool:YES forKey:BHRDHideHomeAddKey]; BHRDUpdateHomePaging(legacy.window,Labels(legacy,YES));
    pager.pages=mixedPages; BHRDUpdateHomePaging(legacy.window,Labels(legacy,NO));
    Check([pager.pages isEqual:mixedPages] && legacy.scroll.contentSize.width==1290 && !BHRDHomePagingLimitScroll(legacy.scroll),@"A legacy pager rebuilt with an unknown page restores the original native pager rather than retaining old constraints");
    if (saved) [defaults setObject:saved forKey:BHRDHideHomeAddKey]; else [defaults removeObjectForKey:BHRDHideHomeAddKey];
    NSLog(@"PASS: %lu production home-header view/paging checks",(unsigned long)checks);
} return 0; }
