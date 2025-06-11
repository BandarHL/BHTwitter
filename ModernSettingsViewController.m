#import "ModernSettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "BHDimPalette.h"
#import "SettingsViewController.h"

// Forward declare full interface so compiler knows the class and its init method
@class TFNTwitterAccount;
@interface GeneralSettingsViewController : UIViewController
- (instancetype)initWithAccount:(TFNTwitterAccount *)account;
@end

// Forward declaration for the view-controller implemented later in this file
@class GeneralSettingsViewController;

// Import external function to get theme color
extern UIColor *BHTCurrentAccentColor(void);

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
            @"icon": @"settings_stroke",
            @"action": @"showLayoutSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_TWITTER_BLUE_TITLE"], 
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_TWITTER_BLUE_SUBTITLE"],
            @"icon": @"twitter_blue",
            @"action": @"showTwitterBlueSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_MEDIA_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_MEDIA_SUBTITLE"],
            @"icon": @"media_tab_stroke",
            @"action": @"showDownloadsSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_PROFILES_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_PROFILES_SUBTITLE"],
            @"icon": @"account",
            @"action": @"showProfilesSettings"
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
            @"action": @"showMessagesSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_EXPERIMENTAL_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_EXPERIMENTAL_SUBTITLE"],
            @"icon": @"flask",
            @"action": @"showExperimentalSettings"
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
        titleLabel.font = [fontGroup performSelector:@selector(headline1BoldFont)];
        
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

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    // Add a thin separator under the main settings section to visually divide it from the developer list
    if (section == 0) {
        UIView *separator = [[UIView alloc] initWithFrame:CGRectZero];
        separator.backgroundColor = [UIColor separatorColor];
        return separator;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 0) {
        // 1-pixel line regardless of screen scale
        return 1.0 / UIScreen.mainScreen.scale;
    }
    return CGFLOAT_MIN;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        NSDictionary *sectionData = self.sections[indexPath.row];
        NSString *action = sectionData[@"action"];
        
        if ([action isEqualToString:@"showDownloadsSettings"]) {
            [self showDownloadsSettings];
        } else if ([action isEqualToString:@"showTwitterBlueSettings"]) {
            [self showTwitterBlueSettings];
        } else if ([action isEqualToString:@"showLayoutSettings"]) {
            [self showLayoutSettings];
        } else if ([action isEqualToString:@"showProfilesSettings"]) {
            [self showProfilesSettings];
        } else if ([action isEqualToString:@"showTweetsSettings"]) {
            [self showTweetsSettings];
        } else if ([action isEqualToString:@"showMessagesSettings"]) {
            [self showMessagesSettings];
        } else if ([action isEqualToString:@"showExperimentalSettings"]) {
            [self showExperimentalSettings];
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
    avatarImageView.layer.cornerRadius = 26; // 52x52 image, radius = 26
    avatarImageView.clipsToBounds = YES;
    avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    avatarImageView.tag = 100; // Tag to find it later
    [cell.contentView addSubview:avatarImageView];
    
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.tag = 101;
    nameLabel.adjustsFontForContentSizeCategory = YES;
    [cell.contentView addSubview:nameLabel];
    
    UILabel *usernameLabel = [[UILabel alloc] init];
    usernameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    usernameLabel.tag = 102;
    usernameLabel.adjustsFontForContentSizeCategory = YES;
    [cell.contentView addSubview:usernameLabel];
    
    // Custom chevron image (matches main cells)
    UIImageView *devChevron = [[UIImageView alloc] init];
    devChevron.translatesAutoresizingMaskIntoConstraints = NO;
    devChevron.tag = 103;
    devChevron.contentMode = UIViewContentModeScaleAspectFit;
    [cell.contentView addSubview:devChevron];
    
    // Setup constraints to match HBTwitterCell layout
    [NSLayoutConstraint activateConstraints:@[
        // Avatar constraints
        [avatarImageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:20],
        [avatarImageView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [avatarImageView.widthAnchor constraintEqualToConstant:52],
        [avatarImageView.heightAnchor constraintEqualToConstant:52],
        
        // Name label constraints
        [nameLabel.leadingAnchor constraintEqualToAnchor:avatarImageView.trailingAnchor constant:12],
        [nameLabel.trailingAnchor constraintEqualToAnchor:devChevron.leadingAnchor constant:-12],
        [nameLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:16],
        
        // Username label constraints
        [usernameLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [usernameLabel.trailingAnchor constraintEqualToAnchor:devChevron.leadingAnchor constant:-12],
        [usernameLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2],
        [usernameLabel.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-16],
        
        // Chevron constraints
        [devChevron.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-20],
        [devChevron.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [devChevron.widthAnchor constraintEqualToConstant:18],
        [devChevron.heightAnchor constraintEqualToConstant:18]
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
    
    UIImageView *devChevron = [cell.contentView viewWithTag:103];
    devChevron.image = [UIImage tfn_vectorImageNamed:@"chevron_right" fitsSize:CGSizeMake(18, 18) fillColor:subtitleColor];
    
    // Load avatar image asynchronously
    NSString *avatarURL = developer[@"avatarURL"];
    if (avatarURL.length > 0) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:avatarURL]];
            UIImage *img = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                avatarImageView.image = img ?: [UIImage systemImageNamed:@"person.circle.fill"];
            });
        });
    } else {
        avatarImageView.image = [UIImage systemImageNamed:@"person.circle.fill"];
    }
}

