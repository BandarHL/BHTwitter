//
//  HBLinkCell.m
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBLinkCell.h"

@implementation HBLinkCell

NSString *URL;

- (instancetype)initLinkCellWithImage:(UIImage *)img Title:(NSString *)title DetailTitle:(NSString *)Dtitle Link:(NSString *)url {
    HBLinkCell *cell = [self init];
    URL = url;
    
    [self setupUI:Dtitle img:img title:title];
    
    
    return cell;
}


- (void)setupUI:(NSString *)Dtitle img:(UIImage *)img title:(NSString *)title {
    HBLinkCell *cell = [self init];
    if (!(img == nil)) {
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
        
        self.SafariImage = UIImageView.new;
        [self.SafariImage setBackgroundColor:[UIColor clearColor]];
        [self.SafariImage setImage:[UIImage imageNamed:@"/Library/Application Support/BHT/Ressources.bundle/safari"]];
        [self.SafariImage setTranslatesAutoresizingMaskIntoConstraints:false];
        [self addSubview:self.SafariImage];
        
        [self.SafariImage.topAnchor constraintEqualToAnchor:self.topAnchor constant:20].active = true;
        [self.SafariImage.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20].active = true;
        [self.SafariImage.widthAnchor constraintEqualToConstant:16].active = true;
        [self.SafariImage.heightAnchor constraintEqualToConstant:16].active = true;
        
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
        
        self.SafariImage = UIImageView.new;
        [self.SafariImage setBackgroundColor:[UIColor clearColor]];
        [self.SafariImage setImage:[UIImage imageNamed:@"safari"]];
        [self.SafariImage setTranslatesAutoresizingMaskIntoConstraints:false];
        [self addSubview:self.SafariImage];
        
        [self.SafariImage.topAnchor constraintEqualToAnchor:self.topAnchor constant:20].active = true;
        [self.SafariImage.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20].active = true;
        [self.SafariImage.widthAnchor constraintEqualToConstant:16].active = true;
        [self.SafariImage.heightAnchor constraintEqualToConstant:16].active = true;
        
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
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    if (URL.length == 0) {
        NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
        [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
        [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        SFSafariViewController *SafariVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:URL]];
//        [[UIApplication.sharedApplication keyWindow].rootViewController.childViewControllers[0] presentViewController:SafariVC animated:true completion:nil];
        [viewController presentViewController:SafariVC animated:true completion:nil];
    }
}

@end
