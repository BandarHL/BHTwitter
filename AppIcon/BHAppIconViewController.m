//
//  BHAppIconViewController.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//  Revised to prefer “-settings” asset, then asset catalog, then bundle files.
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

    // Header label
    self.headerLabel = [[UILabel alloc] init];
    self.headerLabel.text = [[BHTBundle sharedBundle]
        localizedStringForKey:@"APP_ICON_HEADER_TITLE"];
    self.headerLabel.textColor    = [UIColor secondaryLabelColor];
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.font         = [UIFont systemFontOfSize:15];
    self.headerLabel.textAlignment = NSTextAlignmentJustified;
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // Collection view setup
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    self.appIconCollectionView = [[UICollectionView alloc]
        initWithFrame:CGRectZero
        collectionViewLayout:flowLayout];
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
    NSBundle *appBundle = [NSBundle mainBundle];
    NSDictionary *iconsDict =
        [appBundle objectForInfoDictionaryKey:@"CFBundleIcons"];

    // Primary icon
    NSDictionary *primaryDict = iconsDict[@"CFBundlePrimaryIcon"];
    NSString   *primaryName  = primaryDict[@"CFBundleIconName"];
    NSArray<NSString*> *primaryFiles = primaryDict[@"CFBundleIconFiles"];
    [self.icons addObject:
        [[BHAppIconItem alloc]
            initWithBundleIconName:primaryName
                     iconFileNames:primaryFiles
                      isPrimaryIcon:YES]];

    // Alternate icons
    NSDictionary *alts = iconsDict[@"CFBundleAlternateIcons"];
    [alts enumerateKeysAndObjectsUsingBlock:^(NSString *key,
                                              NSDictionary *altDict,
                                              BOOL *stop) {
        NSString   *altName  = altDict[@"CFBundleIconName"];
        NSArray<NSString*> *altFiles = altDict[@"CFBundleIconFiles"];
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
     numberOfItemsInSection:(NSInteger)section
{
    return self.icons.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    BHAppIconCell *cell = [collectionView
        dequeueReusableCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier]
                                  forIndexPath:indexPath];
    BHAppIconItem *item = self.icons[indexPath.row];

    // 1) Try “-settings” asset
    NSString *settingsName = [item.bundleIconName stringByAppendingString:@"-settings"];
    UIImage *iconImg = [UIImage imageNamed:settingsName];

    // 2) Fallback: asset catalog icon
    if (!iconImg) {
        iconImg = [UIImage imageNamed:item.bundleIconName];
    }

    // 3) Fallback: loose bundle files
    if (!iconImg) {
        NSString *fileBase = item.bundleIconFiles.lastObject;
        iconImg = [UIImage imageNamed:fileBase];
        if (!iconImg) {
            NSString *path = [[NSBundle mainBundle] pathForResource:fileBase
                                                              ofType:@"png"];
            iconImg = [UIImage imageWithContentsOfFile:path];
        }
    }

    cell.imageView.image = iconImg;

    // Checkmark logic
    NSString *currentAlt = [UIApplication sharedApplication].alternateIconName;
    BOOL isActive = currentAlt
                  ? [currentAlt isEqualToString:item.bundleIconName]
                  : item.isPrimaryIcon;

    // Clear all
    [collectionView.visibleCells
      enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell *obj,
                                   NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)obj).checkIMG.image =
            [UIImage systemImageNamed:@"circle"];
    }];
    if (isActive) {
        cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
    }

    return cell;
}

#pragma mark – UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    BHAppIconItem *item = self.icons[indexPath.row];

    // Clear
    [collectionView.visibleCells
      enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell *obj,
                                   NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)obj).checkIMG.image =
            [UIImage systemImageNamed:@"circle"];
    }];

    BHAppIconCell *cell = (BHAppIconCell*)
        [collectionView cellForItemAtIndexPath:indexPath];
    NSString *toSet = item.isPrimaryIcon
                    ? nil
                    : item.bundleIconName;
    [[UIApplication sharedApplication]
        setAlternateIconName:toSet
             completionHandler:^(NSError * _Nullable error) {
        if (!error) {
            cell.checkIMG.image =
                [UIImage systemImageNamed:@"checkmark.circle"];
        }
    }];
}

#pragma mark – UICollectionViewDelegateFlowLayout

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(16, 16, 16, 16);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 10;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 10;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(98, 136);
}

@end
