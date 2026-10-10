#import "BHRDHomeHeader.h"
#import <math.h>
BHRDHomeTabRole BHRDHomeHeaderRole(NSString *text) {
    if (![text isKindOfClass:NSString.class]) return BHRDHomeTabNone;
    NSString *normalized = [[text componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \n\t＋+•·●"]] componentsJoinedByString:@""].lowercaseString;
    if ([@[@"为你推荐", @"為你推薦", @"foryou", @"おすすめ", @"parati", @"pourvous", @"fürdich", @"추천"] containsObject:normalized]) return BHRDHomeTabForYou;
    if ([@[@"正在关注", @"正在關注", @"following", @"关注", @"關注", @"フォロー中", @"siguiendo", @"abonnements", @"folgeich", @"팔로우중"] containsObject:normalized]) return BHRDHomeTabFollowing;
    if ([@[@"添加", @"新增", @"add"] containsObject:normalized]) return BHRDHomeTabAdd;
    return BHRDHomeTabNone;
}
BOOL BHRDHomeHeaderHasPrimaryTabs(NSArray<NSDictionary *> *labels, double y) {
    BOOL forYou = NO, following = NO;
    for (NSDictionary *label in labels) {
        if (fabs([label[@"y"] doubleValue] - y) > 20) continue;
        BHRDHomeTabRole role = BHRDHomeHeaderRole(label[@"text"]);
        forYou |= role == BHRDHomeTabForYou;
        following |= role == BHRDHomeTabFollowing;
    }
    return forYou && following;
}
NSArray *BHRDHomeFirstTwoPages(NSArray *pages) {
    if (![pages isKindOfClass:NSArray.class] || pages.count <= 2) return pages;
    return [pages subarrayWithRange:NSMakeRange(0, 2)];
}
NSInteger BHRDHomeSelectedPage(NSInteger proposed) { return MAX(0, MIN(1, proposed)); }
double BHRDHomeMaximumOffset(double viewportWidth, double contentWidth) {
    return MAX(0, MIN(viewportWidth, contentWidth - viewportWidth));
}

NSArray *BHRDHomeSelectPrimaryPages(NSArray *pages, NSArray<NSNumber *> *roles) {
    if (pages.count != roles.count) return nil;
    id first=nil, second=nil;
    for (NSUInteger i=0; i<pages.count; i++) {
        if (roles[i].integerValue == BHRDHomeTabForYou) { if (first) return nil; first=pages[i]; }
        if (roles[i].integerValue == BHRDHomeTabFollowing) { if (second) return nil; second=pages[i]; }
    }
    return first && second ? @[first,second] : nil;
}
