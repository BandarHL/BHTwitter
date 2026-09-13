#import <Foundation/Foundation.h>
#import "../BHRDHomeHeader.h"
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) {
    checks++;
    if (!pass) { NSLog(@"FAIL: %@", name); exit(1); }
}
int main(void) {
    @autoreleasepool {
        for (NSString *text in @[@"添加", @"添加 +", @"• 添加 ＋", @"Add +", @"新增"]) Check(BHRDHomeHeaderRole(text) == BHRDHomeTabAdd, @"Recognize the exact Add tab with optional plus/dot");
        Check(BHRDHomeHeaderRole(@"+") == BHRDHomeTabNone, @"Do not hide unrelated standalone plus controls");
        Check(BHRDHomeHeaderRole(@"添加账号") == BHRDHomeTabNone, @"Do not hide add-account controls");
        Check(BHRDHomeHeaderRole(@"请添加这个列表") == BHRDHomeTabNone, @"Do not match body text");
        Check(BHRDHomeHeaderRole(nil) == BHRDHomeTabNone, @"Handle absent labels");
        NSArray *header = @[@{@"text": @"为你推荐", @"y": @160}, @{@"text": @"正在关注", @"y": @164}];
        Check(BHRDHomeHeaderHasPrimaryTabs(header, 162), @"Require both primary timeline labels beside Add");
        Check(!BHRDHomeHeaderHasPrimaryTabs(header, 240), @"Do not match another row's Add control");
        Check(!BHRDHomeHeaderHasPrimaryTabs(@[header[0]], 162), @"A single primary label is insufficient");
        Check(!BHRDHomeHeaderHasPrimaryTabs(@[@{@"text": @"添加", @"y": @160}], 160), @"Do not hide Add in unrelated screens");
        Check(BHRDHomeHeaderHasPrimaryTabs(@[@{@"text": @"For you", @"y": @160}, @{@"text": @"Following", @"y": @160}], 160), @"Support English host UI with Chinese tweak settings");
        NSObject *forYou = [NSObject new], *following = [NSObject new], *addPage = [NSObject new];
        NSArray *pages = @[forYou, following, addPage];
        Check([BHRDHomeFirstTwoPages(pages) isEqual:@[forYou, following]], @"Remove the third page from the page array, not just its label");
        Check(pages.count == 3 && pages[2] == addPage, @"Keep the original array intact for restoration");
        NSArray *two = @[forYou, following];
        Check(BHRDHomeFirstTwoPages(two) == two, @"Do not rebuild an already two-page home");
        Check([BHRDHomeFirstTwoPages(@[forYou]) count] == 1, @"Do not invent unavailable pages during initialization");
        Check(BHRDHomeFirstTwoPages(nil) == nil, @"Absent page data remains absent");
        Check(BHRDHomeSelectedPage(2) == 1 && BHRDHomeSelectedPage(8) == 1, @"An old third-page selection returns to Following");
        Check(BHRDHomeSelectedPage(0) == 0 && BHRDHomeSelectedPage(1) == 1, @"Both retained tabs remain selectable");
        Check(BHRDHomeSelectedPage(-1) == 0, @"Invalid negative selection cannot index the page array");
        Check(BHRDHomeMaximumOffset(390, 1170) == 390, @"A three-page scroll view cannot stop at the removed third page");
        Check(BHRDHomeMaximumOffset(390, 780) == 390, @"Two-page swipe range includes Following");
        Check(BHRDHomeMaximumOffset(390, 200) == 0, @"Short initial content cannot create a negative scroll range");
        Check(BHRDHomeMaximumOffset(844, 2532) == 844, @"Paging bound adapts to landscape width");
        NSLog(@"PASS: %lu home-header checks", (unsigned long)checks);
    }
    return 0;
}
