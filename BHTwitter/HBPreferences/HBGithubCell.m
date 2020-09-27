//
//  HBGithubCell.m
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBGithubCell.h"

@implementation HBGithubCell

- (instancetype)initGithubCellWithTitle:(NSString *)title detailTitle:(NSString *)Dtitle GithubURL:(NSString *)gURL {
    HBGithubCell *cell = [self init];
    self.GithubURL = gURL;
    
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

- (SFSafariViewController *)SafariViewControllerForURL {
    SFSafariViewController *SafariVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:self.GithubURL]];
    return SafariVC;
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    
    if (self.GithubURL.length == 0) {
        NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
        [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
        [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        [viewController presentViewController:[self SafariViewControllerForURL] animated:true completion:nil];
    }
}

- (UIContextMenuConfiguration *)contextMenuConfigurationForRowAtCell:(HBCell *)cell FromTable:(HBPreferences *)viewController  API_AVAILABLE(ios(13.0)) {
    UIContextMenuConfiguration *configuration = [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:^UIViewController * _Nullable {
        return [self SafariViewControllerForURL];
    } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        
        UIAction *open = [UIAction actionWithTitle:@"Open Link" image:[UIImage systemImageNamed:@"safari"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [viewController presentViewController:[self SafariViewControllerForURL] animated:true completion:nil];
        }];
        
        UIAction *copy = [UIAction actionWithTitle:@"Copy Link" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            UIPasteboard.generalPasteboard.string = self.GithubURL;
        }];
        
        UIAction *share = [UIAction actionWithTitle:@"Share..." image:[UIImage systemImageNamed:@"square.and.arrow.up"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            UIActivityViewController *ac = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL URLWithString:self.GithubURL]] applicationActivities:nil];
            [viewController presentViewController:ac animated:true completion:nil];
        }];
        return [UIMenu menuWithTitle:@"" children:@[open, copy, share]];
    }];
    
    return configuration;
}
@end
