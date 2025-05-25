//
//  BHAppIconViewController.m
//  NeoFreeBird
//
//  Created by Bandar Alruwaili on 10/12/2023.
//  Modified by actuallyaridan on 25/05/2025.
//

#import "BHAppIconViewController.h"
#import "BHAppIconItem.h"
#import "BHAppIconCell.h"
#import "../BHTBundle/BHTBundle.h"
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TwitterFontStyle) {
    TwitterFontStyleRegular,
    TwitterFontStyleSemibold,
    TwitterFontStyleBold
};

static UIFont *TwitterChirpFont(TwitterFontStyle style) {
    switch (style) {
        case TwitterFontStyleBold:
            return [UIFont fontWithName:@"ChirpUIVF_wght3200000_opsz150000" size:17] ?:
                   [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
        case TwitterFontStyleSemibold:
            return [UIFont fontWithName:@"ChirpUIVF_wght2BC0000_opszE0000" size:14] ?:
                   [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        case TwitterFontStyleRegular:
        default:
            return [UIFont fontWithName:@"ChirpUIVF_wght1900000_opszE0000" size:12] ?:
                   [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    }
}

@interface BHAppIconViewController () <
    UICollectionViewDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout
>
@property (nonatomic, strong) UICollectionView     *appIconCollectionView;
@property (nonatomic, copy)   NSArray<NSString *>  *sectionTitles;
@property (nonatomic, copy)   NSArray<NSArray<BHAppIconItem *> *> *sectionedIcons;
@end

@implementation BHAppIconViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.title =
      [[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_NAV_TITLE"];

    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    flow.sectionInset            = UIEdgeInsetsMake(16,16,16,16);
    flow.minimumLineSpacing      = 10;
    flow.minimumInteritemSpacing = 10;

    self.appIconCollectionView = [[UICollectionView alloc]
        initWithFrame:CGRectZero
  collectionViewLayout:flow];
    self.appIconCollectionView.contentInsetAdjustmentBehavior =
      UIScrollViewContentInsetAdjustmentAlways;
    [self.appIconCollectionView registerClass:[BHAppIconCell class]
                      forCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier]];
    [self.appIconCollectionView registerClass:[UICollectionReusableView class]
                forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                       withReuseIdentifier:@"HeaderView"];
    self.appIconCollectionView.delegate   = self;
    self.appIconCollectionView.dataSource = self;
    self.appIconCollectionView.translatesAutoresizingMaskIntoConstraints = NO;

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.appIconCollectionView];

    [NSLayoutConstraint activateConstraints:@[
      [self.appIconCollectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
      [self.appIconCollectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
      [self.appIconCollectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
      [self.appIconCollectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self setupAppIcons];
}

- (void)setupAppIcons {
    NSDictionary *iconsDict =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];
    NSMutableArray<BHAppIconItem*> *flat = [NSMutableArray new];

    NSDictionary *pri = iconsDict[@"CFBundlePrimaryIcon"];
    [flat addObject:[[BHAppIconItem alloc]
         initWithBundleIconName:pri[@"CFBundleIconName"]
                  iconFileNames:pri[@"CFBundleIconFiles"]
                   isPrimaryIcon:YES]];

    NSDictionary *alts = iconsDict[@"CFBundleAlternateIcons"];
    [alts enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *alt, BOOL *stop) {
        [flat addObject:[[BHAppIconItem alloc]
           initWithBundleIconName:alt[@"CFBundleIconName"]
                    iconFileNames:alt[@"CFBundleIconFiles"]
                     isPrimaryIcon:NO]];
    }];

    NSArray<NSString*> *allCats = @[@"Icons", @"Seasonal Icons", @"Holidays", @"Sports", @"Pride", @"Other"];
    NSMutableDictionary *buckets = [NSMutableDictionary new];
    for (NSString *c in allCats) buckets[c] = [NSMutableArray new];

    NSSet *seasonKeys = [NSSet setWithArray:@[@"Autumn",@"Summer",@"Winter",@"Spring",@"Fall"]];
    NSSet *holidayKeys = [NSSet setWithArray:@[@"BlackHistory",@"Holi",@"EarthHour",@"WomansDay",@"LunarNewYear",@"StPatricksDay",@"Christmas",@"NewYears",@"Halloween",@"Thanksgiving",@"ValentinesDay",@"Ramadan",@"Easter",@"Eid",@"Anzac",@"Diwali",@"MayTheFouth",@"MothersDay"]];
    NSSet *sportKeys = [NSSet setWithArray:@[@"BeijingOlympics",@"FormulaOne",@"Daytona",@"Nba",@"Ncaa",@"Masters",@"Nfl",@"Nhl",@"UefaChampionsLeague",@"WorldCup",@"Wimbledon",@"WorldSeries",@"SuperBowl",@"Olympics",@"KentuckyDerby",@"Rugby",@"Cricket",@"Tennis",@"Golf",@"Baseball",@"Football",@"Soccer",@"Basketball",@"Hockey",@"Mlb"]];

    for (BHAppIconItem *item in flat) {
      if (item.isPrimaryIcon || [item.bundleIconName hasPrefix:@"Custom-Icon"]) {
        [buckets[@"Icons"] addObject:item]; continue;
      }
      BOOL placed = NO;
      for (NSString *k in seasonKeys) {
        if ([item.bundleIconName containsString:k]) {
          [buckets[@"Seasonal Icons"] addObject:item]; placed = YES; break;
        }
      }
      if (placed) continue;
      for (NSString *k in holidayKeys) {
        if ([item.bundleIconName containsString:k]) {
          [buckets[@"Holidays"] addObject:item]; placed = YES; break;
        }
      }
      if (placed) continue;
      for (NSString *k in sportKeys) {
        if ([item.bundleIconName containsString:k]) {
          [buckets[@"Sports"] addObject:item]; placed = YES; break;
        }
      }
      if (placed) continue;
      if ([item.bundleIconName containsString:@"Pride"]) {
        [buckets[@"Pride"] addObject:item];
      } else {
        [buckets[@"Other"] addObject:item];
      }
    }

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

#pragma mark – UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)cv {
    return self.sectionedIcons.count;
}

- (NSInteger)collectionView:(UICollectionView*)cv numberOfItemsInSection:(NSInteger)section {
    return self.sectionedIcons[section].count;
}

- (UICollectionViewCell*)collectionView:(UICollectionView*)cv cellForItemAtIndexPath:(NSIndexPath*)ip {
    BHAppIconCell *cell = [cv dequeueReusableCellWithReuseIdentifier:[BHAppIconCell reuseIdentifier] forIndexPath:ip];
    BHAppIconItem *item = self.sectionedIcons[ip.section][ip.row];

    // Determine settings asset name
    NSString *settings;
    if (item.isPrimaryIcon) {
      NSString *nm = item.bundleIconName;
      if ([nm hasSuffix:@"AppIcon"]) nm = [nm substringToIndex:nm.length - @"AppIcon".length];
      settings = [NSString stringWithFormat:@"Icon-%@-settings", nm];
    } else {
      settings = [item.bundleIconName stringByAppendingString:@"-settings"];
    }

    // Load the highest-resolution image available
    NSBundle *iconBundle = [NSBundle mainBundle];
    // If your icons are packaged in BHTBundle, use:
    // iconBundle = [BHTBundle sharedBundle].bundle;
    UITraitCollection *tc = self.traitCollection;

    UIImage *img = [UIImage imageNamed:settings inBundle:iconBundle compatibleWithTraitCollection:tc];
    if (!img) {
      img = [UIImage imageNamed:item.bundleIconName inBundle:iconBundle compatibleWithTraitCollection:tc];
    }
    if (!img) {
      for (NSString *base in [item.bundleIconFiles reverseObjectEnumerator]) {
        img = [UIImage imageNamed:base inBundle:iconBundle compatibleWithTraitCollection:tc];
        if (img) break;
      }
    }
    cell.imageView.image = img;

    // Update checkmark state
    NSString *curr = [UIApplication sharedApplication].alternateIconName;
    BOOL active = curr ? [curr isEqualToString:item.bundleIconName] : item.isPrimaryIcon;
    [cv.visibleCells enumerateObjectsUsingBlock:^(UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image = [UIImage systemImageNamed:@"circle"];
    }];
    if (active) {
      cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
    }
    return cell;
}

#pragma mark – UICollectionViewDelegate

- (void)collectionView:(UICollectionView*)cv didSelectItemAtIndexPath:(NSIndexPath*)ip {
    BHAppIconItem *item = self.sectionedIcons[ip.section][ip.row];
    [cv.visibleCells enumerateObjectsUsingBlock:^(UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHAppIconCell*)c).checkIMG.image = [UIImage systemImageNamed:@"circle"];
    }];
    BHAppIconCell *cell = (BHAppIconCell*)[cv cellForItemAtIndexPath:ip];
    NSString *toSet = item.isPrimaryIcon ? nil : item.bundleIconName;
    [[UIApplication sharedApplication] setAlternateIconName:toSet completionHandler:^(NSError *_Nullable error) {
      if (!error) {
        cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
      }
    }];
}

#pragma mark – Section Headers

- (UICollectionReusableView*)collectionView:(UICollectionView*)cv viewForSupplementaryElementOfKind:(NSString*)kind atIndexPath:(NSIndexPath*)ip {
    UICollectionReusableView *header = [cv dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"HeaderView" forIndexPath:ip];
    [header.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    if (ip.section == 0) {
        UILabel *detail = [UILabel new];
        detail.translatesAutoresizingMaskIntoConstraints = NO;
        detail.font = [TwitterChirpFont(TwitterFontStyleRegular) fontWithSize:13];
        detail.textColor = [UIColor secondaryLabelColor];
        detail.numberOfLines = 0;
        detail.textAlignment = NSTextAlignmentLeft;
        detail.text = [[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_HEADER_TITLE"];
        [header addSubview:detail];
        [NSLayoutConstraint activateConstraints:@[
          [detail.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
          [detail.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
          [detail.topAnchor constraintEqualToAnchor:header.topAnchor constant:8],
          [detail.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8]
        ]];
        return header;
    }

    NSString *cat = self.sectionTitles[ip.section];
    NSString *titleKey, *detailKey;
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

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font      = [TwitterChirpFont(TwitterFontStyleBold) fontWithSize:16];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.text      = [[BHTBundle sharedBundle] localizedStringForKey:titleKey];
    [header addSubview:titleLabel];

    UILabel *detailLabel = nil;
    if (detailKey) {
      detailLabel = [UILabel new];
      detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
      detailLabel.font          = [TwitterChirpFont(TwitterFontStyleRegular) fontWithSize:13];
      detailLabel.textColor     = [UIColor secondaryLabelColor];
      detailLabel.numberOfLines = 0;
      detailLabel.textAlignment = NSTextAlignmentLeft;
      detailLabel.text          = [[BHTBundle sharedBundle] localizedStringForKey:detailKey];
      [header addSubview:detailLabel];
    }

    NSMutableArray *cons = [NSMutableArray new];
    [cons addObjectsFromArray:@[
      [titleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
      [titleLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
      [titleLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:8],
    ]];
    if (detailLabel) {
      [cons addObjectsFromArray:@[
        [detailLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [detailLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
      ]];
    }
    [NSLayoutConstraint activateConstraints:cons];
    return header;
}

- (CGSize)collectionView:(UICollectionView*)cv layout:(UICollectionViewLayout*)layout referenceSizeForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return CGSizeMake(cv.bounds.size.width, 60);
    }
    NSString *cat = self.sectionTitles[section];
    BOOL hasDetail = [cat isEqualToString:@"Seasonal Icons"] ||
                     [cat isEqualToString:@"Holidays"]       ||
                     [cat isEqualToString:@"Sports"]         ||
                     [cat isEqualToString:@"Pride"];
    return CGSizeMake(cv.bounds.size.width, hasDetail ? 60 : 30);
}

#pragma mark – FlowLayout sizing

- (CGSize)collectionView:(UICollectionView*)cv layout:(UICollectionViewLayout*)layout sizeForItemAtIndexPath:(NSIndexPath*)indexPath {
    return CGSizeMake(98,136);
}

@end
