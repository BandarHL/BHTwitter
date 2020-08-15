//
//  HBSection.m
//  Cephei
//
//  Created by BandarHelal on 04/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

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

@end
