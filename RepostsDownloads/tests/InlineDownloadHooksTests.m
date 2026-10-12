#import "InlineActionsFixture.h"
#import "../BHRDInlineLayout.h"
#import "../BHRDMediaResolver.h"
#include <stdlib.h>

static NSUInteger checks;
static BOOL floatingEnabled;
static NSMutableArray<NSString *> *events;
static id registeredModel;
static UIView *registeredView;
static void Check(BOOL pass, NSString *name) {
    checks++;
    if (!pass) { NSLog(@"FAIL: %@", name); exit(1); }
}

@implementation UIView (InlineActionsFixture)
- (BOOL)isDescendantOfView:(UIView *)view {
    for (UIView *candidate = self; candidate; candidate = candidate.superview) if (candidate == view) return YES;
    return NO;
}
- (NSInteger)effectiveUserInterfaceLayoutDirection { return 0; }
@end

#define ACTION(name) @interface name : UIView @end @implementation name @end
ACTION(T1StatusInlineReplyButton)
ACTION(T1StatusInlineBookmarkButton)
ACTION(T1StatusInlineShareButton)
ACTION(BHRDDownloadButton)
ACTION(BHRDShareImageButton)

@interface FixtureInlineActions : UIView
@property(nonatomic) BOOL fullscreen;
@property(nonatomic, strong) id viewModel;
@property(nonatomic, strong) id pendingModel;
@property(nonatomic, strong) id delegate;
@property(nonatomic, strong) NSArray *inlineActionButtons;
@end
@implementation FixtureInlineActions
- (void)layoutSubviews {
    [events addObject:@"native"];
    // Model hydration by the host must happen before the registration callback.
    self.viewModel = self.pendingModel;
}
@end
@interface TTAStatusInlineActionsView : FixtureInlineActions @end
@interface T1StatusInlineActionsView : FixtureInlineActions @end

// Boundaries outside this regression: host screen detection, preferences,
// fullscreen source storage and glyph drawing. The hook bodies and horizontal
// layout below come from production source on every run.
@interface BHRDManager : NSObject
+ (BOOL)DownloadingVideos;
@end
@implementation BHRDManager
+ (BOOL)DownloadingVideos { return YES; }
@end
NSString * const BHRDFloatingDownloadKey = @"floating";
BOOL BHRDPreference(NSString *key) { (void)key; return floatingEnabled; }
NSSet *BHRDHiddenInlineActionKeys(void) { return [NSSet set]; }
static BOOL BHViewIsInImmersiveFullScreen(UIView *view) { return ((FixtureInlineActions *)view).fullscreen; }
static id __attribute__((unused)) BHObjectValueForSelector(id value, SEL selector) { return BHRDMediaObject(value, NSStringFromSelector(selector)); }
static void BHRDRegisterFullscreenInlineModel(UIView *view, id model) {
    registeredView = view;
    registeredModel = model;
    [events addObject:@"register"];
}
static void BHRDRegisterFloatingSource(UIView *view) { (void)view; [events addObject:@"floating"]; }
static void FixtureLayout(UIView *view) {
    [events addObject:@"layout"];
    BHRDLayoutInlineActions(view);
}
static void BHRDMatchAddedButtonsToNative(UIView *view) { (void)view; [events addObject:@"style"]; }

// Only %orig becomes the fixture's native layout; the production hook/helper
// bodies are extracted unchanged, with this spy forwarding to the real layout.
#define BHRDLayoutInlineActions FixtureLayout
#include "InlineDownloadHooks.generated.h"
#undef BHRDLayoutInlineActions

