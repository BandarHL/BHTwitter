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
                                                                   action:@selector(saveState)];
    self.navigationItem.rightBarButtonItem = saveButton;

    // Layout
    CGFloat padding = 20;
    CGFloat itemWidth = (self.view.bounds.size.width - padding * 4) / 3; // 3 items per row, 4 paddings

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(itemWidth, itemWidth + 25); // Reduced the height a bit
    layout.minimumInteritemSpacing = padding;
    layout.minimumLineSpacing = padding;
    layout.sectionInset = UIEdgeInsetsMake(padding, padding, padding, padding);

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
    restoreButton.layer.cornerRadius = 22; // Reduced from 26
    restoreButton.contentEdgeInsets = UIEdgeInsetsMake(12, 0, 12, 0);
    restoreButton.translatesAutoresizingMaskIntoConstraints = NO;
    [restoreButton addTarget:self action:@selector(resetSettingsBarButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:restoreButton];

    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [restoreButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [restoreButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [restoreButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [restoreButton.heightAnchor constraintEqualToConstant:48], // Slightly shorter

        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:restoreButton.topAnchor constant:-10]
    ]];
    [self loadData];
}

#pragma mark - Data

- (UIColor *)disabledBorderColorForCurrentMode {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor colorWithRed:0.145 green:0.145 blue:0.145 alpha:1.0]; // Dark gray that's closer to Twitter dark mode
    } else {
        return [UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0]; // Light gray for light mode
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

    // Colors (more Twitter-like)
    UIColor *borderColor = isEnabled ? [UIColor colorWithRed:0.11 green:0.63 blue:0.95 alpha:1.0] : [self disabledBorderColorForCurrentMode]; // Twitter blue for enabled
    UIColor *bgColor = [UIColor systemBackgroundColor];

    CGFloat boxSize = cell.contentView.bounds.size.width;

    // Container
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, boxSize, boxSize)];
    container.layer.cornerRadius = 16; // More like Twitter's rounded corners
    container.layer.borderWidth = 2;
    container.layer.borderColor = borderColor.CGColor;
    container.backgroundColor = bgColor;
    
    // Tag for retrieving later
    container.tag = 100;

    // Shadow - more subtle like Twitter's UI
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOpacity = 0.05;
    container.layer.shadowOffset = CGSizeMake(0, 2);
    container.layer.shadowRadius = 4;
    container.layer.masksToBounds = NO;

    [cell.contentView addSubview:container];

    // Placeholder for icon (center of container)
    UIView *icon = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
    icon.backgroundColor = [UIColor systemGray4Color];
    icon.layer.cornerRadius = 14; // More circular like Twitter icons
    icon.center = CGPointMake(container.bounds.size.width / 2, container.bounds.size.height / 2);
    [container addSubview:icon];

    // Label below container
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(container.frame) + 6, boxSize, 18)];
    label.text = item.title;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]; // Twitter uses medium weight
    label.textColor = isEnabled ? [UIColor labelColor] : [UIColor secondaryLabelColor]; // Dimmer text for disabled
    label.tag = 101; // Tag for retrieving later
    [cell.contentView addSubview:label];

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    BHCustomTabBarItem *item = self.allItems[indexPath.item];
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    
    BOOL wasEnabled = [self.enabledPageIDs containsObject:item.pageID];
    
    if (wasEnabled) {
        [self.enabledPageIDs removeObject:item.pageID];
    } else {
        [self.enabledPageIDs addObject:item.pageID];
    }
    
    // Instant visual feedback
    [self updateCellAppearance:cell isEnabled:!wasEnabled];
    
    // Also save the state
    [self saveState];
}

// Helper method for updating cell appearance instantly
- (void)updateCellAppearance:(UICollectionViewCell *)cell isEnabled:(BOOL)isEnabled {
    UIView *container = [cell.contentView viewWithTag:100];
    UILabel *label = (UILabel *)[cell.contentView viewWithTag:101];
    
    // Update border color with animation
    UIColor *newBorderColor = isEnabled ? [UIColor colorWithRed:0.11 green:0.63 blue:0.95 alpha:1.0] : [self disabledBorderColorForCurrentMode];
    
    // Animate border color change
    CABasicAnimation *borderColorAnimation = [CABasicAnimation animationWithKeyPath:@"borderColor"];
    borderColorAnimation.fromValue = (__bridge id)container.layer.borderColor;
    borderColorAnimation.toValue = (__bridge id)newBorderColor.CGColor;
    borderColorAnimation.duration = 0.15;
    [container.layer addAnimation:borderColorAnimation forKey:@"borderColor"];
    
    // Set the final value
    container.layer.borderColor = newBorderColor.CGColor;
    
    // Update label color
    label.textColor = isEnabled ? [UIColor labelColor] : [UIColor secondaryLabelColor];
}

@end