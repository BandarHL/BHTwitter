//
//  SettingsViewController.m
//  NeoFreeBird
//
//  Created by BandarHelal
//  Modified by actuallyaridan & nyaathea
//


#import "SettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "Colours/Colours.h"
#import "AppIcon/BHAppIconViewController.h"
#import "ThemeColor/BHColorThemeViewController.h"
#import "CustomTabBar/BHCustomTabBarViewController.h"
#import "BHTManager.h"

typedef NS_ENUM(NSInteger, TwitterFontWeight) {
    TwitterFontWeightRegular,
    TwitterFontWeightMedium,
    TwitterFontWeightSemibold,
    TwitterFontWeightBold
};

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
@interface SettingsViewController () <UIFontPickerViewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) TFNTwitterAccount *twAccount;
@property (nonatomic, assign) BOOL hasDynamicSpecifiers;
@property (nonatomic, retain) NSMutableDictionary *dynamicSpecifiers;
@end

@implementation SettingsViewController

#pragma mark - UITableView Setup
- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupAppearance];
    }
    return self;
}
- (instancetype)initWithTwitterAccount:(TFNTwitterAccount *)account {
    self = [super init];
    if (self) {
        self.twAccount = account;
        [self setupAppearance];
        [self.navigationController.navigationBar setPrefersLargeTitles:false];
        [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"bh_color_theme_selectedColor" options:NSKeyValueObservingOptionNew context:nil];
        [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"T1ColorSettingsPrimaryColorOptionKey" options:NSKeyValueObservingOptionNew context:nil];
        // [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"tab_bar_theming"]; // Ensure it's removed if previously added
    }
    return self;
}
- (void)dealloc {
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"bh_color_theme_selectedColor"];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"T1ColorSettingsPrimaryColorOptionKey"];
    // [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"tab_bar_theming"]; // Ensure it's removed
}

- (void)setupAppearance {
    TAEColorSettings *colorSettings = [objc_getClass("TAEColorSettings") sharedSettings];
    UIColor *primaryColor;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        primaryColor = [[[colorSettings currentColorPalette] colorPalette] primaryColorForOption:[[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"]];
    } else if ([[NSUserDefaults standardUserDefaults] objectForKey:@"T1ColorSettingsPrimaryColorOptionKey"]) {
        primaryColor = [[[colorSettings currentColorPalette] colorPalette] primaryColorForOption:[[NSUserDefaults standardUserDefaults] integerForKey:@"T1ColorSettingsPrimaryColorOptionKey"]];
    } else {
        primaryColor = nil;
    }
    
    HBAppearanceSettings *appearanceSettings = [[HBAppearanceSettings alloc] init];
    appearanceSettings.tintColor = primaryColor;
    appearanceSettings.largeTitleStyle = HBAppearanceSettingsLargeTitleStyleNever;
    }

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"bh_color_theme_selectedColor"] || [keyPath isEqualToString:@"T1ColorSettingsPrimaryColorOptionKey"]) {
        [self setupAppearance];
    }
    // Removed tab_bar_theming observation and BHTTabBarThemingChanged notification
}


// Add this method to configure the table view appearance
- (void)viewDidLoad {
    if (self.twAccount != nil) {
        self.navigationItem.titleView = [objc_getClass("TFNTitleView") titleViewWithTitle:[[BHTBundle sharedBundle]
                               localizedStringForKey:@"BHTWITTER_SETTINGS_TITLE"] subtitle:self.twAccount.displayUsername];
    } else {
        self.title = [[BHTBundle sharedBundle]
                               localizedStringForKey:@"BHTWITTER_SETTINGS_TITLE"];
    }

    [super viewDidLoad];


    
    
    // Set the background color to match system background
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Configure the table view to blend with background
    self.table.backgroundColor = [UIColor systemBackgroundColor];
    self.table.separatorColor = [UIColor separatorColor];
    
    // Remove extra separators below content
    self.table.tableFooterView = [UIView new];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;

    if (@available(iOS 15.0, *)) {
        self.table.sectionHeaderTopPadding = 8; 
    }
    
    // These ensure cells align with headers
    self.table.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
    self.table.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 16);


}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 40)];

        UILabel *detail = [UILabel new];
        detail.translatesAutoresizingMaskIntoConstraints = NO;
        detail.font = [TwitterChirpFont(TwitterFontStyleRegular) fontWithSize:12];
        detail.textColor = [UIColor secondaryLabelColor];
        detail.numberOfLines = 0;
        detail.textAlignment = NSTextAlignmentLeft;
        detail.text = [[BHTBundle sharedBundle] localizedStringForKey:@"BHTWITTER_SETTINGS_DETAIL"];

        [header addSubview:detail];
[NSLayoutConstraint activateConstraints:@[
    [detail.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
    [detail.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
    [detail.topAnchor constraintEqualToAnchor:header.topAnchor constant: 0],
    [detail.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8]
]];


        return header;
    }
    NSString *title = [self tableView:tableView titleForHeaderInSection:section];
    if (!title) {
        return nil;
    }
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 52)];
    
    // Top separator - modified to extend full width
// if (section != 1) {
    UIView *topSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 0.5)];
    topSeparator.backgroundColor = [UIColor separatorColor];
    topSeparator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [headerView addSubview:topSeparator];
//}
    
    // Header label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, tableView.frame.size.width - 32, 28)];
    label.text = title; 
    label.font = TwitterChirpFont(TwitterFontStyleBold); // 17pt bold
    label.textColor = [UIColor labelColor];
    [headerView addSubview:label];
    
    return headerView;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 42; // or whatever height you prefer
    }
    return 52; // or your default
}


- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    NSString *footerText = [self tableView:tableView titleForFooterInSection:section];
    if (!footerText) {
        return nil;
    }
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 44)];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, tableView.frame.size.width - 32, 36)];
    label.text = footerText;
    label.font = TwitterChirpFont(TwitterFontStyleRegular); // 12pt regular
    label.textColor = [UIColor secondaryLabelColor];
    label.numberOfLines = 0;
    [footerView addSubview:label];
    
    return footerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    NSString *footerText = [self tableView:tableView titleForFooterInSection:section];
    if (!footerText) {
        return CGFLOAT_MIN; // Use minimal height when no footer
    }
    
    // Calculate dynamic height
    CGFloat width = tableView.frame.size.width - 32;
    CGRect rect = [footerText boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                        attributes:@{NSFontAttributeName: TwitterChirpFont(TwitterFontStyleRegular)}
                                         context:nil];
    
    return ceil(rect.size.height) + 24; // Top/bottom padding
}

