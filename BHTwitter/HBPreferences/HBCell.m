//
//  HPCell.m
//  Cephei

#import "HBCell.h"

@implementation HBCell

+ (instancetype)initCell {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    return self;
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    
}

- (UIContextMenuConfiguration *)contextMenuConfigurationForRowAtCell:(HBCell *)cell FromTable:(HBPreferences *)viewController {
    
}
@end
