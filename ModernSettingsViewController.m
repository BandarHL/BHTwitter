#import "ModernSettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "BHDimPalette.h"
#import "SettingsViewController.h"

// Import external function to get theme color
extern UIColor *BHTCurrentAccentColor(void);

@interface ModernSettingsTableViewCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) TFNAttributedTextView *titleTextView;
@property (nonatomic, strong) TFNAttributedTextView *subtitleTextView;
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
    
    // Title using Twitter's text view
    self.titleTextView = [[objc_getClass("TFNAttributedTextView") alloc] init];
    self.titleTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.titleTextView];
    
    // Subtitle using Twitter's text view
    self.subtitleTextView = [[objc_getClass("TFNAttributedTextView") alloc] init];
    self.subtitleTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.subtitleTextView];
    
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
        [self.titleTextView.leadingAnchor constraintEqualToAnchor:self.iconImageView.trailingAnchor constant:16],
        [self.titleTextView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [self.titleTextView.trailingAnchor constraintEqualToAnchor:self.chevronImageView.leadingAnchor constant:-16],
        
        // Subtitle constraints
        [self.subtitleTextView.leadingAnchor constraintEqualToAnchor:self.titleTextView.leadingAnchor],
        [self.subtitleTextView.topAnchor constraintEqualToAnchor:self.titleTextView.bottomAnchor constant:4],
        [self.subtitleTextView.trailingAnchor constraintEqualToAnchor:self.titleTextView.trailingAnchor],
        [self.subtitleTextView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16],
        
        // Chevron constraints
        [self.chevronImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.chevronImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.chevronImageView.widthAnchor constraintEqualToConstant:12],
        [self.chevronImageView.heightAnchor constraintEqualToConstant:12]
    ]];
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle iconName:(NSString *)iconName {
    // Configure title with Twitter's font system - using the same fonts as SettingsViewController
    UIFont *titleFont = [[objc_getClass("TAEStandardFontGroup") sharedFontGroup] headline2BoldFont];
    UIFont *subtitleFont = [titleFont fontWithSize:14.0]; // Smaller version of the same font
    
    // Create attributed text for title
    NSAttributedString *titleAttributedString = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSFontAttributeName: titleFont,
        NSForegroundColorAttributeName: [UIColor labelColor]
    }];
    TFNAttributedTextModel *titleTextModel = [[objc_getClass("TFNAttributedTextModel") alloc] initWithAttributedString:titleAttributedString];
    self.titleTextView.textModel = titleTextModel;
    
    // Create attributed text for subtitle
    NSAttributedString *subtitleAttributedString = [[NSAttributedString alloc] initWithString:subtitle attributes:@{
        NSFontAttributeName: subtitleFont,
        NSForegroundColorAttributeName: [UIColor secondaryLabelColor]
    }];
    TFNAttributedTextModel *subtitleTextModel = [[objc_getClass("TFNAttributedTextModel") alloc] initWithAttributedString:subtitleAttributedString];
    self.subtitleTextView.textModel = subtitleTextModel;
    
    // Set icon
    self.iconImageView.image = [UIImage systemImageNamed:iconName];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    self.backgroundColor = [BHDimPalette currentBackgroundColor];
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
            @"title": @"Downloads & Media",
            @"subtitle": @"Video downloads, media settings, and content handling options.",
            @"icon": @"arrow.down.circle",
            @"action": @"showDownloadsSettings"
        },
        @{
            @"title": @"Privacy & Safety", 
            @"subtitle": @"Ad blocking, sensitive content, tracking protection, and security features.",
            @"icon": @"shield",
            @"action": @"showPrivacySettings"
        },
        @{
            @"title": @"Interface & Layout",
            @"subtitle": @"Themes, fonts, tab customization, and visual appearance options.",
            @"icon": @"paintbrush",
            @"action": @"showInterfaceSettings"
        },
        @{
            @"title": @"Advanced Features",
            @"subtitle": @"Translation, confirmations, profile tools, and experimental options.",
            @"icon": @"gearshape.2",
            @"action": @"showAdvancedSettings"
        },
        @{
            @"title": @"About & Support",
            @"subtitle": @"Developers, acknowledgments, version info, and debug options.",
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