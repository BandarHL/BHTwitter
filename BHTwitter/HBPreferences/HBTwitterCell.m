//
//  HBTwitterCell.m
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBTwitterCell.h"

@implementation HBTwitterCell

NSString *AccountURL;

- (instancetype)initTwitterCellWithTitle:(NSString *)title detail:(NSString *)detail AccountLink:(NSString *)Aurl {
    HBTwitterCell *cell = [super init];
    AccountURL = Aurl;
    
    [self setupUI:Aurl detail:detail title:title];
    
    [cell setSeparatorInset:UIEdgeInsetsMake(0, 60, 0, 0)];
    return cell;
}


- (void)setupUI:(NSString *)Aurl detail:(NSString *)detail title:(NSString *)title {
    self.userImage = UIImageView.new;
    [self.userImage setClipsToBounds:true];
    [self.userImage setBackgroundColor:[UIColor clearColor]];
    [self.userImage setTranslatesAutoresizingMaskIntoConstraints:false];
    [self.userImage sd_setImageWithURL:[self getTwitterImage:Aurl]];
    [self.userImage.layer setCornerRadius:14.5];
    [self addSubview:self.userImage];
    
    [self.userImage.topAnchor constraintEqualToAnchor:self.topAnchor constant:12].active = true;
    [self.userImage.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
    [self.userImage.widthAnchor constraintEqualToConstant:29].active = true;
    [self.userImage.heightAnchor constraintEqualToConstant:29].active = true;
    
    self.TwitterImage = UIImageView.new;
    [self.TwitterImage setBackgroundColor:[UIColor clearColor]];
    [self.TwitterImage setImage:[UIImage imageNamed:@"/Library/Application Support/BHT/Ressources.bundle/twitter"]];
    [self.TwitterImage setTranslatesAutoresizingMaskIntoConstraints:false];
    [self addSubview:self.TwitterImage];
    
    [self.TwitterImage.topAnchor constraintEqualToAnchor:self.topAnchor constant:20].active = true;
    [self.TwitterImage.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20].active = true;
    [self.TwitterImage.widthAnchor constraintEqualToConstant:16].active = true;
    [self.TwitterImage.heightAnchor constraintEqualToConstant:13].active = true;
    
    
    self.userName = UILabel.new;
    [self.userName setText:title];
    [self.userName setFont:[UIFont systemFontOfSize:17]];
    [self.userName setNumberOfLines:0];
    [self.userName setTranslatesAutoresizingMaskIntoConstraints:false];
    [self addSubview:self.userName];
    
    [self.userName.topAnchor constraintEqualToAnchor:self.topAnchor constant:12].active = true;
    [self.userName.leadingAnchor constraintEqualToAnchor:self.userImage.trailingAnchor constant:12].active = true;
    
    self.detailLabel = UILabel.new;
    [self.detailLabel setText:detail];
    [self.detailLabel setTextColor:[UIColor systemGrayColor]];
    [self.detailLabel setFont:[UIFont systemFontOfSize:12]];
    [self.detailLabel setNumberOfLines:0];
    [self.detailLabel setTranslatesAutoresizingMaskIntoConstraints:false];
    [self addSubview:self.detailLabel];
    
    [self.detailLabel.topAnchor constraintEqualToAnchor:self.userName.bottomAnchor constant:-1].active = true;
    [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.userImage.trailingAnchor constant:12].active = true;
}

- (NSURL *)getTwitterImage:(NSString *)url {
    NSString *username = [url stringByReplacingOccurrencesOfString:@"https://twitter.com/" withString:@""];
    
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://twitter-avatar.now.sh/%@", username]];
}


- (void)didSelectFromTable:(HBPreferences *)viewController {
    if (AccountURL.length == 0) {
        NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
        [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        SFSafariViewController *SafariVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:AccountURL]];
//        [[UIApplication.sharedApplication windows][0].rootViewController.navigationController presentViewController:SafariVC animated:true completion:nil];
//        [viewController.navigationController pushViewController:SafariVC animated:true];
        [viewController presentViewController:SafariVC animated:true completion:nil];
    }
    
}

@end
