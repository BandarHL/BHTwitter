//
//  BHAppIconViewController.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//  Revised: categorized icons, dynamic "Other" section, proper taps to change the icon
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
@property (nonatomic, copy) NSArray<NSString *> *sectionTitles;
@property (nonatomic, copy) NSArray<NSArray<BHAppIconItem *> *> *sectionedIcons;
@end

@implementation BHAppIconViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Header label
    self.headerLabel = [[UILabel alloc] init];
    self.headerLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_HEADER_TITLE"];
    self.headerLabel.textColor = [UIColor secondaryLabelColor];
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.font = [UIFont systemFontOfSize:15];
    self.headerLabel.textAlignment = NSTextAlignmentJustified;
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // Collection view layout
    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    flow.sectionInset = UIEdgeInsetsMake(16, 16, 16, 16);
    flow.minimumLineSpacing = 10;
    flow.minimumInteritemSpacing = 10;

    self.appIconCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:flow];
    self.appIconCollectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
    [self.appIconCollectionView registerClass:[BHAppIconCell class]
                      forCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier]];
    [self.appIconCollectionView registerClass:[UICollectionReusableView class]
                      forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                             withReuseIdentifier:@"HeaderView"];
    self.appIconCollectionView.delegate = self;
    self.appIconCollectionView.dataSource = self;
    self.appIconCollectionView.translatesAutoresizingMaskIntoConstraints = NO;

    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.headerLabel];
    [self.view addSubview:self.appIconCollectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.headerLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.headerLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.appIconCollectionView.topAnchor constraintEqualToAnchor:self.headerLabel.bottomAnchor],
        [self.appIconCollectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.appIconCollectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.appIconCollectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self setupAppIcons];
}

