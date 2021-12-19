//
//  HBlinkCell.m
//  Cephei

#import "HBlinkCell.h"

@implementation HBlinkCell
- (instancetype)initLinkCellWithTitle:(NSString *)title detailTitle:(NSString *)Dtitle link:(NSString *)gURL {
    HBlinkCell *cell = [self init];
    self.url = gURL;
    [self setupUI:Dtitle title:title];
    return cell;
}

- (void)setupUI:(NSString *)Dtitle title:(NSString *)title {
    self.SafariImage = UIImageView.new;
    [self.SafariImage setImage:[UIImage systemImageNamed:@"safari"]];
    [self.SafariImage setTintColor:[UIColor lightGrayColor]];
    [self.SafariImage setTranslatesAutoresizingMaskIntoConstraints:false];
    [self addSubview:self.SafariImage];
    
    [self.SafariImage.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = true;
    [self.SafariImage.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20].active = true;
    [self.SafariImage.widthAnchor constraintEqualToConstant:16].active = true;
    [self.SafariImage.heightAnchor constraintEqualToConstant:16].active = true;
    
    [self.textLabel setText:title];
    [self.textLabel setTextColor:[UIColor colorWithRed:0.039 green:0.518 blue:1 alpha:1]];
    [self.textLabel setNumberOfLines:0];
    
    [self.detailTextLabel setText:Dtitle];
    [self.detailTextLabel setTextColor:[UIColor secondaryLabelColor]];
    [self.detailTextLabel setFont:[UIFont systemFontOfSize:12]];
    [self.detailTextLabel setNumberOfLines:0];
}

- (SFSafariViewController *)SafariViewControllerForURL {
    SFSafariViewController *SafariVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:self.url]];
    return SafariVC;
}

- (void)didSelectFromTable:(HBPreferences *)viewController {
    NSIndexPath *indexPath = [viewController.tableView indexPathForCell:self];
    if (self.url.length == 0) {
        [viewController.tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        [viewController presentViewController:[self SafariViewControllerForURL] animated:true completion:nil];
    }
}

- (UIContextMenuConfiguration *)contextMenuConfigurationForRowAtCell:(HBCell *)cell FromTable:(HBPreferences *)viewController {
    SFSafariViewController *SafariVC = [self SafariViewControllerForURL];
    
    UIContextMenuConfiguration *configuration = [UIContextMenuConfiguration configurationWithIdentifier:[RuntimeExplore getAddressFromDescription:SafariVC.description] previewProvider:^UIViewController * _Nullable {
        return SafariVC;
    } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        
        UIAction *open = [UIAction actionWithTitle:@"Open Link" image:[UIImage systemImageNamed:@"safari"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [viewController presentViewController:SafariVC animated:true completion:nil];
        }];
        
        UIAction *copy = [UIAction actionWithTitle:@"Copy Link" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            UIPasteboard.generalPasteboard.string = self.url;
        }];
        
        UIAction *share = [UIAction actionWithTitle:@"Share..." image:[UIImage systemImageNamed:@"square.and.arrow.up"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            UIActivityViewController *ac = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL URLWithString:self.url]] applicationActivities:nil];
            [viewController presentViewController:ac animated:true completion:nil];
        }];
        return [UIMenu menuWithTitle:@"" children:@[open, copy, share]];
    }];
    
    return configuration;
}
@end