// And replace with this single implementation:
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Remove any default separator insets
    cell.separatorInset = UIEdgeInsetsMake(0, 0, 0, CGRectGetWidth(tableView.bounds));
    
    // Set cell background
    cell.backgroundColor = [UIColor systemBackgroundColor];
    
    // Remove selection highlight if needed
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
}


- (UITableViewStyle)tableViewStyle {
    return UITableViewStyleGrouped;
}

- (PSSpecifier *)newSectionWithTitle:(NSString *)header footer:(NSString *)footer {
    PSSpecifier *section = [PSSpecifier preferenceSpecifierNamed:header target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
    if (footer != nil) {
        [section setProperty:footer forKey:@"footerText"];
    }
    return section;
}
- (PSSpecifier *)newSwitchCellWithTitle:(NSString *)titleText detailTitle:(NSString *)detailText key:(NSString *)keyText defaultValue:(BOOL)defValue changeAction:(SEL)changeAction {
    PSSpecifier *switchCell = [PSSpecifier preferenceSpecifierNamed:titleText target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    
    [switchCell setProperty:keyText forKey:@"key"];
    [switchCell setProperty:keyText forKey:@"id"];
    [switchCell setProperty:@YES forKey:@"big"];
    [switchCell setProperty:BHSwitchTableCell.class forKey:@"cellClass"];
    [switchCell setProperty:NSBundle.mainBundle.bundleIdentifier forKey:@"defaults"];
    [switchCell setProperty:@(defValue) forKey:@"default"];
    [switchCell setProperty:NSStringFromSelector(changeAction) forKey:@"switchAction"];
    if (detailText != nil) {
        [switchCell setProperty:detailText forKey:@"subtitle"];
    }
    return switchCell;
}
- (PSSpecifier *)newButtonCellWithTitle:(NSString *)titleText detailTitle:(NSString *)detailText dynamicRule:(NSString *)rule action:(SEL)action {
    PSSpecifier *buttonCell = [PSSpecifier preferenceSpecifierNamed:titleText target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSButtonCell edit:nil];
    
    [buttonCell setButtonAction:action];
    [buttonCell setProperty:@YES forKey:@"big"];
    [buttonCell setProperty:BHButtonTableViewCell.class forKey:@"cellClass"];
    if (detailText != nil ){
        [buttonCell setProperty:detailText forKey:@"subtitle"];
    }
    if (rule != nil) {
        [buttonCell setProperty:@44 forKey:@"height"];
        [buttonCell setProperty:rule forKey:@"dynamicRule"];
    }
    return buttonCell;
}
- (PSSpecifier *)newHBLinkCellWithTitle:(NSString *)titleText detailTitle:(NSString *)detailText url:(NSString *)url {
    PSSpecifier *HBLinkCell = [PSSpecifier preferenceSpecifierNamed:titleText target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSButtonCell edit:nil];
    
    [HBLinkCell setButtonAction:@selector(hb_openURL:)];
    [HBLinkCell setProperty:HBLinkTableCell.class forKey:@"cellClass"];
    [HBLinkCell setProperty:url forKey:@"url"];
    if (detailText != nil) {
        [HBLinkCell setProperty:detailText forKey:@"subtitle"];
    }
    return HBLinkCell;
}
- (PSSpecifier *)newHBTwitterCellWithTitle:(NSString *)titleText twitterUsername:(NSString *)user customAvatarURL:(NSString *)avatarURL {
    PSSpecifier *TwitterCell = [PSSpecifier preferenceSpecifierNamed:titleText target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:1 edit:nil];
    
    [TwitterCell setButtonAction:@selector(hb_openURL:)];
    [TwitterCell setProperty:HBTwitterCell.class forKey:@"cellClass"];
    [TwitterCell setProperty:user forKey:@"user"];
    [TwitterCell setProperty:@YES forKey:@"big"];
    [TwitterCell setProperty:@56 forKey:@"height"];
    [TwitterCell setProperty:avatarURL forKey:@"iconURL"];
    return TwitterCell;
}
- (NSArray *)specifiers {
    if (!_specifiers) {

        PSSpecifier *subtitleSection = [self newSectionWithTitle:[[BHTBundle sharedBundle]
                              localizedStringForKey:@"APP_ICON_HEADER_TITLE"]
                              footer:nil];

        
PSSpecifier *tweetsSection   = [self newSectionWithTitle:[[BHTBundle sharedBundle]
                               localizedStringForKey:@"TWEETS_SECTION_HEADER_TITLE"]
                                                  footer:nil];

PSSpecifier *profilesSection = [self newSectionWithTitle:[[BHTBundle sharedBundle]
                               localizedStringForKey:@"PROFILES_SECTION_HEADER_TITLE"]
                                                  footer:nil];

PSSpecifier *searchSection   = [self newSectionWithTitle:[[BHTBundle sharedBundle]
                               localizedStringForKey:@"SEARCH_SECTION_HEADER_TITLE"]
                                                  footer:nil];

PSSpecifier *messagesSection = [self newSectionWithTitle:[[BHTBundle sharedBundle]
                               localizedStringForKey:@"MESSAGES_SECTION_HEADER_TITLE"]
                                                  footer:nil];

PSSpecifier *photosVideosSection = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"PHOTOS_VIDEOS_SECTION_HEADER_TITLE"] footer:nil];

        PSSpecifier *mainSection = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"MAIN_SECTION_HEADER_TITLE"] footer:nil];
        PSSpecifier *twitterBlueSection = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TWITTER_BLUE_SECTION_HEADER_TITLE"] footer:[[BHTBundle sharedBundle] localizedStringForKey:@"TWITTER_BLUE_SECTION_FOOTER_TITLE"]];
        PSSpecifier *layoutSection = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"LAYOUT_CUS_SECTION_HEADER_TITLE"] footer:[[BHTBundle sharedBundle] localizedStringForKey:@"LAYOUT_CUS_SECTION_FOOTER_TITLE"]];
        PSSpecifier *debug = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DEBUG_SECTION_HEADER_TITLE"] footer:nil];
        PSSpecifier *legalSection = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"LEGAL_SECTION_HEADER_TITLE"] footer:nil];
        PSSpecifier *developer = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DEVELOPER_SECTION_HEADER_TITLE"] footer:[NSString stringWithFormat:@"NeoFreeBird-BHTwitter v%@", [[BHTBundle sharedBundle] BHTwitterVersion]]];
        
        PSSpecifier *download = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DOWNLOAD_VIDEOS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DOWNLOAD_VIDEOS_OPTION_DETAIL_TITLE"] key:@"dw_v" defaultValue:true changeAction:nil];
        
        PSSpecifier *directSave = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DIRECT_SAVE_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DIRECT_SAVE_OPTION_DETAIL_TITLE"] key:@"direct_save" defaultValue:false changeAction:nil];
        
        PSSpecifier *hideAds = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_ADS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_ADS_OPTION_DETAIL_TITLE"] key:@"hide_promoted" defaultValue:true changeAction:nil];
        
        PSSpecifier *customVoice = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"UPLOAD_CUSTOM_VOICE_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"UPLOAD_CUSTOM_VOICE_OPTION_DETAIL_TITLE"] key:@"custom_voice_upload" defaultValue:true changeAction:nil];

        PSSpecifier *hideTopics = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TOPICS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TOPICS_OPTION_DETAIL_TITLE"] key:@"hide_topics" defaultValue:false changeAction:nil];
        
        PSSpecifier *hideTopicsToFollow = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TOPICS_TO_FOLLOW_OPTION"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TOPICS_TO_FOLLOW_OPTION_DETAIL_TITLE"] key:@"hide_topics_to_follow" defaultValue:false changeAction:nil];

        PSSpecifier *hideWhoToFollow = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_WHO_FOLLOW_OPTION"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_WHO_FOLLOW_OPTION_DETAIL_TITLE"] key:@"hide_who_to_follow" defaultValue:false changeAction:nil];

        PSSpecifier *hidePremiumOffer = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_PREMIUM_OFFER_OPTION"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_PREMIUM_OFFER_OPTION_DETAIL_TITLE"] key:@"hide_premium_offer" defaultValue:false changeAction:nil];

        PSSpecifier *hideTrendVideos = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TREND_VIDEOS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TREND_VIDEOS_OPTION_DETAIL_TITLE"] key:@"hide_trend_videos" defaultValue:false changeAction:nil];
        
        PSSpecifier *restoreReplyContext = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTORE_REPLY_CONTEXT_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTORE_REPLY_CONTEXT_DETAIL_TITLE"] key:@"restore_reply_context" defaultValue:false changeAction:nil];
        
        PSSpecifier *videoLayerCaption = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_VIDEO_LAYER_CAPTIONS_OPTION_TITLE"] detailTitle:nil key:@"video_layer_caption" defaultValue:false changeAction:nil];
        
        PSSpecifier *noHistory = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"NO_HISTORY_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"NO_HISTORY_OPTION_DETAIL_TITLE"] key:@"no_his" defaultValue:false changeAction:nil];
        
        PSSpecifier *bioTranslate = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BIO_TRANSALTE_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BIO_TRANSALTE_OPTION_DETAIL_TITLE"] key:@"bio_translate" defaultValue:false changeAction:nil];
        
        PSSpecifier *likeConfrim = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"LIKE_CONFIRM_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"LIKE_CONFIRM_OPTION_DETAIL_TITLE"] key:@"like_con" defaultValue:false changeAction:nil];
        
        PSSpecifier *tweetConfirm = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TWEET_CONFIRM_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TWEET_CONFIRM_OPTION_DETAIL_TITLE"] key:@"tweet_con" defaultValue:false changeAction:nil];
        
        PSSpecifier *followConfirm = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FOLLOW_CONFIRM_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FOLLOW_CONFIRM_OPTION_DETAIL_TITLE"] key:@"follow_con" defaultValue:false changeAction:nil];
        
        PSSpecifier *padLock = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"PADLOCK_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"PADLOCK_OPTION_DETAIL_TITLE"] key:@"padlock" defaultValue:false changeAction:nil];
        
        PSSpecifier *autoHighestLoad = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"AUTO_HIGHEST_LOAD_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"AUTO_HIGHEST_LOAD_OPTION_DETAIL_TITLE"] key:@"autoHighestLoad" defaultValue:true changeAction:nil];
        
        PSSpecifier *disableSensitiveTweetWarnings = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_SENSITIVE_TWEET_WARNINGS_OPTION_TITLE"] detailTitle:nil key:@"disableSensitiveTweetWarnings" defaultValue:true changeAction:nil];

        PSSpecifier *copyProfileInfo = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"COPY_PROFILE_INFO_OPTION_DETAIL_TITLE"] key:@"CopyProfileInfo" defaultValue:false changeAction:nil];
        
        PSSpecifier *tweetToImage = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TWEET_TO_IMAGE_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TWEET_TO_IMAGE_OPTION_DETAIL_TITLE"] key:@"TweetToImage" defaultValue:false changeAction:nil];
        
        PSSpecifier *hideSpace = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_SPACE_OPTION_TITLE"] detailTitle:nil key:@"hide_spaces" defaultValue:false changeAction:nil];
        
        PSSpecifier *disableRTL = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_RTL_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_RTL_OPTION_DETAIL_TITLE"] key:@"dis_rtl" defaultValue:false changeAction:nil];

        PSSpecifier *restoreTweetLabels = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ENABLE_TWEET_LABELS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ENABLE_TWEET_LABELS_OPTION_DETAIL_TITLE"] key:@"restore_tweet_labels" defaultValue:false changeAction:nil];
        
        PSSpecifier *alwaysOpenSafari = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ALWAYS_OPEN_SAFARI_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ALWAYS_OPEN_SAFARI_OPTION_DETAIL_TITLE"] key:@"openInBrowser" defaultValue:false changeAction:nil];
        
        PSSpecifier *stripTrackingParams = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"STRIP_URL_TRACKING_PARAMETERS_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"STRIP_URL_TRACKING_PARAMETERS_DETAIL_TITLE"] key:@"strip_tracking_params" defaultValue:false changeAction:nil];

        PSSpecifier *urlHost = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"SELECT_URL_HOST_AFTER_COPY_OPTION_TITLE"] detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"tweet_url_host"] dynamicRule:@"strip_tracking_params, ==, 0" action:@selector(showURLHostSelectionViewController:)];

        PSSpecifier *enableTranslate = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ENABLE_TRANSLATE_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ENABLE_TRANSLATE_OPTION_DETAIL_TITLE"] key:@"enable_translate" defaultValue:false changeAction:nil];

        PSSpecifier *translateEndpoint = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TRANSLATE_ENDPOINT_OPTION_TITLE"] detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"translate_endpoint"] ?: @"Default Gemini API" dynamicRule:@"enable_translate, ==, 0" action:@selector(showTranslateEndpointInput:)];

        NSString *apiKeyDetail = [[NSUserDefaults standardUserDefaults] objectForKey:@"translate_api_key"];
        if (apiKeyDetail && apiKeyDetail.length > 0) {
            apiKeyDetail = @"••••••••••••••••";
        } else {
            apiKeyDetail = @"Not Set";
        }
        PSSpecifier *translateAPIKey = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TRANSLATE_API_KEY_OPTION_TITLE"] detailTitle:apiKeyDetail dynamicRule:@"enable_translate, ==, 0" action:@selector(showTranslateAPIKeyInput:)];

        PSSpecifier *translateModel = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TRANSLATE_MODEL_OPTION_TITLE"] detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"translate_model"] ?: @"gemini-1.5-flash" dynamicRule:@"enable_translate, ==, 0" action:@selector(showTranslateModelInput:)];

        // Twitter bule section
        PSSpecifier *undoTweet = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"UNDO_TWEET_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"UNDO_TWEET_OPTION_DETAIL_TITLE"] key:@"undo_tweet" defaultValue:false changeAction:nil];
        
        PSSpecifier *appTheme = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_DETAIL_TITLE"] dynamicRule:nil action:@selector(showThemeViewController:)];
        
        PSSpecifier *appIcon = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_DETAIL_TITLE"] dynamicRule:nil action:@selector(showBHAppIconViewController:)];
        
        PSSpecifier *customTabBarVC = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_TITLE"] detailTitle:nil dynamicRule:nil action:@selector(showCustomTabBarVC:)];
        
        // Layout customization section
        PSSpecifier *customDirectBackgroundView = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_DIRECT_BACKGROUND_VIEW_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_DIRECT_BACKGROUND_VIEW_DETAIL_TITLE"] dynamicRule:nil action:@selector(showCustomBackgroundViewViewController:)];
        
        PSSpecifier *OldStyle = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ORIG_TWEET_STYLE_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ORIG_TWEET_STYLE_OPTION_DETAIL_TITLE"] key:@"old_style" defaultValue:false changeAction:nil];
        
        PSSpecifier *stopHidingTabBar = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"STOP_HIDING_TAB_BAR_TITLE"] detailTitle:@"Keeps the tab bar visible and prevents fading" key:@"no_tab_bar_hiding" defaultValue:false changeAction:nil];
        
        PSSpecifier *dmAvatars = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DM_AVATARS_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DM_AVATARS_DETAIL_TITLE"] key:@"dm_avatars" defaultValue:false changeAction:nil];
        
        PSSpecifier *dmComposeBarV2 = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DM_COMPOSE_BAR_V2_TITLE"] 
                                                        detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DM_COMPOSE_BAR_V2_DETAIL_TITLE"]
                                                                key:@"dm_compose_bar_v2_enabled"
                                                       defaultValue:false 
                                                       changeAction:nil];
        
        PSSpecifier *dmVoiceCreation = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DM_VOICE_CREATION_TITLE"] 
                                                        detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DM_VOICE_CREATION_DETAIL_TITLE"]
                                                                key:@"dm_voice_creation_enabled"
                                                       defaultValue:false 
                                                       changeAction:nil];
        
        PSSpecifier *tabBarTheming = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CLASSIC_TAB_BAR_SETTINGS_TITLE"]
                                                        detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CLASSIC_TAB_BAR_SETTINGS_DETAIL"]
                                                                key:@"tab_bar_theming" 
                                                       defaultValue:false 
                                                       changeAction:@selector(tabBarThemingAction:)];
        
        PSSpecifier *hideViewCount = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_VIEW_COUNT_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_VIEW_COUNT_OPTION_DETAIL_TITLE"] key:@"hide_view_count" defaultValue:false changeAction:nil];

        PSSpecifier *hideBookmarkButton = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_MARKBOOK_BUTTON_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_MARKBOOK_BUTTON_OPTION_DETAIL_TITLE"] key:@"hide_bookmark_button" defaultValue:false changeAction:nil];

        PSSpecifier *forceFullFrame = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FORCE_TWEET_FULL_FRAME_TITLE"] detailTitle:nil key:@"force_tweet_full_frame" defaultValue:false changeAction:nil];
        
        PSSpecifier *showScrollIndicator = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"SHOW_SCOLL_INDICATOR_OPTION_TITLE"] detailTitle:nil key:@"showScollIndicator" defaultValue:false changeAction:nil];
        
        PSSpecifier *font = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FONT_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FONT_OPTION_DETAIL_TITLE"] key:@"en_font" defaultValue:false changeAction:nil];
        
        PSSpecifier *regularFontsPicker = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"REQULAR_FONTS_PICKER_OPTION_TITLE"] detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"] dynamicRule:@"en_font, ==, 0" action:@selector(showRegularFontPicker:)];
        
        PSSpecifier *boldFontsPicker = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BOLD_FONTS_PICKER_OPTION_TITLE"] detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"] dynamicRule:@"en_font, ==, 0" action:@selector(showBoldFontPicker:)];
        
        PSSpecifier *disableMediaTab = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_MEDIA_TAB_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_MEDIA_TAB_OPTION_DETAIL_TITLE"] key:@"disableMediaTab" defaultValue:false changeAction:nil];

        PSSpecifier *disableArticles = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_ARTICLES_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_ARTICLES_OPTION_DETAIL_TITLE"] key:@"disableArticles" defaultValue:false changeAction:nil];

        PSSpecifier *disableHighlights = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_HIGHLIGHTS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_HIGHLIGHTS_OPTION_DETAIL_TITLE"] key:@"disableHighlights" defaultValue:false changeAction:nil];

        // New UI Customization toggles
        PSSpecifier *hideGrokAnalyze = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_GROK_ANALYZE_BUTTON_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_GROK_ANALYZE_BUTTON_DETAIL_TITLE"] key:@"hide_grok_analyze" defaultValue:false changeAction:nil];
        
        PSSpecifier *hideFollowButton = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_FOLLOW_BUTTON_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_FOLLOW_BUTTON_DETAIL_TITLE"] key:@"hide_follow_button" defaultValue:false changeAction:nil];
        
        PSSpecifier *restoreFollowButton = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTORE_FOLLOW_BUTTON_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTORE_FOLLOW_BUTTON_DETAIL_TITLE"] key:@"restore_follow_button" defaultValue:false changeAction:nil];
        

        
        PSSpecifier *squareAvatars = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"SQUARE_AVATARS_TITLE"] 
                                                        detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"SQUARE_AVATARS_DETAIL_TITLE"]
                                                                key:@"square_avatars"
                                                       defaultValue:false 
                                                       changeAction:@selector(squareAvatarsAction:)];
        
        PSSpecifier *replySorting = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"REPLY_SORTING_TITLE"] 
                                                        detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"REPLY_SORTING_DETAIL_TITLE"]
                                                                key:@"reply_sorting_enabled"
                                                       defaultValue:false 
                                                       changeAction:nil];
        
        PSSpecifier *restoreVideoTimestamp = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTORE_VIDEO_TIMESTAMP_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTORE_VIDEO_TIMESTAMP_DETAIL_TITLE"] key:@"restore_video_timestamp" defaultValue:false changeAction:nil];

        PSSpecifier *biggerActionButtons = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BIGGER_ACTION_BUTTONS_TITLE"] 
                                                        detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BIGGER_ACTION_BUTTONS_DETAIL_TITLE"]
                                                                key:@"bigger_action_buttons"
                                                       defaultValue:false 
                                                       changeAction:@selector(biggerActionButtonsAction:)];

        // debug section
        PSSpecifier *flex = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FLEX_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FLEX_OPTION_DETAIL_TITLE"] key:@"flex_twitter" defaultValue:false changeAction:@selector(FLEXAction:)];
        
        PSSpecifier *clearSourceLabelCache = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CLEAR_SOURCE_LABEL_CACHE_TITLE"]
                                                       detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CLEAR_SOURCE_LABEL_CACHE_DETAIL_TITLE"]
                                                       dynamicRule:nil
                                                            action:@selector(clearSourceLabelCacheAction:)];
        
        // legal section
        PSSpecifier *acknowledgements = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"LEGAL_BUTTON_TITLE"] detailTitle:nil dynamicRule:nil action:@selector(showAcknowledgements:)];
        
        // dvelopers section
    
        PSSpecifier *actuallyaridan = [self newHBTwitterCellWithTitle:@"aridan" twitterUsername:@"actuallyaridan" customAvatarURL:@"https://avatars.githubusercontent.com/u/96298432?v=4"];
        PSSpecifier *timi2506 = [self newHBTwitterCellWithTitle:@"timi2506" twitterUsername:@"timi2506" customAvatarURL:@"https://avatars.githubusercontent.com/u/172171055?v=4"];
        PSSpecifier *nyathea = [self newHBTwitterCellWithTitle:@"nyathea" twitterUsername:@"nyaathea" customAvatarURL:@"https://avatars.githubusercontent.com/u/108613931?v=4"];
        PSSpecifier *bandarHL = [self newHBTwitterCellWithTitle:@"BandarHelal" twitterUsername:@"BandarHL" customAvatarURL:@"https://unavatar.io/twitter/BandarHL"];
        
        _specifiers = [NSMutableArray arrayWithArray:@[
            subtitleSection,

            
            mainSection, // 0
            customVoice,
            hideTopics,
            hideTopicsToFollow,
            hideWhoToFollow,
            padLock,
            alwaysOpenSafari,
            stripTrackingParams,
            urlHost,
            enableTranslate,
            translateEndpoint,
            translateAPIKey,
            translateModel,
            
            tweetsSection, // 1
            OldStyle,
            tweetToImage,
            restoreTweetLabels,
            likeConfrim,
            tweetConfirm,
            hideViewCount,
            hideBookmarkButton,
            disableSensitiveTweetWarnings,
            hideGrokAnalyze,
            squareAvatars,
            replySorting,
            restoreReplyContext,
            
            profilesSection, // 2
            followConfirm,
            copyProfileInfo,
            bioTranslate,
            disableMediaTab,
            disableArticles,
            disableHighlights,
            hideFollowButton,
            restoreFollowButton,

            searchSection, // 3
            noHistory,
            hideTrendVideos,

            messagesSection, // 4
            dmAvatars,
            dmComposeBarV2,
            dmVoiceCreation,
            customDirectBackgroundView,

            photosVideosSection, // 5
            videoLayerCaption,
            autoHighestLoad,
            forceFullFrame,
            restoreVideoTimestamp,

            twitterBlueSection, // 6
            undoTweet,
            download,
            directSave,
            hideAds,
            hidePremiumOffer,
            appTheme,
            appIcon,
            customTabBarVC,
            
            layoutSection, // 7
            hideSpace,
            stopHidingTabBar,
            biggerActionButtons,
            tabBarTheming,
            disableRTL,
            showScrollIndicator,
            font,
            regularFontsPicker,
            boldFontsPicker,
            
            legalSection, // 8
            acknowledgements,
            
            debug, // 9
            flex,
            clearSourceLabelCache,
            
            developer, // 10
            actuallyaridan,
            timi2506,
            nyathea,
            bandarHL
        ]];
        
        [self collectDynamicSpecifiersFromArray:_specifiers];
    }
    
    return _specifiers;
}
- (void)reloadSpecifiers {
    [super reloadSpecifiers];
    
    [self collectDynamicSpecifiersFromArray:self.specifiers];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.hasDynamicSpecifiers) {
        PSSpecifier *dynamicSpecifier = [self specifierAtIndexPath:indexPath];
        BOOL __block shouldHide = false;
        
        [self.dynamicSpecifiers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSMutableArray *specifiers = obj;
            if ([specifiers containsObject:dynamicSpecifier]) {
                shouldHide = [self shouldHideSpecifier:dynamicSpecifier];
                
                UITableViewCell *specifierCell = [dynamicSpecifier propertyForKey:PSTableCellKey];
                specifierCell.clipsToBounds = shouldHide;
            }
        }];
        if (shouldHide) {
            return 0;
        }
    }
    
    return UITableViewAutomaticDimension;
}

