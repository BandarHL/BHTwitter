//
//  HBSection.m
//  Cephei

#import "HBSection.h"

@implementation HBSection

+ (instancetype)sectionWithTitle:(NSString *)title footer:(NSString *)footer {
    return [[self alloc] initWithTitle:title footer:footer];
}

- (instancetype)initWithTitle:(NSString *)title footer:(NSString *)footer {
    if (self = [super init]) {
        self.headerTitle = title;
        self.footerTitle = footer;
        self.cells = [NSMutableArray new];
    }
    
    return self;
}

- (void)addCell:(UITableViewCell *)cell {
    [self.cells addObject:cell];
}
- (void)removeCell:(UITableViewCell *)cell {
    [self.cells removeObject:cell];
}
- (void)addCells:(NSArray <UITableViewCell *> *)cells {
    for (UITableViewCell *cell in cells) {
        [self.cells addObject:cell];
    }
}
- (void)removeCells:(NSArray <UITableViewCell *> *)cells {
    for (UITableViewCell *cell in cells) {
        [self.cells removeObject:cell];
    }
}
@end
