//
//  BHCustomTabBarUtility.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import "BHCustomTabBarUtility.h"

@implementation BHCustomTabBarUtility
+ (NSArray<NSString *> *)getAllowedTabBars {
    NSData *savedItems = [[NSUserDefaults standardUserDefaults] objectForKey:@"allowed"];
    if (savedItems) {
        NSArray<BHCustomTabBarItem *> *savedList = [NSKeyedUnarchiver unarchiveObjectWithData:savedItems];
        NSMutableArray<NSString *> *tmpArr = [NSMutableArray array];
        for (BHCustomTabBarItem *item in savedList) {
            [tmpArr addObject:item.pageID];
        }
        return tmpArr;
    }
    return nil;
}

+ (NSArray<NSString *> *)getHiddenTabBars {
    NSData *savedItems = [[NSUserDefaults standardUserDefaults] objectForKey:@"hidden"];
    if (savedItems) {
        NSArray<BHCustomTabBarItem *> *savedList = [NSKeyedUnarchiver unarchiveObjectWithData:savedItems];
        NSMutableArray<NSString *> *tmpArr = [NSMutableArray array];
        for (BHCustomTabBarItem *item in savedList) {
            [tmpArr addObject:item.pageID];
        }
        return tmpArr;
    }
    return nil;
}
@end
