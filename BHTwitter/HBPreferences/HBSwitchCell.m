//
//  HBSwitchCell.m
//  Cephei

#import "HBSwitchCell.h"

@implementation HBSwitchCell

- (instancetype)initSwitchCellWithImage:(UIImage *)img Title:(NSString *)title DetailTitle:(NSString *)Dtitle switchKey:(NSString *)key withBlock:(ALActionBlock)actionBlock {
    HBSwitchCell *cell = [self init];
    
    [self setupUI:Dtitle actionBlock:actionBlock cell:cell img:img switchMod:key title:title];
    
    
    return cell;
}

- (void)setupUI:(NSString *)Dtitle actionBlock:(ALActionBlock)actionBlock cell:(HBSwitchCell *)cell img:(UIImage *)img switchMod:(NSString *)key title:(NSString *)title {
    
    [self.textLabel setText:title];
    [self.textLabel setTextColor:UIColor.labelColor];
    [self.textLabel setNumberOfLines:0];
    
    [self.detailTextLabel setText:Dtitle];
    [self.detailTextLabel setNumberOfLines:0];
    [self.detailTextLabel setTextColor:[UIColor secondaryLabelColor]];
    [self.detailTextLabel setFont:[UIFont systemFontOfSize:12]];
    
    self.imageView.image = img;
    
    self.Switch = UISwitch.new;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) {
        [self.Switch setOn:true];
    } else {
        [self.Switch setOn:false];
    }
    [self.Switch handleControlEvents:UIControlEventValueChanged withBlock:actionBlock];
    self.accessoryView = self.Switch;

    [self addSubview:self.Switch];
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
    [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
