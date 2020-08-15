//
//  HBGithubCell.m
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBGithubCell.h"

@implementation HBGithubCell

NSString *GithubURL;

- (instancetype)initGithubCellWithTitle:(NSString *)title detailTitle:(NSString *)Dtitle GithubURL:(NSString *)gURL {
    HBGithubCell *cell = [self init];
    GithubURL = gURL;
    
    [self setupUI:Dtitle title:title];
    [cell setSeparatorInset:UIEdgeInsetsMake(0, 60, 0, 0)];
    return cell;
}

- (void)setupUI:(NSString *)Dtitle title:(NSString *)title {
    
    self.GithubImage = UIImageView.new;
    [self.GithubImage setBackgroundColor:[UIColor clearColor]];
    [self.GithubImage setImage:[UIImage imageNamed:@"/Library/Application Support/BHT/Ressources.bundle/github"]];
    [self.GithubImage setTranslatesAutoresizingMaskIntoConstraints:false];
    [self addSubview:self.GithubImage];
    
    [self.GithubImage.topAnchor constraintEqualToAnchor:self.topAnchor constant:12].active = true;
    [self.GithubImage.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
    [self.GithubImage.widthAnchor constraintEqualToConstant:29].active = true;
    [self.GithubImage.heightAnchor constraintEqualToConstant:29].active = true;
    
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
    [self.title.leadingAnchor constraintEqualToAnchor:self.GithubImage.trailingAnchor constant:12].active = true;
    
    self.detailLabel = UILabel.new;
    [self.detailLabel setText:Dtitle];
    [self.detailLabel setTextColor:[UIColor systemGrayColor]];
    [self.detailLabel setFont:[UIFont systemFontOfSize:12]];
    [self.detailLabel setNumberOfLines:0];
    [self.detailLabel setTranslatesAutoresizingMaskIntoConstraints:false];
    [self addSubview:self.detailLabel];
    
    [self.detailLabel.topAnchor constraintEqualToAnchor:self.GithubImage.bottomAnchor constant:-10].active = true;
    [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.GithubImage.trailingAnchor constant:12].active = true;
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    
    if (GithubURL.length == 0) {
        NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
        [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
        [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        SFSafariViewController *SafariVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:GithubURL]];
//        [[UIApplication.sharedApplication keyWindow].rootViewController.childViewControllers[0] presentViewController:SafariVC animated:true completion:nil];
        [viewController presentViewController:SafariVC animated:true completion:nil];
    }
}

@end
