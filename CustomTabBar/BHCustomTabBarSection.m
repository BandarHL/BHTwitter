//
//  BHCustomTabBarSection.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import "BHCustomTabBarSection.h"

@implementation BHCustomTabBarSection
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<BHCustomTabBarItem *> *)items {
    self = [super init];
    if (self) {
        _title = title;
        _items = [items mutableCopy];
    }
    return self;
}

- (void)saveItemsForKey:(NSString *)key {
    NSData *encodedItems = [NSKeyedArchiver archivedDataWithRootObject:self.items];
    [[NSUserDefaults standardUserDefaults] setObject:encodedItems forKey:key];
}
@end