int main(void) { @autoreleasepool {
    events = [NSMutableArray array];
    for (Class hostClass in @[TTAStatusInlineActionsView.class, T1StatusInlineActionsView.class]) {
        for (NSNumber *fullscreen in @[@YES, @NO]) {
            for (NSNumber *floating in @[@YES, @NO]) {
                for (NSNumber *wrapped in @[@NO, @YES]) {
                    for (NSNumber *mutableButtons in @[@YES, @NO]) {
                        for (NSNumber *width in @[@280, @390]) {
                            FixtureInlineActions *host = [[hostClass alloc] initWithFrame:CGRectMake(0, 0, width.doubleValue, 8)];
                            host.fullscreen = fullscreen.boolValue;
                            floatingEnabled = floating.boolValue;
                            NSArray *classes = @[T1StatusInlineReplyButton.class, T1StatusInlineBookmarkButton.class,
                                T1StatusInlineShareButton.class, BHRDDownloadButton.class, BHRDShareImageButton.class];
                            NSArray *widths = @[@60, @50, @32, @40, @40];
                            NSMutableArray<UIView *> *buttons = [NSMutableArray array], *items = [NSMutableArray array];
                            for (NSUInteger index = 0; index < classes.count; index++) {
                                UIView *button = [[classes[index] alloc] initWithFrame:CGRectMake(0, -7, [widths[index] doubleValue], 44)];
                                UIView *item = button;
                                if (wrapped.boolValue) {
                                    item = [[UIView alloc] initWithFrame:button.frame];
                                    button.frame = CGRectMake(0, 0, button.frame.size.width, 44);
                                    [item addSubview:button];
                                }
                                [host addSubview:item]; [buttons addObject:button]; [items addObject:item];
                            }
                            host.inlineActionButtons = mutableButtons.boolValue ? buttons : [buttons copy];
                            id originalArray = host.inlineActionButtons;
                            NSArray *originalButtons = [buttons copy];
                            UIView *download = buttons[3];
                            for (NSUInteger pass = 0; pass < 3; pass++) {
                                [events removeAllObjects]; registeredModel = nil; registeredView = nil;
                                id current = @{@"statusID": [NSString stringWithFormat:@"current-%lu", (unsigned long)pass]};
                                host.pendingModel = pass == 1 ? nil : current;
                                host.delegate = pass == 1 ? @{@"viewModel": current} : nil;
                                // Simulate X resetting native positions each layout/reuse.
                                for (UIView *item in items) item.frame = CGRectMake(width.doubleValue - 4, -7, item.frame.size.width, 44);
                                [host layoutSubviews];
                                NSString *context = [NSString stringWithFormat:@"%@ fullscreen=%@ floating=%@ wrapped=%@ mutable=%@ width=%@ pass=%lu",
                                    NSStringFromClass(hostClass), fullscreen, floating, wrapped, mutableButtons, width, (unsigned long)pass];
                                Check(download.superview != nil && [download isDescendantOfView:host],
                                    [@"Inline download survives alongside the floating control: " stringByAppendingString:context]);
                                Check(host.inlineActionButtons == originalArray && [host.inlineActionButtons isEqualToArray:originalButtons] && host.inlineActionButtons.count == 5,
                                    @"Layout preserves all five host button objects and the original array");
                                Check(registeredView == host && registeredModel == current, @"The current direct/delegate model is registered after host hydration");
                                NSArray *expected = host.fullscreen ? @[@"native", @"register", @"floating", @"layout", @"style"] : @[@"native", @"register", @"layout", @"style"];
                                Check([events isEqualToArray:expected], @"Both host variants always lay out after registration and before matching native glyphs");
                                CGFloat right = 0;
                                for (UIView *item in items) {
                                    Check(item.frame.origin.x >= right && CGRectGetMaxX(item.frame) <= width.doubleValue,
                                        @"Reply, bookmark, share, download and album targets fit in order without overlap");
                                    Check(item.frame.origin.y == -7 && item.frame.size.height == 44,
                                        @"The short detail action container preserves each native target's height and baseline");
                                    right = CGRectGetMaxX(item.frame);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    NSLog(@"PASS: %lu production inline-download hook and five-action layout checks", (unsigned long)checks);
} return 0; }
