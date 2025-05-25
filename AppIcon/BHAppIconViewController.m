//
//  BHAppIconViewController.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//  Revised to prefer “-settings” assets, then catalog icons,
//  then highest-dimension root files via imageNamed:.
//

#import "BHAppIconViewController.h"
#import "BHAppIconItem.h"
#import "BHAppIconCell.h"
#import "../BHTBundle/BHTBundle.h"

@interface BHAppIconViewController () <
    UICollectionViewDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout
>
@property (nonatomic, strong) UICollectionView *appIconCollectionView;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) NSMutableArray<BHAppIconItem *> *icons;
@end

@implementation BHAppIconViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Header
    self.headerLabel = [[UILabel alloc] init];
    self.headerLabel.text = [[BHTBundle sharedBundle]
        localizedStringForKey:@"APP_ICON_HEADER_TITLE"];
    self.headerLabel.textColor    = [UIColor secondaryLabelColor];
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.font        = [UIFont systemFontOfSize:15];
    self.headerLabel.textAlignment = NSTextAlignmentJustified;
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // Collection
    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    self.appIconCollectionView = [[UICollectionView alloc]
        initWithFrame:CGRectZero
        collectionViewLayout:flow];
    self.appIconCollectionView.contentInsetAdjustmentBehavior =
        UIScrollViewContentInsetAdjustmentAlways;
    [self.appIconCollectionView
        registerClass:[BHAppIconCell class]
        forCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier]];
    self.appIconCollectionView.delegate   = self;
    self.appIconCollectionView.dataSource = self;
    self.appIconCollectionView.translatesAutoresizingMaskIntoConstraints = NO;

    self.icons = [NSMutableArray new];
    [self setupAppIcons];

    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.headerLabel];
    [self.view addSubview:self.appIconCollectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerLabel.topAnchor
            constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.headerLabel.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.headerLabel.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [self.appIconCollectionView.topAnchor
            constraintEqualToAnchor:self.headerLabel.bottomAnchor],
        [self.appIconCollectionView.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor],
        [self.appIconCollectionView.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],
        [self.appIconCollectionView.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)setupAppIcons {
    NSDictionary *iconsDict =
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];

    // Primary
    NSDictionary *pri = iconsDict[@"CFBundlePrimaryIcon"];
    NSString   *priName  = pri[@"CFBundleIconName"];
    NSArray<NSString*> *priFiles = pri[@"CFBundleIconFiles"];
    [self.icons addObject:
        [[BHAppIconItem alloc]
            initWithBundleIconName:priName
                     iconFileNames:priFiles
                      isPrimaryIcon:YES]];

    // Alternates
    NSDictionary *alts = iconsDict[@"CFBundleAlternateIcons"];
    [alts enumerateKeysAndObjectsUsingBlock:^(NSString *key,
                                              NSDictionary *alt,
                                              BOOL *stop) {
        NSString   *altName  = alt[@"CFBundleIconName"];
        NSArray<NSString*> *altFiles = alt[@"CFBundleIconFiles"];
        [self.icons addObject:
            [[BHAppIconItem alloc]
                initWithBundleIconName:altName
                         iconFileNames:altFiles
                          isPrimaryIcon:NO]];
    }];

    [self.appIconCollectionView reloadData];
}

#pragma mark – UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.icons.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BHAppIconCell *cell = [collectionView
        dequeueReusableCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier]
                                  forIndexPath:indexPath];
    BHAppIconItem *item = self.icons[indexPath.row];

    UIImage *img = nil;

    // 1) “-settings” asset
    NSString *settingsAsset = [item.bundleIconName stringByAppendingString:@"-settings"];
    img = [UIImage imageNamed:settingsAsset];

    // 2) Plain asset catalog
    if (!img) {
        img = [UIImage imageNamed:item.bundleIconName];
    }

    // 3) Root‐bundle files (highest-dimension first)
    if (!img && item.bundleIconFiles.count) {
        // reverse order: largest dimension last in Info.plist → first here
        for (NSString *base in item.bundleIconFiles.reverseObjectEnumerator) {
            img = [UIImage imageNamed:base];
            if (img) break;
        }
    }

    cell.imageView.image = img;

    // Checkmark
    NSString *currentAlt = [UIApplication sharedApplication].alternateIconName;
    BOOL isActive = currentAlt
                  ? [currentAlt isEqualToString:item.bundleIconName]
                  : item.isPrimaryIcon;

    [collectionView.visibleCells
      enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell *c,
                                   NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image =
            [UIImage systemImageNamed:@"circle"];
    }];
    if (isActive) {
        cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
    }

    return cell;
}

#pragma mark – UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    BHAppIconItem *item = self.icons[indexPath.row];

    [collectionView.visibleCells
      enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell *c,
                                   NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image =
            [UIImage systemImageNamed:@"circle"];
    }];

    BHAppIconCell *cell = (BHAppIconCell*)
        [collectionView cellForItemAtIndexPath:indexPath];
    NSString *toSet = item.isPrimaryIcon ? nil : item.bundleIconName;
    [[UIApplication sharedApplication]
        setAlternateIconName:toSet
             completionHandler:^(NSError * _Nullable error) {
        if (!error) {
            cell.checkIMG.image =
                [UIImage systemImageNamed:@"checkmark.circle"];
        }
    }];
}

#pragma mark – FlowLayout

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(16, 16, 16, 16);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(98, 136);
}

@end
