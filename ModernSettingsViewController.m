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
    
    // Title using Twitter's internal font methods (smaller size)
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
    self.titleLabel.font = [fontGroup performSelector:@selector(subtext1BoldFont)];
    self.titleLabel.textColor = [UIColor labelColor];
    [self.contentView addSubview:self.titleLabel];
    
    // Subtitle using Twitter's internal font methods (smaller size)
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [fontGroup performSelector:@selector(subtext2Font)];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.numberOfLines = 0;
    [self.contentView addSubview:self.subtitleLabel];
    
    // Chevron
    self.chevronImageView = [[UIImageView alloc] init];
    self.chevronImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.chevronImageView.image = [UIImage systemImageNamed:@"chevron.right"];
    self.chevronImageView.tintColor = [UIColor tertiaryLabelColor];
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
        [self.iconImageView.widthAnchor constraintEqualToConstant:24],
        [self.iconImageView.heightAnchor constraintEqualToConstant:24],
        
        // Title constraints
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:16],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.chevronImageView.leadingAnchor constant:-16],
        
        // Subtitle constraints
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16],
        
        // Chevron constraints
        [self.chevronImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.chevronImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.chevronImageView.widthAnchor constraintEqualToConstant:12],
        [self.chevronImageView.heightAnchor constraintEqualToConstant:12]
    ]];
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle iconName:(NSString *)iconName {
    // Set title and subtitle text directly
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
    
    // Set icon
    self.iconImageView.image = [UIImage systemImageNamed:iconName];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    self.backgroundColor = [BHDimPalette currentBackgroundColor];
    
    // Update fonts when text size changes using Twitter's internal methods
    if (previousTraitCollection.preferredContentSizeCategory != self.traitCollection.preferredContentSizeCategory) {
        id fontGroup = [objc_getClass("TAEStandardFontGroup") sharedFontGroup];
        self.titleLabel.font = [fontGroup performSelector:@selector(subtext1BoldFont)];
        self.subtitleLabel.font = [fontGroup performSelector:@selector(subtext2Font)];
    }
}

@end

@interface ModernSettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) TFNTwitterAccount *account;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;
@end

@implementation ModernSettingsViewController

- (instancetype)initWithAccount:(TFNTwitterAccount *)account {
    self = [super init];
    if (self) {
        _account = account;
        [self setupSections];
    }
    return self;
}

- (void)setupSections {
    self.sections = @[
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_DOWNLOADS_MEDIA_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_DOWNLOADS_MEDIA_SUBTITLE"],
            @"icon": @"arrow.down.circle",
            @"action": @"showDownloadsSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_PRIVACY_SAFETY_TITLE"], 
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_PRIVACY_SAFETY_SUBTITLE"],
            @"icon": @"shield",
            @"action": @"showPrivacySettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_INTERFACE_LAYOUT_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_INTERFACE_LAYOUT_SUBTITLE"],
            @"icon": @"paintbrush",
            @"action": @"showInterfaceSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_ADVANCED_FEATURES_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_ADVANCED_FEATURES_SUBTITLE"],
            @"icon": @"gearshape.2",
            @"action": @"showAdvancedSettings"
        },
        @{
            @"title": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_ABOUT_SUPPORT_TITLE"],
            @"subtitle": [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_ABOUT_SUPPORT_SUBTITLE"],
            @"icon": @"info.circle",
            @"action": @"showAboutSettings"
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
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [BHDimPalette currentBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 80;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModernSettingsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsCell" forIndexPath:indexPath];
    
    NSDictionary *sectionData = self.sections[indexPath.row];
    
    [cell configureWithTitle:sectionData[@"title"] 
                    subtitle:sectionData[@"subtitle"] 
                    iconName:sectionData[@"icon"]];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
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