- (void)collectDynamicSpecifiersFromArray:(NSArray *)array {
    if (!self.dynamicSpecifiers) {
        self.dynamicSpecifiers = [NSMutableDictionary new];
        
    } else {
        [self.dynamicSpecifiers removeAllObjects];
    }
    
    for (PSSpecifier *specifier in array) {
        NSString *dynamicSpecifierRule = [specifier propertyForKey:@"dynamicRule"];
        
        if (dynamicSpecifierRule.length > 0) {
            NSArray *ruleComponents = [dynamicSpecifierRule componentsSeparatedByString:@", "];
            
            if (ruleComponents.count == 3) {
                NSString *opposingSpecifierID = [ruleComponents objectAtIndex:0];
                if ([self.dynamicSpecifiers objectForKey:opposingSpecifierID]) {
                    NSMutableArray *specifiers = [[self.dynamicSpecifiers objectForKey:opposingSpecifierID] mutableCopy];
                    [specifiers addObject:specifier];
                    
                    
                    [self.dynamicSpecifiers removeObjectForKey:opposingSpecifierID];
                    [self.dynamicSpecifiers setObject:specifiers forKey:opposingSpecifierID];
                } else {
                    [self.dynamicSpecifiers setObject:[NSMutableArray arrayWithArray:@[specifier]] forKey:opposingSpecifierID];
                }
                
            } else {
                [NSException raise:NSInternalInconsistencyException format:@"dynamicRule key requires three components (Specifier ID, Comparator, Value To Compare To). You have %ld of 3 (%@) for specifier '%@'.", ruleComponents.count, dynamicSpecifierRule, [specifier propertyForKey:PSTitleKey]];
            }
        }
    }
    
    self.hasDynamicSpecifiers = (self.dynamicSpecifiers.count > 0);
}
- (DynamicSpecifierOperatorType)operatorTypeForString:(NSString *)string {
    NSDictionary *operatorValues = @{ @"==" : @(EqualToOperatorType), @"!=" : @(NotEqualToOperatorType), @">" : @(GreaterThanOperatorType), @"<" : @(LessThanOperatorType) };
    return [operatorValues[string] intValue];
}
- (BOOL)shouldHideSpecifier:(PSSpecifier *)specifier {
    if (specifier) {
        NSString *dynamicSpecifierRule = [specifier propertyForKey:@"dynamicRule"];
        NSArray *ruleComponents = [dynamicSpecifierRule componentsSeparatedByString:@", "];
        
        PSSpecifier *opposingSpecifier = [self specifierForID:[ruleComponents objectAtIndex:0]];
        id opposingValue = [self readPreferenceValue:opposingSpecifier];
        id requiredValue = [ruleComponents objectAtIndex:2];
        
        if ([opposingValue isKindOfClass:NSNumber.class]) {
            DynamicSpecifierOperatorType operatorType = [self operatorTypeForString:[ruleComponents objectAtIndex:1]];
            
            switch (operatorType) {
                case EqualToOperatorType:
                    return ([opposingValue intValue] == [requiredValue intValue]);
                    break;
                    
                case NotEqualToOperatorType:
                    return ([opposingValue intValue] != [requiredValue intValue]);
                    break;
                    
                case GreaterThanOperatorType:
                    return ([opposingValue intValue] > [requiredValue intValue]);
                    break;
                    
                case LessThanOperatorType:
                    return ([opposingValue intValue] < [requiredValue intValue]);
                    break;
            }
        }
        
        if ([opposingValue isKindOfClass:NSString.class]) {
            return [opposingValue isEqualToString:requiredValue];
        }
        
        if ([opposingValue isKindOfClass:NSArray.class]) {
            return [opposingValue containsObject:requiredValue];
        }
    }
    
    return NO;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *Prefs = [NSUserDefaults standardUserDefaults];
    [Prefs setValue:value forKey:[specifier identifier]];
    
    if (self.hasDynamicSpecifiers) {
        NSString *specifierID = [specifier propertyForKey:PSIDKey];
        PSSpecifier *dynamicSpecifier = [self.dynamicSpecifiers objectForKey:specifierID];
        
        if (dynamicSpecifier) {
            [self.table beginUpdates];
            [self.table endUpdates];
        }
    }
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSUserDefaults *Prefs = [NSUserDefaults standardUserDefaults];
    return [Prefs valueForKey:[specifier identifier]]?:[specifier properties][@"default"];
}


