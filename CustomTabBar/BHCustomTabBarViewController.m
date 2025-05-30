//
//  BHCustomTabBarViewController.m
//  NeoFeeBird
//
//  Created by Bandar Alruwaili on 11/12/2023.
//  Finalized by actuallyaridan on 30/05/2025.
//

#import "BHCustomTabBarViewController.h"
#import "BHCustomTabBarUtility.h"
#import "../BHTBundle/BHTBundle.h"
#import "Colours/Colours.h"
#import "../TWHeaders.h" // Import for BHTCurrentAccentColor()

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

@interface BHCustomTabBarViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<BHCustomTabBarItem *> *allItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *enabledPageIDs;
@property (nonatomic, assign) BOOL hasChanges;
@property (nonatomic, strong) UIButton *restoreButton;
@end

@implementation BHCustomTabBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.hasChanges = NO;
    [self setupNavigationBar];
    [self setupCollectionView];
    [self setupRestoreButton];
    [self loadData];
    [self updateSaveButtonState];
}

#pragma mark - UI Setup

- (void)setupNavigationBar {
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:@"Save"
                                                                    style:UIBarButtonItemStyleDone
                                                                   target:self
                                                                   action:@selector(saveConfigurationAndDismiss)];
                                                                   action:@selector(saveButtonTapped)];
    self.navigationItem.rightBarButtonItem = saveButton;
    saveButton.enabled = NO;
}

- (void)setupCollectionView {
    CGFloat padding = 20 * 2 + 20 * 2;
    CGFloat itemWidth = (self.view.bounds.size.width - padding) / 3;

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(itemWidth, itemWidth + 30);
    layout.minimumInteritemSpacing = 20;
    layout.minimumLineSpacing = 20;
    layout.sectionInset = UIEdgeInsetsMake(20, 20, 20, 20);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor systemBackgroundColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"tabItemCell"];
    [self.view addSubview:self.collectionView];
}

- (void)setupRestoreButton {
    self.restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.restoreButton setTitle:@"Restore to default" forState:UIControlStateNormal];
    self.restoreButton.titleLabel.font = [TwitterChirpFont(TwitterFontStyleSemibold) fontWithSize:16];
    [self.restoreButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.restoreButton.backgroundColor = [UIColor systemBackgroundColor];
    self.restoreButton.layer.cornerRadius = 26;
    self.restoreButton.layer.borderWidth = 1.0;
    self.restoreButton.layer.borderColor = [UIColor.systemGray6Color resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    self.restoreButton.contentEdgeInsets = UIEdgeInsetsMake(12, 0, 12, 0);
    self.restoreButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.restoreButton addTarget:self action:@selector(resetSettingsBarButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.restoreButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.restoreButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [self.restoreButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.restoreButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.restoreButton.heightAnchor constraintEqualToConstant:52],

        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.restoreButton.topAnchor constant:-10]
    ]];
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
#pragma mark - Data Loading

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
            [[BHCustomTabBarItem alloc] initWithTitle:@"CUSTOM_TAB_BAR_HOME" pageID:@"home"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"CUSTOM_TAB_BAR_EXPLORE" pageID:@"guide"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"CUSTOM_TAB_BAR_SPACES" pageID:@"audiospace"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"CUSTOM_TAB_BAR_COMMUNITIES" pageID:@"communities"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"CUSTOM_TAB_BAR_NOTIFICATIONS" pageID:@"ntab"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"CUSTOM_TAB_BAR_MESSAGES" pageID:@"messages"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"CUSTOM_TAB_BAR_GROK" pageID:@"grok"],
            [[BHCustomTabBarItem alloc] initWithTitle:@"CUSTOM_TAB_BAR_VIDEO" pageID:@"media"]
        ] mutableCopy];
        self.enabledPageIDs = [NSMutableSet setWithArray:@[@"home", @"guide", @"audiospace", @"communities"]];
    }
    // Ensure "home" is always enabled
    [self.enabledPageIDs addObject:@"home"];

    [self.collectionView reloadData];
}