#pragma mark - Placeholder helper

- (UIViewController *)placeholderViewControllerWithTitle:(NSString *)titleKey {
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [BHDimPalette currentBackgroundColor];
    NSString *resolvedTitle = titleKey;
    // If we passed a localization key, resolve via bundle; fall back to the raw string.
    NSString *localized = [[BHTBundle sharedBundle] localizedStringForKey:titleKey];
    if (localized && ![localized isEqualToString:titleKey]) {
        resolvedTitle = localized;
    }
    if (self.account) {
        vc.navigationItem.titleView = [objc_getClass("TFNTitleView") titleViewWithTitle:resolvedTitle subtitle:self.account.displayUsername];
    } else {
        vc.title = resolvedTitle;
    }
    // Show centered placeholder label
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
    label.font = [fontGroup performSelector:@selector(bodyBoldFont)];
    label.text = [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_PLACEHOLDER_TEXT"] ?: @"Nothing to see here.. yet";
    label.textColor = [UIColor secondaryLabelColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    [vc.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],
        [label.leadingAnchor constraintGreaterThanOrEqualToAnchor:vc.view.leadingAnchor constant:20],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:vc.view.trailingAnchor constant:-20]
    ]];
    return vc;
}

#pragma mark - Sub-pages (placeholder)