- (void)fontPickerViewControllerDidPickFont:(UIFontPickerViewController *)viewController {
    NSString *fontName = viewController.selectedFontDescriptor.fontAttributes[UIFontDescriptorNameAttribute];
    NSString *fontFamily = viewController.selectedFontDescriptor.fontAttributes[UIFontDescriptorFamilyAttribute];
    
    if (viewController.configuration.includeFaces) {
        PSSpecifier *fontSpecifier = [self specifierForID:@"Bold Font"];
        [[NSUserDefaults standardUserDefaults] setObject:fontName forKey:@"bhtwitter_font_2"];
        [fontSpecifier setProperty:fontName forKey:@"subtitle"];
    } else {
        PSSpecifier *fontSpecifier = [self specifierForID:@"Font"];
        [[NSUserDefaults standardUserDefaults] setObject:fontFamily forKey:@"bhtwitter_font_1"];
        [fontSpecifier setProperty:fontName forKey:@"subtitle"];
    }
    [self reloadSpecifiers];
    [viewController.navigationController popViewControllerAnimated:true];
}
- (void)showRegularFontPicker:(PSSpecifier *)specifier {
    UIFontPickerViewControllerConfiguration *configuration = [[UIFontPickerViewControllerConfiguration alloc] init];
    [configuration setFilteredTraits:UIFontDescriptorClassMask];
    [configuration setIncludeFaces:false];
    
    UIFontPickerViewController *fontPicker = [[UIFontPickerViewController alloc] initWithConfiguration:configuration];
    fontPicker.delegate = self;
    
    if (self.twAccount != nil) {
        [fontPicker.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"Choose Font" subtitle:self.twAccount.displayUsername]];
    }
    [self.navigationController pushViewController:fontPicker animated:true];
}
- (void)showBoldFontPicker:(PSSpecifier *)specifier {
    UIFontPickerViewControllerConfiguration *configuration = [[UIFontPickerViewControllerConfiguration alloc] init];
    [configuration setIncludeFaces:true];
    [configuration setFilteredTraits:UIFontDescriptorClassModernSerifs];
    [configuration setFilteredTraits:UIFontDescriptorClassMask];
    
    UIFontPickerViewController *fontPicker = [[UIFontPickerViewController alloc] initWithConfiguration:configuration];
    fontPicker.delegate = self;
    
    if (self.twAccount != nil) {
        [fontPicker.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"Choose Font" subtitle:self.twAccount.displayUsername]];
    }
    [self.navigationController pushViewController:fontPicker animated:true];
}
- (void)showAcknowledgements:(PSSpecifier *)specifier {
    T1RichTextFormatViewController *acknowledgementsVC = [[objc_getClass("T1RichTextFormatViewController") alloc] initWithRichTextFormatDocumentPath:[[BHTBundle sharedBundle] pathForFile:@"Acknowledgements.rtf"].path];
    if (self.twAccount != nil) {
        [acknowledgementsVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ACKNOWLEDGEMENTS_SETTINGS_NAVIGATION_TITLE"] subtitle:self.twAccount.displayUsername]];
    }
    [self.navigationController pushViewController:acknowledgementsVC animated:true];
}
- (void)showCustomTabBarVC:(PSSpecifier *)specifier {
    BHCustomTabBarViewController *customTabBarVC = [[BHCustomTabBarViewController alloc] init];
    if (self.twAccount != nil) {
        [customTabBarVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_SETTINGS_NAVIGATION_TITLE"] subtitle:self.twAccount.displayUsername]];
    }
    [self.navigationController pushViewController:customTabBarVC animated:true];
}
- (void)showThemeViewController:(PSSpecifier *)specifier {
    // I create my own Color Theme ViewController for two main reasons:
    // 1- Twitter use swift to build their view controller, so I can't hook anything on it.
    // 2- Twitter knows you do not actually subscribe with Twitter Blue, so it keeps resting the changes and resting 'T1ColorSettingsPrimaryColorOptionKey' key, so I had to create another key to track the original one and keep sure no changes, but it still not enough to keep the new theme after relaunching app, so i had to force the changes again with new lunch.
    BHColorThemeViewController *themeVC = [[BHColorThemeViewController alloc] init];
    if (self.twAccount != nil) {
        [themeVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_SETTINGS_NAVIGATION_TITLE"] subtitle:self.twAccount.displayUsername]];
    }
    [self.navigationController pushViewController:themeVC animated:true];
}
- (void)showBHAppIconViewController:(PSSpecifier *)specifier {
    BHAppIconViewController *appIconVC = [[BHAppIconViewController alloc] init];
    if (self.twAccount != nil) {
        [appIconVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_NAV_TITLE"] subtitle:self.twAccount.displayUsername]];
    }
    [self.navigationController pushViewController:appIconVC animated:true];
}
- (void)showURLHostSelectionViewController:(PSSpecifier *)specifier {
    UITableViewCell *specifierCell = [specifier propertyForKey:PSTableCellKey];
    PSSpecifier *selectionSpecifier = [self specifierForID:@"Select URL host"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"NeoFreeBird" message:@"URL" preferredStyle:UIAlertControllerStyleActionSheet];

    if (alert.popoverPresentationController != nil) {
        CGFloat midX = CGRectGetMidX(specifierCell.frame);
        CGFloat midY = CGRectGetMidY(specifierCell.frame);

        alert.popoverPresentationController.sourceRect = CGRectMake(midX, midY, 0, 0);
        alert.popoverPresentationController.sourceView = specifierCell;
    }

    UIAlertAction *xHostAction = [UIAlertAction actionWithTitle:@"x.com" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setObject:@"x.com" forKey:@"tweet_url_host"];
        [selectionSpecifier setProperty:@"x.com" forKey:@"subtitle"];
        [self reloadSpecifiers];
    }];
    UIAlertAction *twitterHostAction = [UIAlertAction actionWithTitle:@"twitter.com" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setObject:@"twitter.com" forKey:@"tweet_url_host"];
        [selectionSpecifier setProperty:@"twitter.com" forKey:@"subtitle"];
        [self reloadSpecifiers];
    }];
    UIAlertAction *fxHostAction = [UIAlertAction actionWithTitle:@"fxtwitter.com" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setObject:@"fxtwitter.com" forKey:@"tweet_url_host"];
        [selectionSpecifier setProperty:@"fxtwitter.com" forKey:@"subtitle"];
        [self reloadSpecifiers];
    }];
    UIAlertAction *vxHostAction = [UIAlertAction actionWithTitle:@"vxtwitter.com" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setObject:@"vxtwitter.com" forKey:@"tweet_url_host"];
        [selectionSpecifier setProperty:@"vxtwitter.com" forKey:@"subtitle"];
        [self reloadSpecifiers];
    }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:xHostAction];
    [alert addAction:twitterHostAction];
    [alert addAction:fxHostAction];
    [alert addAction:vxHostAction];
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:true completion:nil];
}
- (void)showCustomBackgroundViewViewController:(PSSpecifier *)specifier {
    UITableViewCell *specifierCell = [specifier propertyForKey:PSTableCellKey];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"NeoFreeBird" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    if (alert.popoverPresentationController != nil) {
        CGFloat midX = CGRectGetMidX(specifierCell.frame);
        CGFloat midY = CGRectGetMidY(specifierCell.frame);

        alert.popoverPresentationController.sourceRect = CGRectMake(midX, midY, 0, 0);
        alert.popoverPresentationController.sourceView = specifierCell;
    }
    
    UIAlertAction *imageAction = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_DIRECT_BACKGROUND_ALERT_OPTION_1"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.delegate = self;
        [self presentViewController:imagePicker animated:YES completion:nil];
    }];
    
    UIAlertAction *colorAction = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_DIRECT_BACKGROUND_ALERT_OPTION_2"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIColorPickerViewController *colorPicker = [[UIColorPickerViewController alloc] init];
        colorPicker.delegate = self;
        [self presentViewController:colorPicker animated:true completion:nil];
    }];
    
    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_DIRECT_BACKGROUND_ALERT_OPTION_3"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"change_msg_background"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"background_image"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"background_color"];
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:imageAction];
    [alert addAction:colorAction];
    [alert addAction:resetAction];
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:true completion:nil];
}

