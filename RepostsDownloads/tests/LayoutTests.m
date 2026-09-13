#import <Foundation/Foundation.h>
#import "../BHRDLayoutGeometry.h"
#import "../BHRDFullscreenVisibility.h"
#import "../BHRDPreferences.h"
#import <math.h>
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) {
    checks++;
    if (!pass) { NSLog(@"FAIL: %@", name); exit(1); }
}
static BOOL Near(double a, double b) { return fabs(a - b) < 0.001; }
int main(void) {
    @autoreleasepool {
        for (NSNumber *n in @[@1, @2, @3, @4]) {
            NSUInteger count = n.unsignedIntegerValue;
            CGRect columns = CGRectMake(0, 0, 330, 8);
            CGFloat previousCenter = 0, previousGap = 0;
            for (NSUInteger index = 0; index < count; index++) {
                CGRect original = CGRectMake(3, -7, index == 0 ? 72 : 32, 44);
                CGRect frame = BHRDInlineActionFrame(columns, original, count, index);
                Check(frame.origin.x >= 0 && CGRectGetMaxX(frame) <= 330, @"Horizontal placement stays inside the column range");
                Check(Near(frame.origin.y, -7) && Near(frame.size.height, 44) && Near(frame.size.width, original.size.width), @"A short action container never shrinks or vertically clips its native buttons");
                CGFloat center = CGRectGetMidX(frame);
                if (index > 0) {
                    CGFloat gap = center - previousCenter;
                    if (index > 1) Check(Near(gap, previousGap), @"Native icon/count groups retain equal column centers when they fit");
                    previousGap = gap;
                }
                previousCenter = center;
            }
        }
        CGRect native = CGRectMake(18, 9, 92, 48);
        Check(CGRectEqualToRect(BHRDInlineActionFrame(CGRectZero, native, 0, 0), native), @"Unknown layouts preserve their native frame");
        Check(CGRectEqualToRect(BHRDInlineActionFrame(CGRectMake(0, 0, 60, 1), native, 4, 0), native), @"Insufficient space never compresses an icon or count");
        NSArray<NSNumber *> *widths = @[@92, @72, @48, @40];
        CGRect focalColumns = CGRectMake(52, 0, 320, 1);
        CGRect replyColumns = CGRectMake(0, 0, 320, 1);
        CGFloat previousRight = 0;
        for (NSUInteger i = 0; i < widths.count; i++) {
            CGRect focal = BHRDAlignedInlineActionFrame(focalColumns, CGRectMake(0, -5, widths[i].doubleValue, 44), widths, i);
            CGRect reply = BHRDAlignedInlineActionFrame(replyColumns, CGRectMake(0, 3, 30, 32), widths, i);
            Check(Near(CGRectGetMidX(focal), CGRectGetMidX(reply) + 52), @"Detail and avatar-indented reply rows align in shared list coordinates");
            Check(focal.origin.x >= previousRight, @"Adaptive columns never overlap even with large native counters");
            Check(focal.origin.y == -5 && focal.size.height == 44 && reply.origin.y == 3 && reply.size.height == 32, @"Detail and reply keep their own original vertical layout");
            previousRight = CGRectGetMaxX(focal);
        }
        CGRect portrait = BHRDFloatingDownloadFrame(CGRectMake(0, 0, 390, 844), 47, 0, 34, 0);
        Check(Near(CGRectGetMidY(portrait), 844 * 0.65), @"Portrait download button center is at 65 percent of screen height");
        Check(Near(CGRectGetMaxX(portrait), 390 - 16), @"Button stays 16 points from the right edge");
        CGRect landscape = BHRDFloatingDownloadFrame(CGRectMake(0, 0, 844, 390), 0, 47, 21, 47);
        Check(Near(CGRectGetMidY(landscape), 390 * 0.65), @"Landscape also uses screen-height 65 percent");
        Check(CGRectGetMaxX(landscape) <= 844 - 47 - 12, @"Landscape button avoids the notch safe area");
        BHRDFullscreenVisibility *visibility = [BHRDFullscreenVisibility new];
        Check(![visibility shouldDisplayEnabled:YES attached:YES], @"Unverified non-video pages do not show a download button");
        [visibility observeMedia:YES];
        Check([visibility shouldDisplayEnabled:YES attached:YES], @"A detected video enables the control");
        [visibility observeMedia:NO];
        Check([visibility shouldDisplayEnabled:YES attached:YES], @"Temporary media discovery failure does not hide a verified control");
        [visibility didDisappear]; [visibility observeMedia:YES];
        Check(![visibility shouldDisplayEnabled:YES attached:YES], @"Late layout/media callbacks cannot resurrect a departed page's button");
        [visibility didAppear];
        Check([visibility shouldDisplayEnabled:YES attached:YES], @"Returning to the full-screen page restores the control");
        Check(![visibility shouldDisplayEnabled:NO attached:YES] && ![visibility shouldDisplayEnabled:YES attached:NO], @"Disabled or detached pages cannot retain a visible control");
        NSArray *titles = BHRDSettingsTitles()[1];
        Check(![titles containsObject:@"全屏分享按钮改为下载"], @"Removed sharing replacement setting cannot be selected");
        Check([titles containsObject:@"全屏右侧独立下载按钮"], @"Settings use the new right-side position name");
        CGFloat start = 0;
        Check(BHRDAddedActionGroupStart(CGRectMake(0, 0, 390, 44), CGRectMake(12, 0, 240, 44), @[@40, @40], NO, &start), @"Two added actions fit beside the native group");
        Check(start >= 264 && start + 40 + 12 + 40 <= 390, @"Added controls retain a 12-point gap and do not cover native actions");
        Check(!BHRDAddedActionGroupStart(CGRectMake(0, 0, 300, 44), CGRectMake(12, 0, 240, 44), @[@40, @40], NO, NULL), @"Insufficient room keeps the existing layout instead of overlapping");
        Check(BHRDAddedActionGroupStart(CGRectMake(0, 0, 390, 44), CGRectMake(130, 0, 248, 44), @[@40, @40], YES, &start), @"Leading-side layouts retain visual order");
        Check(start + 92 + 12 <= 130, @"Leading group stays separate from native actions");
        CGRect glyph = BHRDMatchedInlineGlyphFrame(CGRectMake(0, 0, 40, 8), 4, CGSizeMake(24, 24));
        Check(CGRectGetMidY(glyph) == 4 && glyph.size.height == 24, @"Native glyph baseline and size are preserved even in a short container");
        Check(CGRectGetMidX(glyph) == 20, @"Added glyph stays centered in its own click target");
        Check(BHRDInlineActionOrder(@"BHRDShareImageButton") > BHRDInlineActionOrder(@"BHRDDownloadButton"), @"Album is always after download");
        Check(BHRDInlineActionOrder(@"BHRDDownloadButton") > BHRDInlineActionOrder(@"TTAStatusInlineShareButton"), @"Custom controls follow native share");
        for (NSNumber *width in @[@280, @330, @390]) {
            CGRect bounds = CGRectMake(0, 0, width.doubleValue, 44);
            NSArray *sizes = @[@60, @50, @32, @32, @40];
            CGRect original = CGRectMake(9, -7, 40, 44);
            CGRect expected = BHRDAlignedInlineActionFrame(bounds, original, sizes, 4);
            for (NSUInteger pass = 0; pass < 20; pass++) {
                original.origin.x = pass % 2 ? 3 : width.doubleValue - 10;
                CGRect actual = BHRDAlignedInlineActionFrame(bounds, original, sizes, 4);
                Check(CGRectEqualToRect(actual, expected), @"Reused host frames converge to the same album slot");
                Check(CGRectEqualToRect(BHRDAlignedInlineActionFrame(bounds, actual, sizes, 4), expected), @"Repeated layout is idempotent");
            }
        }
        NSLog(@"PASS: %lu layout and fullscreen lifecycle checks", (unsigned long)checks);
    }
    return 0;
}
