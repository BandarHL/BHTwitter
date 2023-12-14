//
//  BHAppIconViewController.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import "BHAppIconViewController.h"
#import "BHAppIconItem.h"
#import "BHAppIconCell.h"
#import "../BHTBundle/BHTBundle.h"

@interface BHAppIconViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *appIconCollectionView;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) NSMutableArray<BHAppIconItem *> *icons;

@end

@implementation BHAppIconViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.headerLabel = [[UILabel alloc] init];
    self.headerLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_HEADER_TITLE"];
    self.headerLabel.textColor = [UIColor secondaryLabelColor];
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.font = [UIFont systemFontOfSize:15];
    self.headerLabel.textAlignment = NSTextAlignmentJustified;
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    self.appIconCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:flowLayout];
    self.appIconCollectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
    [self.appIconCollectionView registerClass:[BHAppIconCell class] forCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier]];
    self.appIconCollectionView.delegate = self;
    self.appIconCollectionView.dataSource = self;
    self.appIconCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.icons = [NSMutableArray new];
    
    [self setupAppIcons];
    
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.headerLabel];
    [self.view addSubview:self.appIconCollectionView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.headerLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.headerLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.headerLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [self.appIconCollectionView.topAnchor constraintEqualToAnchor:self.headerLabel.bottomAnchor],
        [self.appIconCollectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.appIconCollectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.appIconCollectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)setupAppIcons {
    NSBundle *appBundle = [NSBundle mainBundle];
    NSDictionary *CFBundleIcons = [appBundle objectForInfoDictionaryKey:@"CFBundleIcons"];
    NSDictionary *CFBundlePrimaryIcon = CFBundleIcons[@"CFBundlePrimaryIcon"];
    NSString *primaryIcon = CFBundlePrimaryIcon[@"CFBundleIconName"];

    NSDictionary *CFBundleAlternateIcons = CFBundleIcons[@"CFBundleAlternateIcons"];

    [self.icons addObject:[[BHAppIconItem alloc] initWithImageName:primaryIcon
                                               settingsImageName:@"Icon-Production-settings"
                                                    isPrimaryIcon:YES]];

    [CFBundleAlternateIcons enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        [self.icons addObject:[[BHAppIconItem alloc] initWithImageName:key
                                                   settingsImageName:[NSString stringWithFormat:@"%@-settings", key]
                                                        isPrimaryIcon:NO]];
    }];
    
    [self.appIconCollectionView reloadData];
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.icons.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BHAppIconCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier] forIndexPath:indexPath];
    BHAppIconItem *currCell = self.icons[indexPath.row];
    cell.imageView.image = [UIImage imageNamed:currCell.settingsImageName];

    NSString *alternateIconName = [UIApplication sharedApplication].alternateIconName;
    if (alternateIconName) {
        if ([currCell.imageName isEqualToString:alternateIconName]) {
            [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                BHAppIconCell *iconCell = (BHAppIconCell *)obj;
                iconCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
            }];
            cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
        }
    } else if (currCell.isPrimaryIcon) {
        [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            BHAppIconCell *iconCell = (BHAppIconCell *)obj;
            iconCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
        }];
        cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
    }

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    BHAppIconItem *iconItem = self.icons[indexPath.row];
    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        BHAppIconCell *iconCell = (BHAppIconCell *)obj;
        iconCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
    }];
    BHAppIconCell *currCell = (BHAppIconCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [[UIApplication sharedApplication] setAlternateIconName:(iconItem.isPrimaryIcon ? nil : iconItem.imageName) completionHandler:^(NSError * _Nullable error) {
        if (!error) {
            currCell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
        }
    }];
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(16, 16, 16, 16);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(98, 136);
}

@end
