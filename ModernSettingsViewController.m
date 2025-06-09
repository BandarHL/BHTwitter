#import "ModernSettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "BHDimPalette.h"

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
#import "SettingsViewController.h"

// Import external function to get theme color
extern UIColor *BHTCurrentAccentColor(void);

@interface ModernSettingsTableViewCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *chevronImageView;
@end

@implementation ModernSettingsTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
        [self setupConstraints];
    }
    return self;
}

- (void)setupViews {
    // Icon
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconImageView.tintColor = [UIColor secondaryLabelColor];
    [self.contentView addSubview:self.iconImageView];
    
    // Title using Twitter's internal font methods (larger size)
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
    self.titleLabel.font = [fontGroup performSelector:@selector(bodyBoldFont)];
    self.titleLabel.textColor = [UIColor labelColor];
    [self.contentView addSubview:self.titleLabel];
    
    // Subtitle using Twitter's internal font methods (original size)
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [fontGroup performSelector:@selector(subtext2Font)];
    [self updateSubtitleColor];
    self.subtitleLabel.numberOfLines = 0;
    [self.contentView addSubview:self.subtitleLabel];
    
    // Chevron
    self.chevronImageView = [[UIImageView alloc] init];
    self.chevronImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.chevronImageView];
    
    // Cell appearance
    self.backgroundColor = [BHDimPalette currentBackgroundColor];
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Icon constraints
        [self.iconImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.iconImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.iconImageView.widthAnchor constraintEqualToConstant:20],
        [self.iconImageView.heightAnchor constraintEqualToConstant:20],
        
        // Title constraints
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:16],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.chevronImageView.leadingAnchor constant:-16],
        
        // Subtitle constraints
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:2],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16],
        
        // Chevron constraints
        [self.chevronImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.chevronImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.chevronImageView.widthAnchor constraintEqualToConstant:18],
        [self.chevronImageView.heightAnchor constraintEqualToConstant:18]
    ]];
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle iconName:(NSString *)iconName {
    // Set title and subtitle text directly
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
    
    // Store icon name for theme updates
    objc_setAssociatedObject(self, @selector(iconName), iconName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Set icon using Twitter's internal vector system with proper dynamic color
    [self updateIconColors];
}

- (void)updateIconColors {
    NSString *iconName = objc_getAssociatedObject(self, @selector(iconName));
    if (iconName) {
        // Get Twitter's color palette properly
        Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
        id settings = [TAEColorSettingsCls sharedSettings];
        id currentPalette = [settings currentColorPalette];
        id colorPalette = [currentPalette colorPalette];
        
        // Use Twitter's tab bar item color for icons
        UIColor *iconColor = [colorPalette performSelector:@selector(tabBarItemColor)];
        self.iconImageView.image = [UIImage tfn_vectorImageNamed:iconName fitsSize:CGSizeMake(20, 20) fillColor:iconColor];
    }
    
    // Update chevron color using Twitter's tab bar item color  
    Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
    id settings = [TAEColorSettingsCls sharedSettings];
    id currentPalette = [settings currentColorPalette];
    id colorPalette = [currentPalette colorPalette];
    
    UIColor *chevronColor = [colorPalette performSelector:@selector(tabBarItemColor)];
    self.chevronImageView.image = [UIImage tfn_vectorImageNamed:@"chevron_right" fitsSize:CGSizeMake(18, 18) fillColor:chevronColor];
}

- (void)updateSubtitleColor {
    // Get Twitter's color palette properly
    Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
    id settings = [TAEColorSettingsCls sharedSettings];
    id currentPalette = [settings currentColorPalette];
    id colorPalette = [currentPalette colorPalette];
    
    // Use Twitter's tab bar item color for subtitles (same as icons)
    UIColor *subtitleColor = [colorPalette performSelector:@selector(tabBarItemColor)];
    self.subtitleLabel.textColor = subtitleColor;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    self.backgroundColor = [BHDimPalette currentBackgroundColor];
    
    // Update icon colors when appearance changes
    [self updateIconColors];
    
    // Update subtitle color when appearance changes
    [self updateSubtitleColor];
    
    // Update fonts when text size changes using Twitter's internal methods
    if (previousTraitCollection.preferredContentSizeCategory != self.traitCollection.preferredContentSizeCategory) {
        id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
        self.titleLabel.font = [fontGroup performSelector:@selector(bodyBoldFont)];
        self.subtitleLabel.font = [fontGroup performSelector:@selector(subtext2Font)];
    }
}

@end

@interface ModernSettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) TFNTwitterAccount *account;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *developerCells;
@end