- (void)FLEXAction:(UISwitch *)sender {
    if (sender.isOn) {
        [[objc_getClass("FLEXManager") sharedManager] showExplorer];
    } else {
        [[objc_getClass("FLEXManager") sharedManager] hideExplorer];
    }
}

- (void)clearSourceLabelCacheAction:(PSSpecifier *)specifier {
    [BHTManager clearSourceLabelCache];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CACHE_CLEARED_TITLE"] 
                                                                   message:[[BHTBundle sharedBundle] localizedStringForKey:@"CACHE_CLEARED_MESSAGE"] 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"OK_BUTTON_TITLE"] 
                                              style:UIAlertActionStyleDefault 
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// Translate configuration input methods
- (void)showTranslateEndpointInput:(PSSpecifier *)specifier {
    NSString *currentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"translate_endpoint"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TRANSLATE_ENDPOINT_OPTION_TITLE"]
                                                                   message:@"Enter the API endpoint URL for translation"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";
        textField.text = currentValue;
        textField.keyboardType = UIKeyboardTypeURL;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"OK_BUTTON_TITLE"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *inputText = alert.textFields.firstObject.text;
        if (inputText.length > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:inputText forKey:@"translate_endpoint"];
            [specifier setProperty:inputText forKey:@"subtitle"];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"translate_endpoint"];
            [specifier setProperty:@"Default Gemini API" forKey:@"subtitle"];
        }
        [self reloadSpecifiers];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showTranslateAPIKeyInput:(PSSpecifier *)specifier {
    NSString *currentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"translate_api_key"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TRANSLATE_API_KEY_OPTION_TITLE"]
                                                                   message:@"Enter your API key for the translation service"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"API Key";
        textField.text = currentValue;
        textField.secureTextEntry = YES;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"OK_BUTTON_TITLE"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *inputText = alert.textFields.firstObject.text;
        if (inputText.length > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:inputText forKey:@"translate_api_key"];
            [specifier setProperty:@"••••••••••••••••" forKey:@"subtitle"];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"translate_api_key"];
            [specifier setProperty:@"Not Set" forKey:@"subtitle"];
        }
        [self reloadSpecifiers];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showTranslateModelInput:(PSSpecifier *)specifier {
    NSString *currentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"translate_model"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TRANSLATE_MODEL_OPTION_TITLE"]
                                                                   message:@"Enter the model name to use for translation"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"gemini-1.5-flash";
        textField.text = currentValue;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"OK_BUTTON_TITLE"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *inputText = alert.textFields.firstObject.text;
        if (inputText.length > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:inputText forKey:@"translate_model"];
            [specifier setProperty:inputText forKey:@"subtitle"];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"translate_model"];
            [specifier setProperty:@"gemini-1.5-flash" forKey:@"subtitle"];
        }
        [self reloadSpecifiers];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"change_msg_background"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"background_image"];
    
    
    UIColor *selectedColor = viewController.selectedColor;
    [[NSUserDefaults standardUserDefaults] setObject:selectedColor.hexString forKey:@"background_color"];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *DocPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    
    NSURL *oldImgPath = info[UIImagePickerControllerImageURL];
    NSURL *newImgPath = [[NSURL fileURLWithPath:DocPath] URLByAppendingPathComponent:@"msg_background.png"];
    
    if ([manager fileExistsAtPath:newImgPath.path]) {
        [manager removeItemAtURL:newImgPath error:nil];
    } 
    
    [manager copyItemAtURL:oldImgPath toURL:newImgPath error:nil];
    
    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"change_msg_background"];
    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"background_image"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"background_color"];
    
    [picker dismissViewControllerAnimated:true completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:true completion:nil];
}

