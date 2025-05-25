//
//  BHAppIconViewController.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//  Revised: categorized icons into sections (default, custom, seasonal, holiday, sports, pride)
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

// Sectioned data
@property (nonatomic, copy) NSArray<NSString *> *sectionTitles;
@property (nonatomic, copy) NSArray<NSArray<BHAppIconItem *> *> *sectionedIcons;
@end

@implementation BHAppIconViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Top header
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

    // Static header + collection view
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
    // 1. Read flat icon items
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *iconsDict = [bundle objectForInfoDictionaryKey:@"CFBundleIcons"];

    // Primary
    NSDictionary *priDict = iconsDict[@"CFBundlePrimaryIcon"];
    NSString *priName = priDict[@"CFBundleIconName"];
    NSArray<NSString*> *priFiles = priDict[@"CFBundleIconFiles"];
    BHAppIconItem *primaryItem = [[BHAppIconItem alloc]
        initWithBundleIconName:priName
                 iconFileNames:priFiles
                  isPrimaryIcon:YES];

    // Alternates
    NSMutableArray<BHAppIconItem*> *flat = [NSMutableArray array];
    [flat addObject:primaryItem];
    NSDictionary *alts = iconsDict[@"CFBundleAlternateIcons"];
    [alts enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *alt, BOOL *stop) {
        NSString *altName = alt[@"CFBundleIconName"];
        NSArray<NSString*> *altFiles = alt[@"CFBundleIconFiles"];
        BHAppIconItem *item = [[BHAppIconItem alloc]
            initWithBundleIconName:altName
                     iconFileNames:altFiles
                      isPrimaryIcon:NO];
        [flat addObject:item];
    }];

    // 2. Define categories and keywords
    self.sectionTitles = @[@"Default", @"Custom Icons", @"Seasonal Icons", @"Holidays", @"Sports", @"Pride"];
    NSMutableArray<NSMutableArray<BHAppIconItem *>*> *sections = [NSMutableArray new];
    for (NSInteger i = 0; i < self.sectionTitles.count; i++) {
        [sections addObject:[NSMutableArray new]];
    }

    NSSet<NSString*> *seasonKeys = [NSSet setWithArray:@[@"Autumn", @"Summer", @"Winter"]];
    NSSet<NSString*> *holidayKeys = [NSSet setWithArray:@[@"BlackHistory", @"Holi", @"EarthHour", @"WomansDay", @"LunarNewYear", @"StPatricksDay"]];
    NSSet<NSString*> *sportKeys = [NSSet setWithArray:@[@"BeijingOlympics", @"FormulaOne", @"Daytona", @"Nba", @"Ncaa"]];

    for (BHAppIconItem *item in flat) {
        if (item.isPrimaryIcon) {
            [sections[0] addObject:item];
        } else if ([item.bundleIconName hasPrefix:@"Custom-Icon"]) {
            [sections[1] addObject:item];
        } else {
            BOOL placed = NO;
            for (NSString *key in seasonKeys) {
                if ([item.bundleIconName containsString:key]) {
                    [sections[2] addObject:item]; placed = YES; break;
                }
            }
            if (placed) continue;
            for (NSString *key in holidayKeys) {
                if ([item.bundleIconName containsString:key]) {
                    [sections[3] addObject:item]; placed = YES; break;
                }
            }
            if (placed) continue;
            for (NSString *key in sportKeys) {
                if ([item.bundleIconName containsString:key]) {
                    [sections[4] addObject:item]; placed = YES; break;
                }
            }
            if (placed) continue;
            if ([item.bundleIconName containsString:@"Pride"]) {
                [sections[5] addObject:item];
            }
        }
    }

    // 3. Assign and reload
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
    BHAppIconItem *item = self.sectionedIcons[indexPath.section][indexPath.item];

    // Load image (using existing priority: -settings asset, then plain asset, then bundle files)
    UIImage *img = nil;
    NSString *settingsAsset = [item.bundleIconName stringByAppendingString:@"-settings"];
    img = [UIImage imageNamed:settingsAsset];
    if (!img) img = [UIImage imageNamed:item.bundleIconName];
    if (!img && item.bundleIconFiles.count) {
        // highest-res first
        for (NSString *base in item.bundleIconFiles.reverseObjectEnumerator) {
            img = [UIImage imageNamed:base];
            if (img) break;
        }
    }
    cell.imageView.image = img;

    // Checkmark logic
    NSString *current = [UIApplication sharedApplication].alternateIconName;
    BOOL isActive = current ? [current isEqualToString:item.bundleIconName] : item.isPrimaryIcon;
    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image = [UIImage systemImageNamed:@"circle"];
    }];
    if (isActive) cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
    
    return cell;
}

#pragma mark - Supplementary (Section Headers)

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                            withReuseIdentifier:@"HeaderView"
                                                                                   forIndexPath:indexPath];
    // Remove existing labels
    [header.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    // Only show header for sections >= 2 (seasonal and beyond)
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

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section {
    return (section < 2)
        ? CGSizeZero
        : CGSizeMake(collectionView.bounds.size.width, 30);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(98, 136);
}

@end
