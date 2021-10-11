//
//  HBTwitterCell.m
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBTwitterCell.h"

@implementation HBTwitterCell

- (instancetype)initTwitterCellWithTitle:(NSString *)title detail:(NSString *)detail AccountLink:(NSString *)Aurl {
    HBTwitterCell *cell = [super init];
    self.AccountURL = Aurl;
    
    [self setupUI:Aurl detail:detail title:title];
    
    [cell setSeparatorInset:UIEdgeInsetsMake(0, 60, 0, 0)];
    return cell;
}


- (void)setupUI:(NSString *)Aurl detail:(NSString *)detail title:(NSString *)title {
    self.userImage = UIImageView.new;
    [self.userImage setClipsToBounds:true];
    [self.userImage setBackgroundColor:[UIColor clearColor]];
    [self.userImage setTranslatesAutoresizingMaskIntoConstraints:false];
    self.userImage.image = [UIImage bhtwitter_imageNamed:@"BandarHL.jpg"];
    [self.userImage.layer setCornerRadius:14.5];
    [self addSubview:self.userImage];
    
    [self.userImage.topAnchor constraintEqualToAnchor:self.topAnchor constant:12].active = true;
    [self.userImage.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20].active = true;
    [self.userImage.widthAnchor constraintEqualToConstant:29].active = true;
    [self.userImage.heightAnchor constraintEqualToConstant:29].active = true;
    
    self.TwitterImage = UIImageView.new;
    [self.TwitterImage setBackgroundColor:[UIColor clearColor]];
    [self.TwitterImage setImage:[UIImage bhtwitter_imageNamed:@"twitter"]];
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

- (SFSafariViewController *)SafariViewControllerForURL {
    SFSafariViewController *SafariVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:self.AccountURL]];
    return SafariVC;
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    if (self.AccountURL.length == 0) {
        NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
        [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        [viewController presentViewController:[self SafariViewControllerForURL] animated:true completion:nil];
    }
    
}

- (UIContextMenuConfiguration *)contextMenuConfigurationForRowAtCell:(HBCell *)cell FromTable:(HBPreferences *)viewController API_AVAILABLE(ios(13.0)) {
    SFSafariViewController *SafariVC = [self SafariViewControllerForURL];
    
    UIContextMenuConfiguration *configuration = [UIContextMenuConfiguration configurationWithIdentifier:[RuntimeExplore getAddressFromDescription:SafariVC.description] previewProvider:^UIViewController * _Nullable{
        return SafariVC;
    } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        UIAction *open = [UIAction actionWithTitle:@"Open Link" image:[UIImage systemImageNamed:@"safari"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [viewController presentViewController:SafariVC animated:true completion:nil];
        }];
        
        UIAction *copy = [UIAction actionWithTitle:@"Copy Link" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            UIPasteboard.generalPasteboard.string = self.AccountURL;
        }];
        
        UIAction *share = [UIAction actionWithTitle:@"Share..." image:[UIImage systemImageNamed:@"square.and.arrow.up"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            UIActivityViewController *ac = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL URLWithString:self.AccountURL]] applicationActivities:nil];
            [viewController presentViewController:ac animated:true completion:nil];
        }];
        return [UIMenu menuWithTitle:@"" children:@[open, copy, share]];
    }];
    
    return configuration;
}

@end
