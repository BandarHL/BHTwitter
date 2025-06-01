//  BHCustomTabBarViewController.m
//  NeoFreeBird
//
//  Created by Bandar Alruwaili on 11/12/2023.
//  Modified by actuallyaridan on 31/05/2025.
//

#import "BHCustomTabBarViewController.h"
#import "BHCustomTabBarUtility.h"
#import "../BHTBundle/BHTBundle.h"
#import "Colours/Colours.h"

// Import external function to get theme color
extern UIColor *BHTCurrentAccentColor(void);

// Interface declaration for TFNFloatingActionButton
@interface TFNFloatingActionButton : UIView
- (void)hideAnimated:(_Bool)animated completion:(id)completion;
@end

// UIImage category for TFN vector image methods
@interface UIImage (TFNAdditions)
+ (id)tfn_vectorImageNamed:(id)arg1 fitsSize:(struct CGSize)arg2 fillColor:(id)arg3;
@end

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
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIButton *restoreButton;
@property (nonatomic, strong) NSMutableArray<BHCustomTabBarItem *> *allItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *enabledPageIDs;
@property (nonatomic, assign) BOOL hasChanges;
@property (nonatomic, strong) NSLayoutConstraint *collectionViewHeightConstraint;
@property (nonatomic, strong) NSMutableSet<NSString *> *originalEnabledPageIDs;
@property (nonatomic, strong) UILabel *headerLabel;
@end

@implementation BHCustomTabBarViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Find and hide the floating action button using recursive search
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        [self findAndHideFloatingActionButtonInView:window];
    }
}

- (void)findAndHideFloatingActionButtonInView:(UIView *)view {
    // Direct check for the current view
    if ([view isKindOfClass:NSClassFromString(@"TFNFloatingActionButton")]) {
        [(TFNFloatingActionButton *)view hideAnimated:YES completion:nil];
        return;
    }
    
    // Recursively check subviews
    for (UIView *subview in view.subviews) {
        [self findAndHideFloatingActionButtonInView:subview];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Setup header label
self.headerLabel = [UILabel new];
self.headerLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_NAVIGATION_DETAIL"];
self.headerLabel.font = [TwitterChirpFont(TwitterFontStyleRegular) fontWithSize:13];
self.headerLabel.textColor = [UIColor secondaryLabelColor];
self.headerLabel.numberOfLines = 0;
self.headerLabel.textAlignment = NSTextAlignmentLeft;
self.headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
[self.view addSubview:self.headerLabel];

// Add constraints for header
[NSLayoutConstraint activateConstraints:@[
    [self.headerLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
    [self.headerLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
    [self.headerLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16]
]];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.hasChanges = NO;
    [self setupScrollView];
    [self setupCollectionView];
    [self setupRestoreButton];
    [self loadData];
    [self updateSaveButtonState];
    [self setupSaveButton];
}

#pragma mark - UI Setup

- (void)setupSaveButton {
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"SAVE_BUTTON_TITLE"]
                                                                    style:UIBarButtonItemStyleDone
                                                                   target:self
                                                                   action:@selector(saveButtonTapped)];
    
    // Explicitly set the disabled appearance for better visibility in dark mode
    [saveButton setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor systemGray2Color]} forState:UIControlStateDisabled];
    
    self.navigationItem.rightBarButtonItem = saveButton;
    saveButton.enabled = NO;
}

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    
    [NSLayoutConstraint activateConstraints:@[
[self.scrollView.topAnchor constraintEqualToAnchor:self.headerLabel.bottomAnchor constant:8],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];
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
    [self.contentView addSubview:self.collectionView];

    self.collectionViewHeightConstraint = [self.collectionView.heightAnchor constraintEqualToConstant:100];
    self.collectionViewHeightConstraint.active = YES;
}

- (void)setupRestoreButton {
    self.restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.restoreButton setTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_RESET_BUTTON"] forState:UIControlStateNormal];
    self.restoreButton.titleLabel.font = [TwitterChirpFont(TwitterFontStyleSemibold) fontWithSize:16];
    [self.restoreButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.restoreButton.backgroundColor = [UIColor systemBackgroundColor];
    self.restoreButton.layer.cornerRadius = 26;
    self.restoreButton.layer.borderWidth = 2.0;
    self.restoreButton.layer.borderColor = [UIColor.systemGray6Color resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    self.restoreButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.restoreButton addTarget:self action:@selector(resetSettingsBarButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.restoreButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],

        [self.restoreButton.topAnchor constraintEqualToAnchor:self.collectionView.bottomAnchor constant:20],
        [self.restoreButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.restoreButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.restoreButton.heightAnchor constraintEqualToConstant:52],
        [self.restoreButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-20]
    ]];
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
        self.enabledPageIDs = [NSMutableSet setWithArray:@[@"home", @"guide", @"grok", @"media", @"ntab", @"messages"]];
    }
    
    // Store initial state for comparison later
    self.originalEnabledPageIDs = [self.enabledPageIDs mutableCopy];
    
    [self.collectionView reloadData];
    [self updateCollectionViewHeight];
}

