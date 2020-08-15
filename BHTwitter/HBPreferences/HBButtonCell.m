//
//  HBButtonCell.m
//  Cephei
//
//  Created by BandarHelal on 06/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBButtonCell.h"

@implementation HBButtonCell

- (instancetype)initButtonCellWithTitle:(NSString *)title actionBlock:(HBPValueChanged)actionBlock image:(UIImage *)img DetailTitle:(NSString *)Dtitle {
    HBButtonCell *Cell = [self init];
    [self setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    self.valueChanged = actionBlock;
    if (!(img == nil)) {
        [Cell setSeparatorInset:UIEdgeInsetsMake(0, 60, 0, 0)];
        self.image = UIImageView.new;
        [self.image setBackgroundColor:[UIColor clearColor]];
        [self.image setImage:img];
        [self.image setTranslatesAutoresizingMaskIntoConstraints:false];
        [self addSubview:self.image];
        
        [self.image.topAnchor constraintEqualToAnchor:self.topAnchor constant:12].active = true;
        [self.image.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
        [self.image.widthAnchor constraintEqualToConstant:29].active = true;
        [self.image.heightAnchor constraintEqualToConstant:29].active = true;
        
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
    } else {
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
        
        [self.detailLabel.topAnchor constraintEqualToAnchor:self.title.bottomAnchor constant:-1].active = true;
        [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
    }
    return Cell;
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
    [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.valueChanged) {
        self.valueChanged(self);
    }
}


@end