- (void)tabBarThemingAction:(UISwitch *)sender {
    BOOL newState = sender.isOn;
    NSString *key = @"tab_bar_theming"; // The UserDefaults key
    BOOL previousState = !newState;    // The state before the user toggled the switch

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_REQUIRED_ALERT_TITLE"]
                                                                   message:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_REQUIRED_ALERT_MESSAGE_CLASSIC_TAB_BAR_GENERIC"]
                                                                preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_NOW_BUTTON_TITLE"]
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setBool:newState forKey:key];
            [[NSUserDefaults standardUserDefaults] synchronize];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                exit(0);
            });
        }]];

    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"]
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * _Nonnull action) {
        // Revert the switch to its previous state if canceled
        [sender setOn:previousState animated:YES];
        }]];

        [self presentViewController:alert animated:YES completion:nil];
}

- (void)squareAvatarsAction:(UISwitch *)sender {
    BOOL enabled = sender.isOn;
    NSString *key = @"square_avatars";
    BOOL previousValue = !enabled; // The value before the switch was flipped

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_REQUIRED_ALERT_TITLE"]
                                                                   message:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_REQUIRED_ALERT_MESSAGE_SQUARE_AVATARS"]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_NOW_BUTTON_TITLE"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // Flip the switch back visually if cancelled
        [sender setOn:previousValue animated:YES];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)biggerActionButtonsAction:(UISwitch *)sender {
    BOOL enabled = sender.isOn;
    NSString *key = @"bigger_action_buttons";
    BOOL previousValue = !enabled; // The value before the switch was flipped

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_REQUIRED_ALERT_TITLE"]
                                                                   message:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_REQUIRED_ALERT_MESSAGE_GENERIC"]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"RESTART_NOW_BUTTON_TITLE"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CANCEL_BUTTON_TITLE"] style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // Flip the switch back visually if cancelled
        [sender setOn:previousValue animated:YES];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