@implementation ModernSettingsViewController

- (instancetype)initWithAccount:(TFNTwitterAccount *)account {
    self = [super init];
    if (self) {
        _account = account;
        [self setupSections];
        [self setupDeveloperCells];
    }
    return self;
}

- (void)setupSections {
    self.sections = @[
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_LAYOUT_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_LAYOUT_SUBTITLE"],
            @"icon": @"cards",
            @"action": @"showInterfaceSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_TWITTER_BLUE_TITLE"], 
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_TWITTER_BLUE_SUBTITLE"],
            @"icon": @"twitter_blue_stroke",
            @"action": @"showPrivacySettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_MEDIA_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_MEDIA_SUBTITLE"],
            @"icon": @"media_tab_v2_stroke",
            @"action": @"showDownloadsSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_PROFILES_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_PROFILES_SUBTITLE"],
            @"icon": @"person_stroke",
            @"action": @"showAdvancedSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_TWEETS_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_TWEETS_SUBTITLE"],
            @"icon": @"quill",
            @"action": @"showTweetsSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_MESSAGES_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_MESSAGES_SUBTITLE"],
            @"icon": @"messages_stroke",
            @"action": @"showAboutSettings"
        }
    ];
}

- (void)setupDeveloperCells {
    self.developerCells = @[
        @{
            @"title": @"aridan",
            @"username": @"actuallyaridan",
            @"avatarURL": @"https://unavatar.io/x/actuallyaridan",
            @"userID": @"1351218086649720837"
        },
        @{
            @"title": @"timi2506",
            @"username": @"timi2506", 
            @"avatarURL": @"https://unavatar.io/x/timi2506",
            @"userID": @"1671731225424195584"
        },
        @{
            @"title": @"nyathea",
            @"username": @"nyaathea",
            @"avatarURL": @"https://unavatar.io/x/nyaathea", 
            @"userID": @"1541742676009226241"
        },
        @{
            @"title": @"BandarHelal",
            @"username": @"BandarHL",
            @"avatarURL": @"https://unavatar.io/x/BandarHL",
            @"userID": @"827842200708853762"
        },
        @{
            @"title": @"NeoFreeBird",
            @"username": @"NeoFreeBird", 
            @"avatarURL": @"https://unavatar.io/x/NeoFreeBird",
            @"userID": @"1878595268255297537"
        }
    ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationBar];
    [self setupTableView];
    [self setupLayout];
    
    // Listen for Dynamic Type changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentSizeCategoryDidChange:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)contentSizeCategoryDidChange:(NSNotification *)notification {
    [self.tableView reloadData];
}