- (void)showLayoutSettings {
    GeneralSettingsViewController *vc = [[GeneralSettingsViewController alloc] initWithAccount:self.account];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showTwitterBlueSettings {
    UIViewController *vc = [self placeholderViewControllerWithTitle:@"MODERN_SETTINGS_TWITTER_BLUE_TITLE"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showDownloadsSettings {
    UIViewController *vc = [self placeholderViewControllerWithTitle:@"MODERN_SETTINGS_MEDIA_TITLE"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showProfilesSettings {
    UIViewController *vc = [self placeholderViewControllerWithTitle:@"MODERN_SETTINGS_PROFILES_TITLE"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showTweetsSettings {
    UIViewController *vc = [self placeholderViewControllerWithTitle:@"MODERN_SETTINGS_TWEETS_TITLE"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showMessagesSettings {
    UIViewController *vc = [self placeholderViewControllerWithTitle:@"MODERN_SETTINGS_MESSAGES_TITLE"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showExperimentalSettings {
    UIViewController *vc = [self placeholderViewControllerWithTitle:@"MODERN_SETTINGS_EXPERIMENTAL_TITLE"];
    [self.navigationController pushViewController:vc animated:YES];
}

@end

#pragma mark - General Settings Page

@interface GeneralSettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) TFNTwitterAccount *account;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *toggles;
@end

@implementation GeneralSettingsViewController

- (instancetype)initWithAccount:(TFNTwitterAccount *)account {
    if ((self = [super init])) {
        _account = account;
        [self buildToggleList];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [BHDimPalette currentBackgroundColor];
    [self setupNav];
    [self setupTable];
}

- (void)setupNav {
    NSString *title = [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_LAYOUT_TITLE"];
    if (self.account) {
        self.navigationItem.titleView = [objc_getClass("TFNTitleView") titleViewWithTitle:title subtitle:self.account.displayUsername];
    } else {
        self.title = title;
    }
}

- (void)setupTable {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [BHDimPalette currentBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)buildToggleList {
    // Combine switches from Main and Layout sections of classic controller
    _toggles = @[ 
        // Main
        @{ @"key": @"custom_voice_upload", @"titleKey": @"UPLOAD_CUSTOM_VOICE_OPTION_TITLE", @"subtitleKey": @"UPLOAD_CUSTOM_VOICE_OPTION_DETAIL_TITLE", @"default": @YES },
        @{ @"key": @"hide_topics", @"titleKey": @"HIDE_TOPICS_OPTION_TITLE", @"subtitleKey": @"HIDE_TOPICS_OPTION_DETAIL_TITLE", @"default": @NO },
        @{ @"key": @"hide_topics_to_follow", @"titleKey": @"HIDE_TOPICS_TO_FOLLOW_OPTION", @"subtitleKey": @"HIDE_TOPICS_TO_FOLLOW_OPTION_DETAIL_TITLE", @"default": @NO },
        @{ @"key": @"hide_who_to_follow", @"titleKey": @"HIDE_WHO_FOLLOW_OPTION", @"subtitleKey": @"HIDE_WHO_FOLLOW_OPTION_DETAIL_TITLE", @"default": @NO },
        @{ @"key": @"padlock", @"titleKey": @"PADLOCK_OPTION_TITLE", @"subtitleKey": @"PADLOCK_OPTION_DETAIL_TITLE", @"default": @NO },
        @{ @"key": @"openInBrowser", @"titleKey": @"ALWAYS_OPEN_SAFARI_OPTION_TITLE", @"subtitleKey": @"ALWAYS_OPEN_SAFARI_OPTION_DETAIL_TITLE", @"default": @NO },
        @{ @"key": @"strip_tracking_params", @"titleKey": @"STRIP_URL_TRACKING_PARAMETERS_TITLE", @"subtitleKey": @"STRIP_URL_TRACKING_PARAMETERS_DETAIL_TITLE", @"default": @NO },
        @{ @"key": @"enable_translate", @"titleKey": @"ENABLE_TRANSLATE_OPTION_TITLE", @"subtitleKey": @"ENABLE_TRANSLATE_OPTION_DETAIL_TITLE", @"default": @NO },
        // Layout
        @{ @"key": @"hide_spaces", @"titleKey": @"HIDE_SPACE_OPTION_TITLE", @"subtitleKey": @"", @"default": @NO },
        @{ @"key": @"no_tab_bar_hiding", @"titleKey": @"STOP_HIDING_TAB_BAR_TITLE", @"subtitleKey": @"STOP_HIDING_TAB_BAR_TITLE", @"default": @NO },
        @{ @"key": @"tab_bar_theming", @"titleKey": @"CLASSIC_TAB_BAR_SETTINGS_TITLE", @"subtitleKey": @"CLASSIC_TAB_BAR_SETTINGS_DETAIL", @"default": @NO },
        @{ @"key": @"restore_tab_labels", @"titleKey": @"RESTORE_TAB_LABELS_TITLE", @"subtitleKey": @"RESTORE_TAB_LABELS_DETAIL", @"default": @NO },
        @{ @"key": @"dis_rtl", @"titleKey": @"DISABLE_RTL_OPTION_TITLE", @"subtitleKey": @"DISABLE_RTL_OPTION_DETAIL_TITLE", @"default": @NO },
        @{ @"key": @"showScollIndicator", @"titleKey": @"SHOW_SCOLL_INDICATOR_OPTION_TITLE", @"subtitleKey": @"", @"default": @NO }
    ];
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.toggles.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = @"GeneralSwitchCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        // switch control
        UISwitch *sw = [[UISwitch alloc] init];
        sw.tag = 500;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    }
    NSDictionary *toggle = self.toggles[indexPath.row];
    NSString *title = [[BHTBundle sharedBundle] localizedStringForKey:toggle[@"titleKey"]];
    NSString *subtitleKey = toggle[@"subtitleKey"];
    NSString *subtitle = subtitleKey.length ? [[BHTBundle sharedBundle] localizedStringForKey:subtitleKey] : @"";
    cell.textLabel.text = title;
    cell.detailTextLabel.text = subtitle;
    id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
    cell.textLabel.font = [fontGroup performSelector:@selector(bodyBoldFont)];
    cell.detailTextLabel.font = [fontGroup performSelector:@selector(subtext2Font)];
    cell.detailTextLabel.numberOfLines = 0;
    UISwitch *sw = (UISwitch *)cell.accessoryView;
    sw.onTintColor = BHTCurrentAccentColor();
    NSString *key = toggle[@"key"];
    BOOL enabled = [[[NSUserDefaults standardUserDefaults] objectForKey:key] ?: toggle[@"default"] boolValue];
    sw.on = enabled;
    // store key inside switch for callback
    objc_setAssociatedObject(sw, @"prefKey", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return cell;
}

#pragma mark UITableViewDelegate
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [[UILabel alloc] init];
    label.numberOfLines = 0;
    label.text = [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_LAYOUT_SUBTITLE"];
    id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
    label.font = [fontGroup performSelector:@selector(subtext2Font)];
    Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
    id settings = [TAEColorSettingsCls sharedSettings];
    id colorPalette = [[settings currentColorPalette] colorPalette];
    label.textColor = [colorPalette performSelector:@selector(tabBarItemColor)];
    label.textAlignment = NSTextAlignmentLeft;
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [BHDimPalette currentBackgroundColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:16],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-16]
    ]];
    return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return UITableViewAutomaticDimension; }

#pragma mark Switch action
- (void)switchChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, @"prefKey");
    if (key) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end