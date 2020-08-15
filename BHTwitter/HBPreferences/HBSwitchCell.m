//
//  HBSwitchCell.m
//  Cephei
//
//  Created by BandarHelal on 06/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBSwitchCell.h"

@implementation HBSwitchCell

- (instancetype)initSwitchCellWithImage:(UIImage *)img Title:(NSString *)title DetailTitle:(NSString *)Dtitle switchKey:(NSString *)key withBlock:(ALActionBlock)actionBlock {
    HBSwitchCell *cell = [self init];
    
    [self setupUI:Dtitle actionBlock:actionBlock cell:cell img:img switchMod:key title:title];
    
    
    return cell;
}

- (void)setupUI:(NSString *)Dtitle actionBlock:(ALActionBlock)actionBlock cell:(HBSwitchCell *)cell img:(UIImage *)img switchMod:(NSString *)key title:(NSString *)title {
    if (!(img == nil)) {
        
        if (!(Dtitle.length == 0)) {
            
            [cell setSeparatorInset:UIEdgeInsetsMake(0, 60, 0, 0)];
            self.image = UIImageView.new;
            [self.image setBackgroundColor:[UIColor clearColor]];
            [self.image setImage:img];
            [self.image setTranslatesAutoresizingMaskIntoConstraints:false];
            [self addSubview:self.image];
            
            [self.image.topAnchor constraintEqualToAnchor:self.topAnchor constant:12].active = true;
            [self.image.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
            [self.image.widthAnchor constraintEqualToConstant:29].active = true;
            [self.image.heightAnchor constraintEqualToConstant:29].active = true;
            
            self.Switch = UISwitch.new;
            if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) {
                [self.Switch setOn:true];
                [[NSUserDefaults standardUserDefaults] setBool:true forKey:key];
            } else {
                [self.Switch setOn:false];
                [[NSUserDefaults standardUserDefaults] setBool:false forKey:key];
            }
            [self.Switch handleControlEvents:UIControlEventValueChanged withBlock:actionBlock];
            self.accessoryView = self.Switch;
            
            [self addSubview:self.Switch];
            
            self.title = UILabel.new;
            [self.title setText:title];
            [self.title setFont:[UIFont systemFontOfSize:17]];
            [self.title setNumberOfLines:0];
            [self.title setTranslatesAutoresizingMaskIntoConstraints:false];
            [self addSubview:self.title];
            
            [self.title.topAnchor constraintEqualToAnchor:self.topAnchor constant:12].active = true;
            [self.title.leadingAnchor constraintEqualToAnchor:self.image.trailingAnchor constant:12].active = true;
            
            self.detailLabel = UILabel.new;
            [self.detailLabel setText:Dtitle];
            [self.detailLabel setTextColor:[UIColor systemGrayColor]];
            [self.detailLabel setFont:[UIFont systemFontOfSize:12]];
            [self.detailLabel setNumberOfLines:0];
            [self.detailLabel setTranslatesAutoresizingMaskIntoConstraints:false];
            [self addSubview:self.detailLabel];
            
            [self.detailLabel.topAnchor constraintEqualToAnchor:self.image.bottomAnchor constant:-10].active = true;
            [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.image.trailingAnchor constant:12].active = true;
            [self.detailLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-60].active = true;
        } else {
            [cell setSeparatorInset:UIEdgeInsetsMake(0, 60, 0, 0)];
            self.image = UIImageView.new;
            [self.image setBackgroundColor:[UIColor clearColor]];
            [self.image setImage:img];
            [self.image setTranslatesAutoresizingMaskIntoConstraints:false];
            [self addSubview:self.image];
            
            [self.image.topAnchor constraintEqualToAnchor:self.topAnchor constant:12].active = true;
            [self.image.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
            [self.image.widthAnchor constraintEqualToConstant:29].active = true;
            [self.image.heightAnchor constraintEqualToConstant:29].active = true;
            
            self.Switch = UISwitch.new;
            if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) {
                [self.Switch setOn:true];
                [[NSUserDefaults standardUserDefaults] setBool:true forKey:key];
            } else {
                [self.Switch setOn:false];
                [[NSUserDefaults standardUserDefaults] setBool:false forKey:key];
            }
            [self.Switch handleControlEvents:UIControlEventValueChanged withBlock:actionBlock];
            self.accessoryView = self.Switch;
            [self addSubview:self.Switch];
            
            self.title = UILabel.new;
            [self.title setText:title];
            [self.title setFont:[UIFont systemFontOfSize:17]];
            [self.title setNumberOfLines:0];
            [self.title setTranslatesAutoresizingMaskIntoConstraints:false];
            [self addSubview:self.title];
            
            [self.title.topAnchor constraintEqualToAnchor:self.topAnchor constant:17].active = true;
            [self.title.leadingAnchor constraintEqualToAnchor:self.image.trailingAnchor constant:12].active = true;
        }
    } else {
        
        if (!(Dtitle.length == 0)) {
            self.Switch = UISwitch.new;
            if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) {
                [self.Switch setOn:true];
                [[NSUserDefaults standardUserDefaults] setBool:true forKey:key];
            } else {
                [self.Switch setOn:false];
                [[NSUserDefaults standardUserDefaults] setBool:false forKey:key];
            }
            [self.Switch handleControlEvents:UIControlEventValueChanged withBlock:actionBlock];
            self.accessoryView = self.Switch;
            [self addSubview:self.Switch];
            
            self.title = UILabel.new;
            [self.title setText:title];
            [self.title setFont:[UIFont systemFontOfSize:17]];
            [self.title setNumberOfLines:0];
            [self.title setTranslatesAutoresizingMaskIntoConstraints:false];
            [self addSubview:self.title];
            
            [self.title.topAnchor constraintEqualToAnchor:self.topAnchor constant:12].active = true;
            [self.title.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
            
            self.detailLabel = UILabel.new;
            [self.detailLabel setText:Dtitle];
            [self.detailLabel setTextColor:[UIColor systemGrayColor]];
            [self.detailLabel setFont:[UIFont systemFontOfSize:12]];
            [self.detailLabel setNumberOfLines:0];
            [self.detailLabel setTranslatesAutoresizingMaskIntoConstraints:false];
            [self addSubview:self.detailLabel];
            
//            [self.detailLabel.heightAnchor constraintGreaterThanOrEqualToConstant:55].active = true;
            [self.detailLabel.topAnchor constraintEqualToAnchor:self.title.bottomAnchor constant:-1].active = true;
            [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
            [self.detailLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-60].active = true;
            
        } else {
            self.Switch = UISwitch.new;
            if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) {
                [self.Switch setOn:true];
                [[NSUserDefaults standardUserDefaults] setBool:true forKey:key];
            } else {
                [self.Switch setOn:false];
                [[NSUserDefaults standardUserDefaults] setBool:false forKey:key];
            }
            [self.Switch handleControlEvents:UIControlEventValueChanged withBlock:actionBlock];
            self.accessoryView = self.Switch;
            [self addSubview:self.Switch];
            
            self.title = UILabel.new;
            [self.title setText:title];
            [self.title setFont:[UIFont systemFontOfSize:17]];
            [self.title setNumberOfLines:0];
            [self.title setTranslatesAutoresizingMaskIntoConstraints:false];
            [self addSubview:self.title];
            
            [self.title.topAnchor constraintEqualToAnchor:self.topAnchor constant:17].active = true;
            [self.title.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
        }
    }
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
    [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