- (void)setupNavigationBar {
    self.view.backgroundColor = [BHDimPalette currentBackgroundColor];
    
    // Use Twitter's title view if account is available
    if (self.account) {
        self.navigationItem.titleView = [objc_getClass("TFNTitleView") titleViewWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_TITLE"] subtitle:self.account.displayUsername];
    } else {
        self.title = [[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_TITLE"];
    }
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [BHDimPalette currentBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 80;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedSectionHeaderHeight = 50;
    self.tableView.sectionHeaderHeight = UITableViewAutomaticDimension;
    
    [self.tableView registerClass:[ModernSettingsTableViewCell class] forCellReuseIdentifier:@"SettingsCell"];
    [self.view addSubview:self.tableView];
}

- (void)setupLayout {
    [NSLayoutConstraint activateConstraints:@[
        // Table view
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    self.view.backgroundColor = [BHDimPalette currentBackgroundColor];
    self.tableView.backgroundColor = [BHDimPalette currentBackgroundColor];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // Main sections + Developer section
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.sections.count;
    } else {
        return self.developerCells.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        ModernSettingsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsCell" forIndexPath:indexPath];
        
        NSDictionary *sectionData = self.sections[indexPath.row];
        
        [cell configureWithTitle:sectionData[@"title"] 
                        subtitle:sectionData[@"subtitle"] 
                        iconName:sectionData[@"icon"]];
        
        return cell;
    } else {
        // Developer cell - create custom HBTwitterCell-style layout
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DeveloperCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DeveloperCell"];
            [self setupDeveloperCell:cell];
        }
        
        NSDictionary *developer = self.developerCells[indexPath.row];
        [self configureDeveloperCell:cell withDeveloper:developer];
        
        return cell;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        // Top subtitle header
        UIView *headerView = [[UIView alloc] init];
        headerView.backgroundColor = [BHDimPalette currentBackgroundColor];
        
        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        subtitleLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_DETAIL"];
        subtitleLabel.numberOfLines = 0;
        subtitleLabel.textAlignment = NSTextAlignmentLeft;
        
        // Use Twitter fonts and colors
        id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
        subtitleLabel.font = [fontGroup performSelector:@selector(subtext2Font)];
        
        // Get Twitter's color palette for subtitle color
        Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
        id settings = [TAEColorSettingsCls sharedSettings];
        id currentPalette = [settings currentColorPalette];
        id colorPalette = [currentPalette colorPalette];
        UIColor *subtitleColor = [colorPalette performSelector:@selector(tabBarItemColor)];
        subtitleLabel.textColor = subtitleColor;
        
        [headerView addSubview:subtitleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [subtitleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:20],
            [subtitleLabel.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-20],
            [subtitleLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:16],
            [subtitleLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-16]
        ]];
        
        return headerView;
    } else if (section == 1) {
        // Developer section header
        UIView *headerView = [[UIView alloc] init];
        headerView.backgroundColor = [BHDimPalette currentBackgroundColor];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"DEVELOPER_SECTION_HEADER_TITLE"];
        
        // Use Twitter fonts and colors
        id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
        titleLabel.font = [fontGroup performSelector:@selector(headline2BoldFont)];
        
        // Get Twitter's color palette for text color
        Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
        id settings = [TAEColorSettingsCls sharedSettings];
        id currentPalette = [settings currentColorPalette];
        id colorPalette = [currentPalette colorPalette];
        UIColor *titleColor = [colorPalette performSelector:@selector(textColor)];
        titleLabel.textColor = titleColor;
        
        [headerView addSubview:titleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:20],
            [titleLabel.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-20],
            [titleLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:32],
            [titleLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-16]
        ]];
        
        return headerView;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return UITableViewAutomaticDimension;
    } else if (section == 1) {
        return UITableViewAutomaticDimension;
    }
    return 0;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        NSDictionary *sectionData = self.sections[indexPath.row];
        NSString *action = sectionData[@"action"];
        
        if ([action isEqualToString:@"showDownloadsSettings"]) {
            [self showDownloadsSettings];
        } else if ([action isEqualToString:@"showPrivacySettings"]) {
            [self showPrivacySettings];
        } else if ([action isEqualToString:@"showInterfaceSettings"]) {
            [self showInterfaceSettings];
        } else if ([action isEqualToString:@"showAdvancedSettings"]) {
            [self showAdvancedSettings];
        } else if ([action isEqualToString:@"showAboutSettings"]) {
            [self showAboutSettings];
        }
    } else if (indexPath.section == 1) {
        // Developer cell selected
        NSDictionary *developer = self.developerCells[indexPath.row];
        NSString *userID = developer[@"userID"];
        NSString *twitterURL = [NSString stringWithFormat:@"twitter://user?id=%@", userID];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:twitterURL] options:@{} completionHandler:nil];
    }
}

#pragma mark - Developer Cell Setup

