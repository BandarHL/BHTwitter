#import "BHRDHomeHeaderView.h"
#import "BHRDHomeHeader.h"
#import "BHRDHomePaging.h"
#import "BHRDFullscreenDownloadControl.h"
%hook UIWindow
- (void)layoutSubviews {
    %orig;
    BHRDScheduleHomeHeaderUpdate(self);
}
%end
%hook UILabel
- (void)setText:(NSString *)text {
    %orig;
    if (BHRDHomeHeaderRole(text) != BHRDHomeTabNone) BHRDScheduleHomeHeaderUpdate(self.window);
}
%end
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    BHRDScheduleHomeHeaderUpdate(self.viewIfLoaded.window);
    BHRDFullscreenControllerDidAppear(self);
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    BHRDFullscreenControllerDidDisappear(self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    BHRDRefreshFullscreenController(self);
}
%end

// Only views associated with the verified home header/pager are affected.
%hook UIView
- (void)setFrame:(CGRect)frame { %orig(BHRDHomePagingTabFrame(self, frame)); }
%end
%hook UIScrollView
- (void)setContentSize:(CGSize)size { %orig(BHRDHomePagingContentSize(self, size)); }
- (void)setContentOffset:(CGPoint)offset { %orig(BHRDHomePagingOffset(self, offset)); }
- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated { %orig(BHRDHomePagingOffset(self, offset), animated); }
- (void)setBounces:(BOOL)bounces { %orig(BHRDHomePagingLimitScroll(self) ? NO : bounces); }
%end
