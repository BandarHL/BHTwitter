//
//  HPCell.m
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBCell.h"

@implementation HBCell

+ (instancetype)initCell {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    return self;
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    
}

- (UIContextMenuConfiguration *)contextMenuConfigurationForRowAtCell:(HBCell *)cell FromTable:(HBPreferences *)viewController {
    
}
@end
