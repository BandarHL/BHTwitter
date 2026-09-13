#import <UIKit/UIKit.h>
void BHRDUpdateHomePaging(UIWindow *window, NSArray<NSDictionary *> *labels);
BOOL BHRDHomePagingLimitScroll(UIScrollView *scroll);
CGSize BHRDHomePagingContentSize(UIScrollView *scroll, CGSize proposed);
CGPoint BHRDHomePagingOffset(UIScrollView *scroll, CGPoint proposed);
CGRect BHRDHomePagingTabFrame(UIView *view, CGRect proposed);
