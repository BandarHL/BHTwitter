#import "ModernSettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "BHDimPalette.h"

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
    
    // Title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentView addSubview:self.titleLabel];
    
    // Subtitle
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.numberOfLines = 0;
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
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

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    self.backgroundColor = [BHDimPalette currentBackgroundColor];
}

@end

@interface ModernSettingsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) TFNTwitterAccount *account;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
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
            @"title": @"Your account",
            @"subtitle": @"See information about your account, download an archive of your data, or learn about your account deactivation options.",
            @"icon": @"person.circle",
            @"action": @"showAccountSettings"
        },
        @{
            @"title": @"Security and account access", 
            @"subtitle": @"Manage your account's security and keep track of your account's usage including apps that you have connected to your account.",
            @"icon": @"lock.shield",
            @"action": @"showSecuritySettings"
        },
        @{
            @"title": @"Monetization",
            @"subtitle": @"See how you can make money on Twitter and manage your monetization options.",
            @"icon": @"dollarsign.circle",
            @"action": @"showMonetizationSettings"
        },
        @{
            @"title": @"Twitter Blue",
            @"subtitle": @"Manage your subscription features including Undo Tweet timing.",
            @"icon": @"checkmark.seal",
            @"action": @"showTwitterBlueSettings"
        },
        @{
            @"title": @"Privacy and safety",
            @"subtitle": @"Manage what information you see and share on Twitter.",
            @"icon": @"shield",
            @"action": @"showPrivacySettings"
        },
        @{
            @"title": @"Notifications",
            @"subtitle": @"Select the kinds of notifications you get about your activities, interests, and recommendations.",
            @"icon": @"bell",
            @"action": @"showNotificationSettings"
        },
        @{
            @"title": @"Accessibility, display, and languages",
            @"subtitle": @"Manage how Twitter content is displayed to you.",
            @"icon": @"accessibility",
            @"action": @"showDisplaySettings"
        }
    ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationBar];
    [self setupTableView];
    [self setupSearchBar];
    [self setupLayout];
}

- (void)setupNavigationBar {
    self.title = @"Settings";
    self.view.backgroundColor = [BHDimPalette currentBackgroundColor];
    
    // Use Twitter's title view if account is available
    if (self.account) {
        self.navigationItem.titleView = [objc_getClass("TFNTitleView") titleViewWithTitle:@"Settings" subtitle:self.account.displayUsername];
    }
}

- (void)setupSearchBar {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search settings";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.backgroundColor = [BHDimPalette currentBackgroundColor];
    [self.view addSubview:self.searchBar];
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
        // Search bar
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        // Table view
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    self.view.backgroundColor = [BHDimPalette currentBackgroundColor];
    self.tableView.backgroundColor = [BHDimPalette currentBackgroundColor];
    self.searchBar.backgroundColor = [BHDimPalette currentBackgroundColor];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModernSettingsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsCell" forIndexPath:indexPath];
    
    NSDictionary *sectionData = self.sections[indexPath.row];
    
    cell.titleLabel.text = sectionData[@"title"];
    cell.subtitleLabel.text = sectionData[@"subtitle"];
    cell.iconImageView.image = [UIImage systemImageNamed:sectionData[@"icon"]];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *sectionData = self.sections[indexPath.row];
    NSString *action = sectionData[@"action"];
    
    if ([action isEqualToString:@"showAccountSettings"]) {
        [self showAccountSettings];
    } else if ([action isEqualToString:@"showSecuritySettings"]) {
        [self showSecuritySettings];
    } else if ([action isEqualToString:@"showMonetizationSettings"]) {
        [self showMonetizationSettings];
    } else if ([action isEqualToString:@"showTwitterBlueSettings"]) {
        [self showTwitterBlueSettings];
    } else if ([action isEqualToString:@"showPrivacySettings"]) {
        [self showPrivacySettings];
    } else if ([action isEqualToString:@"showNotificationSettings"]) {
        [self showNotificationSettings];
    } else if ([action isEqualToString:@"showDisplaySettings"]) {
        [self showDisplaySettings];
    }
}

#pragma mark - Navigation Methods (Placeholder implementations)

- (void)showAccountSettings {
    // TODO: Implement account settings
    NSLog(@"Show Account Settings");
}

- (void)showSecuritySettings {
    // TODO: Implement security settings  
    NSLog(@"Show Security Settings");
}

- (void)showMonetizationSettings {
    // TODO: Implement monetization settings
    NSLog(@"Show Monetization Settings");
}

- (void)showTwitterBlueSettings {
    // TODO: Implement Twitter Blue settings
    NSLog(@"Show Twitter Blue Settings");
}

- (void)showPrivacySettings {
    // TODO: Implement privacy settings
    NSLog(@"Show Privacy Settings");
}

- (void)showNotificationSettings {
    // TODO: Implement notification settings
    NSLog(@"Show Notification Settings");
}

- (void)showDisplaySettings {
    // TODO: Implement display settings
    NSLog(@"Show Display Settings");
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    // TODO: Implement search functionality
}

@end