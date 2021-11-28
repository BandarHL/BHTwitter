//
//  HBViewControllerCell.m
//  Cephei

#import "HBViewControllerCell.h"

@interface HBViewControllerCell ()
@property (nonatomic, strong) UIViewController *destanationVC;
@end

@implementation HBViewControllerCell
- (instancetype)initCellWithTitle:(NSString *)title detail:(NSString *)detail action:(UIViewController* (^_Nonnull)(void))action {
    HBViewControllerCell *cell = [super init];
    cell.destanationVC = action();
    [self setupUI:title detail:detail];
    return cell;
}

- (void)setupUI:(NSString *)title detail:(NSString *)detail {
    [self.textLabel setText:title];
    [self.textLabel setTextColor:[UIColor colorWithRed:0.35 green:0.78 blue:0.98 alpha:1]];
    [self.textLabel setNumberOfLines:0];
    
    [self.detailTextLabel setText:detail];
    [self.detailTextLabel setNumberOfLines:0];
    [self.detailTextLabel setTextColor:[UIColor secondaryLabelColor]];
    [self.detailTextLabel setFont:[UIFont systemFontOfSize:12]];
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
    [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
//    [viewController presentViewController:self.destanationVC animated:true completion:nil];
    [viewController.navigationController pushViewController:self.destanationVC animated:true];
}

- (UIContextMenuConfiguration *)contextMenuConfigurationForRowAtCell:(HBCell *)cell FromTable:(HBPreferences *)viewController {
    UIContextMenuConfiguration *configuration = [UIContextMenuConfiguration configurationWithIdentifier:[RuntimeExplore getAddressFromDescription:self.destanationVC.description] previewProvider:^UIViewController * _Nullable{
        return self.destanationVC;
    } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [UIMenu menuWithTitle:@"" children:@[]];
    }];
    
    return configuration;
}
@end