// Need helper to find specifier by key for switch actions
- (PSSpecifier *)specifierForID:(NSString *)identifier {
    for (PSSpecifier *specifier in [self specifiers]) {
        if ([[specifier propertyForKey:@"key"] isEqualToString:identifier]) {
            return specifier;
        }
    }
    return nil;
}

@end

@implementation BHButtonTableViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        NSString *subTitle = [specifier.properties[@"subtitle"] copy];
        BOOL isBig = specifier.properties[@"big"] ? ((NSNumber *)specifier.properties[@"big"]).boolValue : NO;
        
        // Set the font to semibold
        self.textLabel.font = TwitterChirpFont(TwitterFontStyleSemibold); // 14pt semibold
        
        // Keep subtitle style exactly as before
        self.detailTextLabel.text = subTitle;
        self.detailTextLabel.numberOfLines = isBig ? 0 : 1;
        self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        self.detailTextLabel.font = TwitterChirpFont(TwitterFontStyleRegular); // Match footer font
        self.selectionStyle = UITableViewCellSelectionStyleDefault; // or .None if you don't want selection highlight
    }
    return self;
}
@end

@implementation BHSwitchTableCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier])) {
        NSString *subTitle = [specifier.properties[@"subtitle"] copy];
        BOOL isBig = specifier.properties[@"big"] ? ((NSNumber *)specifier.properties[@"big"]).boolValue : NO;
        
        // Set the font to semibold
        self.textLabel.font = TwitterChirpFont(TwitterFontStyleSemibold); // 14pt semibold

        // Keep subtitle style exactly as before
        self.detailTextLabel.text = subTitle;
        self.detailTextLabel.numberOfLines = isBig ? 0 : 1;
        self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        self.detailTextLabel.font = TwitterChirpFont(TwitterFontStyleRegular); // Match footer font
        self.selectionStyle = UITableViewCellSelectionStyleDefault; // or .None if you don't want selection highlight
        
        if (specifier.properties[@"switchAction"]) {
            UISwitch *targetSwitch = ((UISwitch *)[self control]);
            NSString *strAction = [specifier.properties[@"switchAction"] copy];
            [targetSwitch addTarget:[self cellTarget] action:NSSelectorFromString(strAction) forControlEvents:UIControlEventValueChanged];
        }
    }
    return self;
}
@end