- (void)updateCollectionViewHeight {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat height = self.collectionView.collectionViewLayout.collectionViewContentSize.height;
        self.collectionViewHeightConstraint.constant = height;
    });
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_REQUIRED_ALERT_TITLE"]
                                                                   message:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_REQUIRED_ALERT_MESSAGE_NAVBAR"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_NOW_BUTTON_TITLE"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
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

    self.hasChanges = NO;
    [self updateSaveButtonState];
}

- (void)updateSaveButtonState {
    self.navigationItem.rightBarButtonItem.enabled = self.hasChanges;
}

#pragma mark - Reset Logic

- (void)resetSettingsBarButtonHandler:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@""
                                                                   message:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_RESET_MESSAGE"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"YES_BUTTON_TITLE"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"allowed"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"hidden"];
        [self loadData];
        [self persistChanges];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"NO_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UICollectionView

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView { return 1; }
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { return self.allItems.count; }

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"tabItemCell" forIndexPath:indexPath];
    [cell.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    BHCustomTabBarItem *item = self.allItems[indexPath.item];
    BOOL isEnabled = [self.enabledPageIDs containsObject:item.pageID];
    CGFloat boxSize = cell.contentView.bounds.size.width;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, boxSize, boxSize)];
    UIColor *accentColor = BHTCurrentAccentColor();
    container.layer.cornerRadius = 12;

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        container.backgroundColor = [UIColor colorWithRed:28/255.0 green:32/255.0 blue:35/255.0 alpha:1.0];
        container.layer.borderWidth = isEnabled ? 2 : 0;
        container.layer.borderColor = isEnabled ? accentColor.CGColor : nil;
    } else {
        container.backgroundColor = [UIColor systemBackgroundColor];
        container.layer.borderWidth = 2;
        UIColor *borderColor = isEnabled ? accentColor : [UIColor whiteColor];
        container.layer.borderColor = borderColor.CGColor;
        container.layer.shadowColor = [UIColor blackColor].CGColor;
        container.layer.shadowOffset = CGSizeMake(0, 4);
        container.layer.shadowOpacity = 0.10;
        container.layer.shadowRadius = 12;
        container.layer.masksToBounds = NO;
    }

    [cell.contentView addSubview:container];

    // Use Twitter's internal vector images based on pageID
    NSString *iconName = nil;
    
    // Choose the right icon name based on tab ID and enabled state
    if ([item.pageID isEqualToString:@"home"]) {
        iconName = isEnabled ? @"home" : @"home_stroke";
    } else if ([item.pageID isEqualToString:@"guide"]) {
        iconName = isEnabled ? @"search" : @"search_stroke";
    } else if ([item.pageID isEqualToString:@"audiospace"]) {
        iconName = isEnabled ? @"spaces" : @"spaces_stroke";
    } else if ([item.pageID isEqualToString:@"communities"]) {
        iconName = isEnabled ? @"communities" : @"communities_stroke";
    } else if ([item.pageID isEqualToString:@"ntab"]) {
        iconName = isEnabled ? @"notifications" : @"notifications_stroke";
    } else if ([item.pageID isEqualToString:@"messages"]) {
        iconName = isEnabled ? @"messages" : @"messages_stroke";
    } else if ([item.pageID isEqualToString:@"grok"]) {
        iconName = isEnabled ? @"grok_icon_blackhole" : @"grok_icon_blackhole_stroke";
    } else if ([item.pageID isEqualToString:@"media"]) {
        iconName = isEnabled ? @"media_tab" : @"media_tab_stroke";
    }
    
    // Choose icon color based on light/dark mode, not selection state
    UIColor *iconColor;
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        iconColor = [UIColor whiteColor];
    } else {
        iconColor = [UIColor blackColor];
    }
    
    // Generate vector image with proper color
    UIImage *iconImage = [UIImage tfn_vectorImageNamed:iconName 
                                             fitsSize:CGSizeMake(28, 28) 
                                            fillColor:iconColor];
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:iconImage];
    iconView.frame = CGRectMake(0, 0, 28, 28);
    iconView.center = CGPointMake(container.bounds.size.width / 2, container.bounds.size.height / 2);
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [container addSubview:iconView];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(container.frame) + 8, boxSize, 22)];
    label.text = [[BHTBundle sharedBundle] localizedStringForKey:item.title];
    label.font = [TwitterChirpFont(TwitterFontStyleRegular) fontWithSize:14];
    label.textAlignment = NSTextAlignmentCenter;
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
    
    // Check if current state differs from original state
    self.hasChanges = ![self.enabledPageIDs isEqual:self.originalEnabledPageIDs];
    
    [self updateSaveButtonState];
    
    // Use a faster animation for selection changes
    [UIView animateWithDuration:0.15 animations:^{
        [collectionView performBatchUpdates:^{
            [collectionView reloadItemsAtIndexPaths:@[indexPath]];
        } completion:nil];
    }];
}

@end