- (void)setupAppIcons {
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *iconsDict = [bundle objectForInfoDictionaryKey:@"CFBundleIcons"];

    // Build flat list
    NSMutableArray<BHAppIconItem*> *flat = [NSMutableArray array];
    NSDictionary *priDict = iconsDict[@"CFBundlePrimaryIcon"];
    BHAppIconItem *primary = [[BHAppIconItem alloc]
        initWithBundleIconName:priDict[@"CFBundleIconName"]
                 iconFileNames:priDict[@"CFBundleIconFiles"]
                  isPrimaryIcon:YES];
    [flat addObject:primary];

    NSDictionary *alts = iconsDict[@"CFBundleAlternateIcons"];
    [alts enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *alt, BOOL *stop) {
        BHAppIconItem *item = [[BHAppIconItem alloc]
            initWithBundleIconName:alt[@"CFBundleIconName"]
                     iconFileNames:alt[@"CFBundleIconFiles"]
                      isPrimaryIcon:NO];
        [flat addObject:item];
    }];

    // Categories
    NSArray<NSString*> *allCategories = @[
        @"Default",
        @"Custom Icons",
        @"Seasonal Icons",
        @"Holidays",
        @"Sports",
        @"Pride",
        @"Other"
    ];
    NSMutableDictionary<NSString*, NSMutableArray<BHAppIconItem*>*> *buckets = [NSMutableDictionary new];
    for (NSString *cat in allCategories) buckets[cat] = [NSMutableArray new];

    NSSet<NSString*> *seasonKeys = [NSSet setWithArray:@[@"Autumn", @"Summer", @"Winter"]];
    NSSet<NSString*> *holidayKeys = [NSSet setWithArray:@[@"BlackHistory", @"Holi", @"EarthHour", @"WomansDay", @"LunarNewYear", @"StPatricksDay"]];
    NSSet<NSString*> *sportKeys = [NSSet setWithArray:@[@"BeijingOlympics", @"FormulaOne", @"Daytona", @"Nba", @"Ncaa"]];

    for (BHAppIconItem *item in flat) {
        if (item.isPrimaryIcon) {
            [buckets[@"Default"] addObject:item];
        } else if ([item.bundleIconName hasPrefix:@"Custom-Icon"]) {
            [buckets[@"Custom Icons"] addObject:item];
        } else {
            BOOL placed = NO;
            for (NSString *key in seasonKeys) if ([item.bundleIconName containsString:key]) { [buckets[@"Seasonal Icons"] addObject:item]; placed=YES; break; }
            if (placed) continue;
            for (NSString *key in holidayKeys) if ([item.bundleIconName containsString:key]) { [buckets[@"Holidays"] addObject:item]; placed=YES; break; }
            if (placed) continue;
            for (NSString *key in sportKeys) if ([item.bundleIconName containsString:key]) { [buckets[@"Sports"] addObject:item]; placed=YES; break; }
            if (placed) continue;
            if ([item.bundleIconName containsString:@"Pride"]) {
                [buckets[@"Pride"] addObject:item];
            } else {
                [buckets[@"Other"] addObject:item];
            }
        }
    }

    // Build sections
    NSMutableArray<NSString*> *titles = [NSMutableArray new];
    NSMutableArray<NSArray<BHAppIconItem*>*> *sections = [NSMutableArray new];
    for (NSString *cat in allCategories) {
        NSArray *arr = buckets[cat];
        if (arr.count) { [titles addObject:cat]; [sections addObject:arr]; }
    }
    self.sectionTitles = titles;
    self.sectionedIcons = sections;
    [self.appIconCollectionView reloadData];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.sectionedIcons.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.sectionedIcons[section].count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BHAppIconCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier]
                                                                       forIndexPath:indexPath];
    BHAppIconItem *item = self.sectionedIcons[indexPath.section][indexPath.row];
    // Load image
    NSString *settingsAsset;
    if (item.isPrimaryIcon) {
        NSString *name = item.bundleIconName;
        if ([name hasSuffix:@"AppIcon"]) name = [name substringToIndex:name.length-@"AppIcon".length];
        settingsAsset = [NSString stringWithFormat:@"Icon-%@-settings", name];
    } else {
        settingsAsset = [item.bundleIconName stringByAppendingString:@"-settings"];
    }
    UIImage *img = [UIImage imageNamed:settingsAsset] ?: [UIImage imageNamed:item.bundleIconName];
    if (!img) {
        for (NSString *base in item.bundleIconFiles.reverseObjectEnumerator) {
            img = [UIImage imageNamed:base]; if (img) break;
        }
    }
    cell.imageView.image = img;

    // Checkmark
    NSString *current = [UIApplication sharedApplication].alternateIconName;
    BOOL isActive = current ? [current isEqualToString:item.bundleIconName] : item.isPrimaryIcon;
    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image = [UIImage systemImageNamed:@"circle"];
    }];
    if (isActive) cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    BHAppIconItem *item = self.sectionedIcons[indexPath.section][indexPath.row];
    // Reset checkmarks
    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image = [UIImage systemImageNamed:@"circle"];
    }];
    BHAppIconCell *cell = (BHAppIconCell*)[collectionView cellForItemAtIndexPath:indexPath];
    NSString *toSet = item.isPrimaryIcon ? nil : item.bundleIconName;
    [[UIApplication sharedApplication] setAlternateIconName:toSet completionHandler:^(NSError * _Nullable error) {
        if (!error) {
            cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
        }
    }];
}

#pragma mark - Section Headers

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                            withReuseIdentifier:@"HeaderView"
                                                                                   forIndexPath:indexPath];
    [header.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    if (indexPath.section < 2) return header;
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.font = [UIFont boldSystemFontOfSize:16];
    lbl.textColor = [UIColor labelColor];
    lbl.text = self.sectionTitles[indexPath.section];
    [header addSubview:lbl];
    [NSLayoutConstraint activateConstraints:@[
        [lbl.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [lbl.centerYAnchor constraintEqualToAnchor:header.centerYAnchor]
    ]];
    return header;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section {
    return (section < 2) ? CGSizeZero : CGSizeMake(collectionView.bounds.size.width, 30);
}

#pragma mark - FlowLayout Sizes

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(98, 136);
}

@end
