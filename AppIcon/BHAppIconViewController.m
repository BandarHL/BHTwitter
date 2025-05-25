//
//  BHAppIconViewController.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//  Revised: merged Default+Custom into “Icons” (no header),
//           special headers driven by your localization keys,
//           including "Other" section.
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

    // Header label
    self.headerLabel = [UILabel new];
    self.headerLabel.text =
      [[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_HEADER_TITLE"];
    self.headerLabel.textColor    = [UIColor secondaryLabelColor];
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.font         = [UIFont systemFontOfSize:15];
    self.headerLabel.textAlignment = NSTextAlignmentJustified;
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // Collection view layout
    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    flow.sectionInset            = UIEdgeInsetsMake(16,16,16,16);
    flow.minimumLineSpacing      = 10;
    flow.minimumInteritemSpacing = 10;

    // Collection view
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
         constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
      [self.headerLabel.leadingAnchor
         constraintEqualToAnchor:self.view.leadingAnchor constant:16],
      [self.headerLabel.trailingAnchor
         constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

      [self.appIconCollectionView.topAnchor
         constraintEqualToAnchor:self.headerLabel.bottomAnchor],
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

    // 1) Flat list of all icons
    NSMutableArray<BHAppIconItem*> *flat = [NSMutableArray new];

    // Primary icon
    NSDictionary *pri = iconsDict[@"CFBundlePrimaryIcon"];
    [flat addObject:
      [[BHAppIconItem alloc]
         initWithBundleIconName:pri[@"CFBundleIconName"]
                  iconFileNames:pri[@"CFBundleIconFiles"]
                   isPrimaryIcon:YES]];

    // Alternate icons
    NSDictionary *alts = iconsDict[@"CFBundleAlternateIcons"];
    [alts enumerateKeysAndObjectsUsingBlock:
      ^(NSString *key, NSDictionary *alt, BOOL *stop) {
        [flat addObject:
          [[BHAppIconItem alloc]
             initWithBundleIconName:alt[@"CFBundleIconName"]
                      iconFileNames:alt[@"CFBundleIconFiles"]
                       isPrimaryIcon:NO]];
    }];

    // 2) Prepare buckets
    NSArray<NSString*> *allCats = @[
      @"Icons",
      @"Seasonal Icons",
      @"Holidays",
      @"Sports",
      @"Pride",
      @"Other"
    ];
    NSMutableDictionary<NSString*,NSMutableArray*> *buckets = [NSMutableDictionary new];
    for (NSString *c in allCats) buckets[c] = [NSMutableArray new];

    NSSet *seasonKeys = [NSSet setWithArray:@[@"Autumn",@"Summer",@"Winter",@"Spring",@"Fall"]];
    NSSet *holidayKeys = [NSSet setWithArray:@[
      @"BlackHistory",@"Holi",@"EarthHour",@"WomansDay",
      @"LunarNewYear",@"StPatricksDay",@"Easter",
      @"Halloween",@"Thanksgiving",@"Christmas",@"NewYears"
    ]];
    NSSet *sportKeys = [NSSet setWithArray:@[
      @"BeijingOlympics",@"FormulaOne",@"Daytona",@"Nba",@"Ncaa"
    ]];

    // 3) Distribute into buckets
    for (BHAppIconItem *item in flat) {
      if (item.isPrimaryIcon ||
          [item.bundleIconName hasPrefix:@"Custom-Icon"]) {
        [buckets[@"Icons"] addObject:item];
        continue;
      }
      BOOL placed = NO;
      for (NSString *k in seasonKeys) {
        if ([item.bundleIconName containsString:k]) {
          [buckets[@"Seasonal Icons"] addObject:item];
          placed = YES; break;
        }
      }
      if (placed) continue;
      for (NSString *k in holidayKeys) {
        if ([item.bundleIconName containsString:k]) {
          [buckets[@"Holidays"] addObject:item];
          placed = YES; break;
        }
      }
      if (placed) continue;
      for (NSString *k in sportKeys) {
        if ([item.bundleIconName containsString:k]) {
          [buckets[@"Sports"] addObject:item];
          placed = YES; break;
        }
      }
      if (placed) continue;
      if ([item.bundleIconName containsString:@"Pride"]) {
        [buckets[@"Pride"] addObject:item];
      } else {
        [buckets[@"Other"] addObject:item];
      }
    }

    // 4) Build section arrays, dropping empty
    NSMutableArray<NSString*> *titles   = [NSMutableArray new];
    NSMutableArray<NSArray*>   *sections = [NSMutableArray new];
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

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)collectionView {
    return self.sectionedIcons.count;
}

- (NSInteger)collectionView:(UICollectionView*)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.sectionedIcons[section].count;
}

- (UICollectionViewCell*)collectionView:(UICollectionView*)collectionView
              cellForItemAtIndexPath:(NSIndexPath*)indexPath {
    BHAppIconCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:
        [BHAppIconCell reuseIdentifier] forIndexPath:indexPath];
    BHAppIconItem *item = self.sectionedIcons[indexPath.section][indexPath.row];

    // Load icon image (settings → catalog → bundle highest-res)
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

    // Checkmark
    NSString *curr = [UIApplication sharedApplication].alternateIconName;
    BOOL active = curr ? [curr isEqualToString:item.bundleIconName] : item.isPrimaryIcon;
    [collectionView.visibleCells enumerateObjectsUsingBlock:
      ^(__kindof UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image =
          [UIImage systemImageNamed:@"circle"];
    }];
    if (active) cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];

    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView*)collectionView
