//
//  HBTwitterCell.m
//  Cephei

#import "HBTwitterCell.h"

@implementation HBTwitterCell

- (instancetype)initTwitterCellWithTitle:(NSString *)title detail:(NSString *)detail AccountLink:(NSString *)Aurl {
    HBTwitterCell *cell = [super init];
    self.AccountURL = Aurl;
    [self setupUI:Aurl detail:detail title:title];
    return cell;
}

- (void)setupUI:(NSString *)Aurl detail:(NSString *)detail title:(NSString *)title {
    
    [self.imageView setImage:[UIImage bhtwitter_imageNamed:@"BandarHL.jpg"]];
    [self.imageView setClipsToBounds:true];
    [self.imageView.layer setCornerRadius:(29/2)];
    
    CGSize size = CGSizeMake(29, 29);
    UIGraphicsBeginImageContextWithOptions(size, NO, UIScreen.mainScreen.scale);
    [self.image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newThumbnail = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    self.imageView.image = newThumbnail;
    
    self.TwitterImage = UIImageView.new;
    [self.TwitterImage setImage:[UIImage bhtwitter_imageNamed:@"twitter"]];
    [self.TwitterImage setTintColor:[UIColor systemGray3Color]];
    [self.TwitterImage setTranslatesAutoresizingMaskIntoConstraints:false];
    [self addSubview:self.TwitterImage];
    
    [self.TwitterImage.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = true;
    [self.TwitterImage.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20].active = true;
    [self.TwitterImage.widthAnchor constraintEqualToConstant:16].active = true;
    [self.TwitterImage.heightAnchor constraintEqualToConstant:13].active = true;
    
    [self.textLabel setText:title];
    [self.textLabel setTextColor:[UIColor colorWithRed:0.039 green:0.518 blue:1 alpha:1]];
    [self.textLabel setNumberOfLines:0];
    
    [self.detailTextLabel setText:detail];
    [self.detailTextLabel setTextColor:[UIColor secondaryLabelColor]];
    [self.detailTextLabel setFont:[UIFont systemFontOfSize:12]];
    [self.detailTextLabel setNumberOfLines:0];
    
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

- (UIContextMenuConfiguration *)contextMenuConfigurationForRowAtCell:(HBCell *)cell FromTable:(HBPreferences *)viewController {
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