- (NSArray<BHCustomTabBarItem *> *)getItemsForKey:(NSString *)key {
    NSData *savedItems = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (savedItems) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:savedItems];
    }
    return nil;
}

#pragma mark - Save Logic

- (void)saveButtonTapped {
    [self persistChanges];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restart required"
                                                                   message:@"You need to restart Twitter for your custom tab bar to take affect"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Not now" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Restart now" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)persistChanges {
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

    self.hasChanges = NO;
    [self updateSaveButtonState];
}

- (void)updateSaveButtonState {
    self.navigationItem.rightBarButtonItem.enabled = self.hasChanges;
}

#pragma mark - Reset Logic

- (void)resetSettingsBarButtonHandler:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BHTwitter"
                                                                   message:@"Reset tab bar layout to default?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"allowed"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"hidden"];
        [self loadData];
        [self persistChanges];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Trait Collection

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self.collectionView reloadData];
    self.restoreButton.layer.borderColor = [UIColor.systemGray6Color resolvedColorWithTraitCollection:self.traitCollection].CGColor;
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
    [cell.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

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

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, boxSize, boxSize)];
    container.layer.cornerRadius = 16;
    container.layer.borderWidth = 1.5; // Thinner border
    container.layer.borderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    container.backgroundColor = cellBackgroundColor;
    
    // Shadow effect
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.3 : 0.15;
    container.layer.shadowOffset = CGSizeMake(0, 2);
    container.layer.shadowRadius = 4;
    container.layer.masksToBounds = NO;
    container.layer.cornerRadius = 12;

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        container.backgroundColor = [UIColor colorWithRed:28/255.0 green:32/255.0 blue:35/255.0 alpha:1.0];
        container.layer.borderWidth = isEnabled ? 2 : 0;
        if (isEnabled) container.layer.borderColor = [UIColor systemBlueColor].CGColor;
        container.layer.shadowOpacity = 0;
    } else {
        container.backgroundColor = [UIColor systemBackgroundColor];
        container.layer.borderWidth = 2;
        UIColor *borderColor = isEnabled ? [UIColor systemBlueColor] : [UIColor whiteColor];
        container.layer.borderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
        container.layer.shadowColor = [UIColor blackColor].CGColor;
        container.layer.shadowOffset = CGSizeMake(0, 4);
        container.layer.shadowOpacity = 0.10;
        container.layer.shadowRadius = 12;
        container.layer.masksToBounds = NO;
    }

    [cell.contentView addSubview:container];

    UIView *icon = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
    icon.backgroundColor = [UIColor systemGray4Color];
    icon.layer.cornerRadius = 6;
    icon.center = CGPointMake(container.bounds.size.width / 2, container.bounds.size.height / 2);
    [container addSubview:icon];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(container.frame) + 8, boxSize, 22)];
    label.text = [[BHTBundle sharedBundle] localizedStringForKey:item.title];
    label.font = [TwitterChirpFont(TwitterFontStyleRegular) fontWithSize:14];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    label.textColor = [UIColor labelColor];
    [cell.contentView addSubview:label];

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    BHCustomTabBarItem *item = self.allItems[indexPath.item];

    // Prevent deselection of "home" item
    if ([item.pageID isEqualToString:@"home"]) {
        return;
    }

    if ([self.enabledPageIDs containsObject:item.pageID]) {
        // Item is currently enabled, so disable it (deselect)
        [self.enabledPageIDs removeObject:item.pageID];
    } else {
        // Item is currently disabled, try to enable it (select)
        // Prevent selecting more than 6 items (home + 5 others)
        if (self.enabledPageIDs.count >= 6) {
            // Optional: Provide feedback to the user that limit is reached
            // For now, just prevent selection
            return;
        }
        [self.enabledPageIDs addObject:item.pageID];
    }

    // [self saveState]; // Removed: Do not save on every selection change

    // Reload without animation
    [UIView performWithoutAnimation:^{
        [collectionView reloadItemsAtIndexPaths:@[indexPath]];
    }];
    self.hasChanges = YES;
    [self updateSaveButtonState];
    [collectionView reloadItemsAtIndexPaths:@[indexPath]];
}

@end