didSelectItemAtIndexPath:(NSIndexPath*)indexPath {
    BHAppIconItem *item = self.sectionedIcons[indexPath.section][indexPath.row];
    [collectionView.visibleCells enumerateObjectsUsingBlock:
      ^(__kindof UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image =
          [UIImage systemImageNamed:@"circle"];
    }];
    BHAppIconCell *cell = (BHAppIconCell*)[collectionView cellForItemAtIndexPath:indexPath];
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

- (UICollectionReusableView*)collectionView:(UICollectionView*)collectionView
               viewForSupplementaryElementOfKind:(NSString*)kind
                                     atIndexPath:(NSIndexPath*)indexPath
{
    UICollectionReusableView *header =
      [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                         withReuseIdentifier:@"HeaderView"
                                                forIndexPath:indexPath];
    [header.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    // First section ("Icons") has no header
    if (indexPath.section == 0) return header;

    // Determine localization key
    NSString *cat   = self.sectionTitles[indexPath.section];
    NSString *locKey;
    if ([cat isEqualToString:@"Seasonal Icons"]) {
      locKey = @"APP_ICON_SEASONS_HEADER_TITLE";
    } else if ([cat isEqualToString:@"Holidays"]) {
      locKey = @"APP_ICON_HOLIDAYS_HEADER_TITLE";
    } else if ([cat isEqualToString:@"Sports"]) {
      locKey = @"APP_ICON_SPORTS_HEADER_TITLE";
    } else if ([cat isEqualToString:@"Pride"]) {
      locKey = @"APP_ICON_PRIDE_HEADER_TITLE";
    } else if ([cat isEqualToString:@"Other"]) {
      locKey = @"APP_ICON_OTHER_HEADER_TITLE";
    } else {
      locKey = nil;
    }

    UILabel *lbl = [UILabel new];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.font      = [UIFont boldSystemFontOfSize:16];
    lbl.textColor = [UIColor labelColor];

    if (locKey) {
      lbl.text = [[BHTBundle sharedBundle] localizedStringForKey:locKey];
    } else {
      lbl.text = cat;
    }

    [header addSubview:lbl];
    [NSLayoutConstraint activateConstraints:@[
      [lbl.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
      [lbl.centerYAnchor constraintEqualToAnchor:header.centerYAnchor]
    ]];
    return header;
}

- (CGSize)collectionView:(UICollectionView*)collectionView
                  layout:(UICollectionViewLayout*)layout
referenceSizeForHeaderInSection:(NSInteger)section
{
    return (section == 0)
      ? CGSizeZero
      : CGSizeMake(collectionView.bounds.size.width, 30);
}

#pragma mark - FlowLayout sizing

- (CGSize)collectionView:(UICollectionView*)collectionView
                  layout:(UICollectionViewLayout*)layout
 sizeForItemAtIndexPath:(NSIndexPath*)indexPath
{
    return CGSizeMake(98,136);
}

@end
