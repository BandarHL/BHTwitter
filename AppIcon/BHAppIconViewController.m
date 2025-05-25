//
//  BHAppIconViewController.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//  Revised: added localized detail subtitles under category headers.
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
@property (nonatomic, strong) UICollectionView     *appIconCollectionView;
@property (nonatomic, strong) UILabel              *headerLabel;
@property (nonatomic, copy)   NSArray<NSString *>  *sectionTitles;
@property (nonatomic, copy)   NSArray<NSArray<BHAppIconItem *> *> *sectionedIcons;
@end

@implementation BHAppIconViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Navigation title
    self.navigationItem.title =
      [[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_NAV_TITLE"];

    // Description label
    self.headerLabel = [UILabel new];
    self.headerLabel.text =
      [[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_HEADER_TITLE"];
    self.headerLabel.textColor    = [UIColor secondaryLabelColor];
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.font         = [UIFont systemFontOfSize:15];
    self.headerLabel.textAlignment = NSTextAlignmentLeft;
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // Collection view setup
    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    flow.sectionInset            = UIEdgeInsetsMake(16,16,16,16);
    flow.minimumLineSpacing      = 10;
    flow.minimumInteritemSpacing = 10;

    self.appIconCollectionView = [[UICollectionView alloc]
        initWithFrame:CGRectZero
  collectionViewLayout:flow];
    self.appIconCollectionView.contentInsetAdjustmentBehavior =
      UIScrollViewContentInsetAdjustmentAlways;
    [self.appIconCollectionView
      registerClass:[BHAppIconCell class]
      forCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier]];
    [self.appIconCollectionView
      registerClass:[UICollectionReusableView class]
      forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
      withReuseIdentifier:@"HeaderView"];
    self.appIconCollectionView.delegate   = self;
    self.appIconCollectionView.dataSource = self;
    self.appIconCollectionView.translatesAutoresizingMaskIntoConstraints = NO;

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.headerLabel];
    [self.view addSubview:self.appIconCollectionView];

    [NSLayoutConstraint activateConstraints:@[
      [self.headerLabel.topAnchor
         constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
      [self.headerLabel.leadingAnchor
         constraintEqualToAnchor:self.view.leadingAnchor constant:16],
      [self.headerLabel.trailingAnchor
         constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

      [self.appIconCollectionView.topAnchor
         constraintEqualToAnchor:self.headerLabel.bottomAnchor constant:8],
      [self.appIconCollectionView.leadingAnchor
         constraintEqualToAnchor:self.view.leadingAnchor],
      [self.appIconCollectionView.trailingAnchor
         constraintEqualToAnchor:self.view.trailingAnchor],
      [self.appIconCollectionView.bottomAnchor
         constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self setupAppIcons];
}

- (void)setupAppIcons {
    NSDictionary *iconsDict =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];

    // Build flat list
    NSMutableArray<BHAppIconItem*> *flat = [NSMutableArray new];
    NSDictionary *pri = iconsDict[@"CFBundlePrimaryIcon"];
    [flat addObject:
      [[BHAppIconItem alloc]
         initWithBundleIconName:pri[@"CFBundleIconName"]
                  iconFileNames:pri[@"CFBundleIconFiles"]
                   isPrimaryIcon:YES]];
    NSDictionary *alts = iconsDict[@"CFBundleAlternateIcons"];
    [alts enumerateKeysAndObjectsUsingBlock:
      ^(NSString *key, NSDictionary *alt, BOOL *stop) {
        [flat addObject:
          [[BHAppIconItem alloc]
             initWithBundleIconName:alt[@"CFBundleIconName"]
                      iconFileNames:alt[@"CFBundleIconFiles"]
                       isPrimaryIcon:NO]];
    }];

    // Categories
    NSArray<NSString*> *allCats = @[
      @"Icons", @"Seasonal Icons", @"Holidays", @"Sports", @"Pride", @"Other"
    ];
    NSMutableDictionary *buckets = [NSMutableDictionary new];
    for (NSString *c in allCats) buckets[c] = [NSMutableArray new];

    NSSet *seasonKeys = [NSSet setWithArray:@[@"Autumn",@"Summer",@"Winter",@"Spring",@"Fall"]];
    NSSet *holidayKeys = [NSSet setWithArray:@[
      @"BlackHistory",@"Holi",@"EarthHour",@"WomansDay",
      @"LunarNewYear",@"StPatricksDay",@"Christmas",@"NewYears"
    ]];
    NSSet *sportKeys = [NSSet setWithArray:@[
      @"BeijingOlympics",@"FormulaOne",@"Daytona",@"Nba",@"Ncaa"
    ]];

    for (BHAppIconItem *item in flat) {
      if (item.isPrimaryIcon ||
          [item.bundleIconName hasPrefix:@"Custom-Icon"]) {
        [buckets[@"Icons"] addObject:item];
        continue;
      }
      BOOL placed = NO;
      for (NSString *k in seasonKeys) {
        if ([item.bundleIconName containsString:k]) {
          [buckets[@"Seasonal Icons"] addObject:item]; placed=YES; break;
        }
      }
      if (placed) continue;
      for (NSString *k in holidayKeys) {
        if ([item.bundleIconName containsString:k]) {
          [buckets[@"Holidays"] addObject:item]; placed=YES; break;
        }
      }
      if (placed) continue;
      for (NSString *k in sportKeys) {
        if ([item.bundleIconName containsString:k]) {
          [buckets[@"Sports"] addObject:item]; placed=YES; break;
        }
      }
      if (placed) continue;
      if ([item.bundleIconName containsString:@"Pride"]) {
        [buckets[@"Pride"] addObject:item];
      } else {
        [buckets[@"Other"] addObject:item];
      }
    }

    NSMutableArray *titles   = [NSMutableArray new];
    NSMutableArray *sections = [NSMutableArray new];
    for (NSString *cat in allCats) {
      NSArray *arr = buckets[cat];
      if (arr.count > 0) {
        [titles addObject:cat];
        [sections addObject:arr];
      }
    }
    self.sectionTitles  = titles;
    self.sectionedIcons = sections;
    [self.appIconCollectionView reloadData];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)cv {
    return self.sectionedIcons.count;
}
- (NSInteger)collectionView:(UICollectionView*)cv
     numberOfItemsInSection:(NSInteger)section {
    return self.sectionedIcons[section].count;
}
- (UICollectionViewCell*)collectionView:(UICollectionView*)cv
              cellForItemAtIndexPath:(NSIndexPath*)ip {
    BHAppIconCell *cell = [cv dequeueReusableCellWithReuseIdentifier:
        [BHAppIconCell reuseIdentifier] forIndexPath:ip];
    BHAppIconItem *item = self.sectionedIcons[ip.section][ip.row];

    // image loading (settings → catalog → bundle)
    NSString *settings;
    if (item.isPrimaryIcon) {
      NSString *nm = item.bundleIconName;
      if ([nm hasSuffix:@"AppIcon"]) {
        nm = [nm substringToIndex:nm.length-@"AppIcon".length];
      }
      settings = [NSString stringWithFormat:@"Icon-%@-settings", nm];
    } else {
      settings = [item.bundleIconName stringByAppendingString:@"-settings"];
    }
    UIImage *img = [UIImage imageNamed:settings] ?: [UIImage imageNamed:item.bundleIconName];
    if (!img) {
      for (NSString *base in item.bundleIconFiles.reverseObjectEnumerator) {
        img = [UIImage imageNamed:base];
        if (img) break;
      }
    }
    cell.imageView.image = img;

    // checkmark
    NSString *curr = [UIApplication sharedApplication].alternateIconName;
    BOOL active = curr ? [curr isEqualToString:item.bundleIconName] : item.isPrimaryIcon;
    [cv.visibleCells enumerateObjectsUsingBlock:
      ^(__kindof UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image =
          [UIImage systemImageNamed:@"circle"];
    }];
    if (active) cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView*)cv
didSelectItemAtIndexPath:(NSIndexPath*)ip {
    BHAppIconItem *item = self.sectionedIcons[ip.section][ip.row];
    [cv.visibleCells enumerateObjectsUsingBlock:
      ^(__kindof UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image =
          [UIImage systemImageNamed:@"circle"];
    }];
    BHAppIconCell *cell = (BHAppIconCell*)[cv cellForItemAtIndexPath:ip];
    NSString *toSet = item.isPrimaryIcon ? nil : item.bundleIconName;
    [[UIApplication sharedApplication]
       setAlternateIconName:toSet
            completionHandler:^(NSError *_Nullable error) {
      if (!error) {
        cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
      }
    }];
}

#pragma mark - Section Headers

- (UICollectionReusableView*)collectionView:(UICollectionView*)cv
               viewForSupplementaryElementOfKind:(NSString*)kind
                                     atIndexPath:(NSIndexPath*)ip
{
    UICollectionReusableView *header =
      [cv dequeueReusableSupplementaryViewOfKind:kind
                             withReuseIdentifier:@"HeaderView"
                                    forIndexPath:ip];
    // remove any old subviews
    [header.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    // First section ("Icons") has no header
    if (ip.section == 0) return header;

    // Determine localization keys for title & detail
    NSString *cat   = self.sectionTitles[ip.section];
    NSString *titleKey;
    NSString *detailKey;
    if ([cat isEqualToString:@"Seasonal Icons"]) {
      titleKey  = @"APP_ICON_SEASONS_HEADER_TITLE";
      detailKey = @"APP_ICON_SEASONS_HEADER_DETAIL";
    } else if ([cat isEqualToString:@"Holidays"]) {
      titleKey  = @"APP_ICON_HOLIDAYS_HEADER_TITLE";
      detailKey = @"APP_ICON_HOLIDAYS_HEADER_DETAIL";
    } else if ([cat isEqualToString:@"Sports"]) {
      titleKey  = @"APP_ICON_SPORTS_HEADER_TITLE";
      detailKey = @"APP_ICON_SPORTS_HEADER_DETAIL";
    } else if ([cat isEqualToString:@"Pride"]) {
      titleKey  = @"APP_ICON_PRIDE_HEADER_TITLE";
      detailKey = @"APP_ICON_PRIDE_HEADER_DETAIL";
    } else if ([cat isEqualToString:@"Other"]) {
      titleKey  = @"APP_ICON_OTHER_HEADER_TITLE";
      detailKey = nil;
    }

    // Title label
    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font      = [UIFont boldSystemFontOfSize:16];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.text      = [[BHTBundle sharedBundle] localizedStringForKey:titleKey];
    [header addSubview:titleLabel];

    // Detail label (if provided)
    UILabel *detailLabel = nil;
    if (detailKey) {
      detailLabel = [UILabel new];
      detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
      detailLabel.font          = [UIFont systemFontOfSize:13];
      detailLabel.textColor     = [UIColor secondaryLabelColor];
      detailLabel.numberOfLines = 0;
      detailLabel.textAlignment = NSTextAlignmentLeft;
      detailLabel.text          = [[BHTBundle sharedBundle] localizedStringForKey:detailKey];
      [header addSubview:detailLabel];
    }

    // Constraints
    NSMutableArray<NSLayoutConstraint*> *cons = [NSMutableArray new];
    [cons addObjectsFromArray:@[
      [titleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
      [titleLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:8],
      [titleLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
    ]];
    if (detailLabel) {
      [cons addObjectsFromArray:@[
        [detailLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [detailLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
      ]];
    }
    [NSLayoutConstraint activateConstraints:cons];

    return header;
}

- (CGSize)collectionView:(UICollectionView*)cv
                  layout:(UICollectionViewLayout*)layout
referenceSizeForHeaderInSection:(NSInteger)section
{
    // Section 0: no header
    if (section == 0) return CGSizeZero;

    // If detail exists (sections 1–4), taller header; Other no detail → shorter
    NSString *cat = self.sectionTitles[section];
    BOOL hasDetail = [cat isEqualToString:@"Seasonal Icons"]
                  || [cat isEqualToString:@"Holidays"]
                  || [cat isEqualToString:@"Sports"]
                  || [cat isEqualToString:@"Pride"];
    CGFloat height = hasDetail ? 60 : 30;
    return CGSizeMake(cv.bounds.size.width, height);
}

#pragma mark - FlowLayout sizing

- (CGSize)collectionView:(UICollectionView*)cv
                  layout:(UICollectionViewLayout*)layout
 sizeForItemAtIndexPath:(NSIndexPath*)ip
{
    return CGSizeMake(98,136);
}

@end
