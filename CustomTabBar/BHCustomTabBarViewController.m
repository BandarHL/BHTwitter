//
//  BHCustomTabBarViewController.m
//  NeoFeeBird
//
//  Created by Bandar Alruwaili on 11/12/2023.
//  Modified by actuallyaridan on 30/05/2025.
//

#import "BHCustomTabBarViewController.h"
#import "BHCustomTabBarUtility.h"
#import "../BHTBundle/BHTBundle.h"
#import "Colours/Colours.h"
#import "../TWHeaders.h" // Import for BHTCurrentAccentColor()

@interface BHCustomTabBarViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<BHCustomTabBarItem *> *allItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *enabledPageIDs;
@end

@implementation BHCustomTabBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // Save button in nav bar
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:@"Save"
                                                                    style:UIBarButtonItemStyleDone
                                                                   target:self
                                                                   action:@selector(saveConfigurationAndDismiss)];
    self.navigationItem.rightBarButtonItem = saveButton;

    // Layout
CGFloat padding = 20 * 2 + 20 * 2; // section inset + 2 gaps
CGFloat itemWidth = (self.view.bounds.size.width - padding) / 3;

UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
layout.itemSize = CGSizeMake(itemWidth, itemWidth + 30); // 30 for label height
layout.minimumInteritemSpacing = 20;
layout.minimumLineSpacing = 20;
layout.sectionInset = UIEdgeInsetsMake(20, 20, 20, 20);

    // Collection view setup
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor systemBackgroundColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"tabItemCell"];
    [self.view addSubview:self.collectionView];

    // Restore button
UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
[restoreButton setTitle:@"Restore to default" forState:UIControlStateNormal];
restoreButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
[restoreButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
restoreButton.backgroundColor = [UIColor systemGray6Color];
restoreButton.layer.cornerRadius = 26;
restoreButton.contentEdgeInsets = UIEdgeInsetsMake(12, 0, 12, 0);
restoreButton.translatesAutoresizingMaskIntoConstraints = NO;
[restoreButton addTarget:self action:@selector(resetSettingsBarButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
[self.view addSubview:restoreButton];

    // Layout constraints
[NSLayoutConstraint activateConstraints:@[
    [restoreButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
    [restoreButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
    [restoreButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
    [restoreButton.heightAnchor constraintEqualToConstant:52],

    [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [self.collectionView.bottomAnchor constraintEqualToAnchor:restoreButton.topAnchor constant:-10]
]];
    [self loadData];
}

#pragma mark - Data

- (UIColor *)disabledBorderColorForCurrentMode {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor colorWithWhite:0.2 alpha:1.0]; // Darker gray for dark mode
    } else {
        return [UIColor colorWithWhite:0.85 alpha:1.0]; // Lighter gray for light mode
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self.collectionView reloadData];
}

- (void)loadData {
    NSArray<BHCustomTabBarItem *> *savedAllowed = [self getItemsForKey:@"allowed"];
    NSArray<BHCustomTabBarItem *> *savedHidden = [self getItemsForKey:@"hidden"];

    if (savedAllowed && savedHidden) {
        self.allItems = [[savedAllowed arrayByAddingObjectsFromArray:savedHidden] mutableCopy];
        self.enabledPageIDs = [NSMutableSet set];
        for (BHCustomTabBarItem *item in savedAllowed) {
            [self.enabledPageIDs addObject:item.pageID];
        }
    } else {
        self.allItems = [@[
            [[BHCustomTabBarItem alloc] initWithTitle:@"Home" pageID:@"home"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"Guide" pageID:@"guide"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"Spaces" pageID:@"audiospace"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"Communities" pageID:@"communities"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"NTAB" pageID:@"ntab"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"Messages" pageID:@"messages"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"Grok" pageID:@"grok"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"Media" pageID:@"media"]
        ] mutableCopy];
        self.enabledPageIDs = [NSMutableSet setWithArray:@[@"home", @"guide", @"audiospace", @"communities"]];
    }

    [self.collectionView reloadData];
}

- (NSArray<BHCustomTabBarItem *> *)getItemsForKey:(NSString *)key {
    NSData *savedItems = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (savedItems) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:savedItems];
    }
    return nil;
}

- (void)saveState {
    NSMutableArray *enabledItems = [NSMutableArray array];
    NSMutableArray *disabledItems = [NSMutableArray array];

    for (BHCustomTabBarItem *item in self.allItems) {
        if ([self.enabledPageIDs containsObject:item.pageID]) {
            [enabledItems addObject:item];
        } else {
            [disabledItems addObject:item];
        }
    }

    NSData *enabledData = [NSKeyedArchiver archivedDataWithRootObject:enabledItems];
    NSData *disabledData = [NSKeyedArchiver archivedDataWithRootObject:disabledItems];

    [[NSUserDefaults standardUserDefaults] setObject:enabledData forKey:@"allowed"];
    [[NSUserDefaults standardUserDefaults] setObject:disabledData forKey:@"hidden"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveConfigurationAndDismiss {
    [self saveState];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)resetSettingsBarButtonHandler:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BHTwitter"
                                                                   message:@"Reset tab bar layout to default?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"allowed"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"hidden"];
        [self loadData];
        [self saveState];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UICollectionView

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.allItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"tabItemCell" forIndexPath:indexPath];

    for (UIView *view in cell.contentView.subviews) {
        [view removeFromSuperview];
    }

    BHCustomTabBarItem *item = self.allItems[indexPath.item];
    BOOL isEnabled = [self.enabledPageIDs containsObject:item.pageID];

    // Border colors
    UIColor *borderColor;
    if (isEnabled) {
        borderColor = BHTCurrentAccentColor(); // Use BHTwitter theme accent color
    } else {
        borderColor = [self disabledBorderColorForCurrentMode];
    }
    
    UIColor *cellBackgroundColor;
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        cellBackgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.13 alpha:1.0]; // Twitter dark cell bg
    } else {
        cellBackgroundColor = [UIColor systemGray6Color]; // Light gray for light mode
    }

    CGFloat boxSize = cell.contentView.bounds.size.width;

    // Container
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, boxSize, boxSize)];
    container.layer.cornerRadius = 16; // More rounded corners
    container.layer.borderWidth = 2.5; // Slightly thicker border
    container.layer.borderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    container.backgroundColor = cellBackgroundColor;
    container.layer.masksToBounds = NO; // masksToBounds should be YES if you don't want shadow, but screenshot has none.

    [cell.contentView addSubview:container];

    // Label below container
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(container.frame) + 2, boxSize, 20)];
    label.text = item.title;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    label.textColor = [UIColor labelColor];
    [cell.contentView addSubview:label];

    return cell;
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    BHCustomTabBarItem *item = self.allItems[indexPath.item];

    if ([self.enabledPageIDs containsObject:item.pageID]) {
        [self.enabledPageIDs removeObject:item.pageID];
    } else {
        [self.enabledPageIDs addObject:item.pageID];
    }

    // Reload without animation
    [UIView performWithoutAnimation:^{
        [collectionView reloadItemsAtIndexPaths:@[indexPath]];
    }];
}

@end