- (void)setupDeveloperCell:(UITableViewCell *)cell {
    // Remove default subviews
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    cell.imageView.image = nil;
    
    // Create custom layout matching HBTwitterCell
    UIImageView *avatarImageView = [[UIImageView alloc] init];
    avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarImageView.layer.cornerRadius = 28; // 56x56 image, so radius = 28
    avatarImageView.clipsToBounds = YES;
    avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    avatarImageView.tag = 100; // Tag to find it later
    [cell.contentView addSubview:avatarImageView];
    
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.tag = 101;
    [cell.contentView addSubview:nameLabel];
    
    UILabel *usernameLabel = [[UILabel alloc] init];
    usernameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    usernameLabel.tag = 102;
    [cell.contentView addSubview:usernameLabel];
    
    // Setup constraints to match HBTwitterCell layout
    [NSLayoutConstraint activateConstraints:@[
        // Avatar constraints
        [avatarImageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:20],
        [avatarImageView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [avatarImageView.widthAnchor constraintEqualToConstant:56],
        [avatarImageView.heightAnchor constraintEqualToConstant:56],
        
        // Name label constraints
        [nameLabel.leadingAnchor constraintEqualToAnchor:avatarImageView.trailingAnchor constant:12],
        [nameLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-20],
        [nameLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:16],
        
        // Username label constraints
        [usernameLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [usernameLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],
        [usernameLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2],
        [usernameLabel.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-16]
    ]];
    
    // Set cell properties
    cell.backgroundColor = [BHDimPalette currentBackgroundColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (void)configureDeveloperCell:(UITableViewCell *)cell withDeveloper:(NSDictionary *)developer {
    // Get subviews by tag
    UIImageView *avatarImageView = [cell.contentView viewWithTag:100];
    UILabel *nameLabel = [cell.contentView viewWithTag:101];
    UILabel *usernameLabel = [cell.contentView viewWithTag:102];
    
    // Configure fonts and colors
    id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
    Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
    id settings = [TAEColorSettingsCls sharedSettings];
    id currentPalette = [settings currentColorPalette];
    id colorPalette = [currentPalette colorPalette];
    UIColor *textColor = [colorPalette performSelector:@selector(textColor)];
    UIColor *subtitleColor = [colorPalette performSelector:@selector(tabBarItemColor)];
    
    // Set text content and styling
    nameLabel.text = developer[@"title"];
    nameLabel.font = [fontGroup performSelector:@selector(bodyBoldFont)];
    nameLabel.textColor = textColor;
    
    usernameLabel.text = [NSString stringWithFormat:@"@%@", developer[@"username"]];
    usernameLabel.font = [fontGroup performSelector:@selector(subtext2Font)];
    usernameLabel.textColor = subtitleColor;
    
    // Load profile image asynchronously
    NSString *avatarURL = developer[@"avatarURL"];
    if (avatarURL) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:avatarURL]];
            UIImage *image = [UIImage imageWithData:imageData];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (image) {
                    avatarImageView.image = image;
                } else {
                    // Fallback to person icon if image fails to load
                    avatarImageView.image = [UIImage systemImageNamed:@"person.circle.fill"];
                    avatarImageView.tintColor = subtitleColor;
                }
            });
        });
    } else {
        // Fallback icon
        avatarImageView.image = [UIImage systemImageNamed:@"person.circle.fill"];
        avatarImageView.tintColor = subtitleColor;
    }
}

#pragma mark - Navigation Methods

- (void)showDownloadsSettings {
    // Create a filtered settings view with download-related options
    SettingsViewController *settingsVC = [[SettingsViewController alloc] initWithTwitterAccount:self.account];
    // TODO: Filter to show only download/media related settings
    [self.navigationController pushViewController:settingsVC animated:YES];
}

- (void)showPrivacySettings {
    // Create a filtered settings view with privacy-related options
    SettingsViewController *settingsVC = [[SettingsViewController alloc] initWithTwitterAccount:self.account];
    // TODO: Filter to show only privacy/safety related settings
    [self.navigationController pushViewController:settingsVC animated:YES];
}

- (void)showInterfaceSettings {
    // Create a filtered settings view with interface-related options
    SettingsViewController *settingsVC = [[SettingsViewController alloc] initWithTwitterAccount:self.account];
    // TODO: Filter to show only interface/theme related settings
    [self.navigationController pushViewController:settingsVC animated:YES];
}

- (void)showAdvancedSettings {
    // Create a filtered settings view with advanced options
    SettingsViewController *settingsVC = [[SettingsViewController alloc] initWithTwitterAccount:self.account];
    // TODO: Filter to show only advanced/experimental settings
    [self.navigationController pushViewController:settingsVC animated:YES];
}

- (void)showAboutSettings {
    // Create a filtered settings view with about/developer info
    SettingsViewController *settingsVC = [[SettingsViewController alloc] initWithTwitterAccount:self.account];
    // TODO: Filter to show only about/developer/debug settings
    [self.navigationController pushViewController:settingsVC animated:YES];
}

@end