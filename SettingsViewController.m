//
//  SettingsViewController.m
//  BHTwitter
//
//  Created by BandarHelal
//


#import "SettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "Colours/Colours.h"
#import "AppIcon/BHAppIconViewController.h"
#import "ThemeColor/BHColorThemeViewController.h"
#import "CustomTabBar/BHCustomTabBarViewController.h"

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
    }
    return self;
}
- (void)dealloc {
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"bh_color_theme_selectedColor"];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"T1ColorSettingsPrimaryColorOptionKey"];
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
    self.hb_appearanceSettings = appearanceSettings;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"bh_color_theme_selectedColor"] || [keyPath isEqualToString:@"T1ColorSettingsPrimaryColorOptionKey"]) {
        [self setupAppearance];
    }
}

- (UITableViewStyle)tableViewStyle {
    return UITableViewStyleInsetGrouped;
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
        
        PSSpecifier *mainSection = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"MAIN_SECTION_HEADER_TITLE"] footer:nil];
        PSSpecifier *twitterBlueSection = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"TWITTER_BLUE_SECTION_HEADER_TITLE"] footer:[[BHTBundle sharedBundle] localizedStringForKey:@"TWITTER_BLUE_SECTION_FOOTER_TITLE"]];
        PSSpecifier *layoutSection = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"LAYOUT_CUS_SECTION_HEADER_TITLE"] footer:[[BHTBundle sharedBundle] localizedStringForKey:@"LAYOUT_CUS_SECTION_FOOTER_TITLE"]];
        PSSpecifier *legalSection = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"LEGAL_SECTION_HEADER_TITLE"] footer:nil];
        PSSpecifier *developer = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DEVELOPER_SECTION_HEADER_TITLE"] footer:nil];
        PSSpecifier *other = [self newSectionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"PEOPLE_WHO_CONTRIBUTED_SECTION_HEADER_TITLE"] footer:[NSString stringWithFormat:@"BHTwitter v%@", [[BHTBundle sharedBundle] BHTwitterVersion]]];
        
        PSSpecifier *download = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DOWNLOAD_VIDEOS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DOWNLOAD_VIDEOS_OPTION_DETAIL_TITLE"] key:@"dw_v" defaultValue:true changeAction:nil];
        
        PSSpecifier *directSave = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DIRECT_SAVE_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DIRECT_SAVE_OPTION_DETAIL_TITLE"] key:@"direct_save" defaultValue:false changeAction:nil];
        
        PSSpecifier *hideAds = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_ADS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_ADS_OPTION_DETAIL_TITLE"] key:@"hide_promoted" defaultValue:true changeAction:nil];
        
        PSSpecifier *voiceFeature = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"VOICE_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"VOICE_OPTION_DETAIL_TITLE"] key:@"voice_creation_enabled" defaultValue:false changeAction:nil];

        PSSpecifier *customVoice = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"UPLOAD_CUSTOM_VOICE_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"UPLOAD_CUSTOM_VOICE_OPTION_DETAIL_TITLE"] key:@"custom_voice_upload" defaultValue:true changeAction:nil];

        PSSpecifier *dmReplyLater = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DM_REPLY_LATER_ENABLED_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DM_REPLY_LATER_ENABLED_OPTION_DETAIL_TITLE"] key:@"dm_reply_later_enabled" defaultValue:false changeAction:nil];

        PSSpecifier *mediaUpload4k = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"MEDIA_UPLOAD_4K_ENABLED_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"MEDIA_UPLOAD_4K_ENABLED_OPTION_DETAIL_TITLE"] key:@"media_upload_4k_enabled" defaultValue:false changeAction:nil];

        PSSpecifier *hideTopics = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TOPICS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TOPICS_OPTION_DETAIL_TITLE"] key:@"hide_topics" defaultValue:false changeAction:nil];
        
        PSSpecifier *hideWhoToFollow = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_WHO_FOLLOW_OPTION"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_WHO_FOLLOW_OPTION_DETAIL_TITLE"] key:@"hide_who_to_follow" defaultValue:false changeAction:nil];
        
        PSSpecifier *hideTopicsToFollow = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TOPICS_TO_FOLLOW_OPTION"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TOPICS_TO_FOLLOW_OPTION_DETAIL_TITLE"] key:@"hide_topics_to_follow" defaultValue:false changeAction:nil];

        PSSpecifier *hidePremiumOffer = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_PREMIUM_OFFER_OPTION"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_PREMIUM_OFFER_OPTION_DETAIL_TITLE"] key:@"hide_premium_offer" defaultValue:false changeAction:nil];

        PSSpecifier *hideTrendVideos = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TREND_VIDEOS_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_TREND_VIDEOS_OPTION_DETAIL_TITLE"] key:@"hide_trend_videos" defaultValue:false changeAction:nil];
        
        PSSpecifier *videoLayerCaption = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"DISABLE_VIDEO_LAYER_CAPTIONS_OPTION_TITLE"] detailTitle:nil key:@"dis_VODCaptions" defaultValue:false changeAction:nil];
        
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
        
        PSSpecifier *alwaysOpenSafari = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ALWAYS_OPEN_SAFARI_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"ALWAYS_OPEN_SAFARI_OPTION_DETAIL_TITLE"] key:@"openInBrowser" defaultValue:false changeAction:nil];
        
        PSSpecifier *stripTrackingParams = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"STRIP_URL_TRACKING_PARAMETERS_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"STRIP_URL_TRACKING_PARAMETERS_DETAIL_TITLE"] key:@"strip_tracking_params" defaultValue:false changeAction:nil];

        PSSpecifier *urlHost = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"SELECT_URL_HOST_AFTER_COPY_OPTION_TITLE"] detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"tweet_url_host"] dynamicRule:@"strip_tracking_params, ==, 0" action:@selector(showURLHostSelectionViewController:)];

        // Twitter bule section
        PSSpecifier *undoTweet = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"UNDO_TWEET_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"UNDO_TWEET_OPTION_DETAIL_TITLE"] key:@"undo_tweet" defaultValue:false changeAction:nil];
        
        PSSpecifier *appTheme = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_DETAIL_TITLE"] dynamicRule:nil action:@selector(showThemeViewController:)];
        
        PSSpecifier *appIcon = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_DETAIL_TITLE"] dynamicRule:nil action:@selector(showBHAppIconViewController:)];
        
        PSSpecifier *customTabBarVC = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_TITLE"] detailTitle:nil dynamicRule:nil action:@selector(showCustomTabBarVC:)];
        
        // Layout customization section
        PSSpecifier *customDirectBackgroundView = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_DIRECT_BACKGROUND_VIEW_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_DIRECT_BACKGROUND_VIEW_DETAIL_TITLE"] dynamicRule:nil action:@selector(showCustomBackgroundViewViewController:)];
        
        PSSpecifier *hideViewCount = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_VIEW_COUNT_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_VIEW_COUNT_OPTION_DETAIL_TITLE"] key:@"hide_view_count" defaultValue:false changeAction:nil];

        PSSpecifier *hideBookmarkButton = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_MARKBOOK_BUTTON_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"HIDE_MARKBOOK_BUTTON_OPTION_DETAIL_TITLE"] key:@"hide_bookmark_button" defaultValue:false changeAction:nil];

        PSSpecifier *forceFullFrame = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FORCE_TWEET_FULL_FRAME_TITLE"] detailTitle:nil key:@"force_tweet_full_frame" defaultValue:false changeAction:nil];
        
        PSSpecifier *showScrollIndicator = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"SHOW_SCOLL_INDICATOR_OPTION_TITLE"] detailTitle:nil key:@"showScollIndicator" defaultValue:false changeAction:nil];
        
        PSSpecifier *font = [self newSwitchCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FONT_OPTION_TITLE"] detailTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"FONT_OPTION_DETAIL_TITLE"] key:@"en_font" defaultValue:false changeAction:nil];
        
        PSSpecifier *regularFontsPicker = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"REQULAR_FONTS_PICKER_OPTION_TITLE"] detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"] dynamicRule:@"en_font, ==, 0" action:@selector(showRegularFontPicker:)];
        
        PSSpecifier *boldFontsPicker = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"BOLD_FONTS_PICKER_OPTION_TITLE"] detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"] dynamicRule:@"en_font, ==, 0" action:@selector(showBoldFontPicker:)];
        
        // legal section
        PSSpecifier *acknowledgements = [self newButtonCellWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"LEGAL_BUTTON_TITLE"] detailTitle:nil dynamicRule:nil action:@selector(showAcknowledgements:)];
        
        // developer section
        PSSpecifier *bandarHL = [self newHBTwitterCellWithTitle:@"BandarHelal" twitterUsername:@"BandarHL" customAvatarURL:@"https://unavatar.io/twitter/BandarHL"];
        PSSpecifier *tipJar = [self newHBLinkCellWithTitle:@"Tip Jar" detailTitle:@"Donate Via Paypal" url:@"https://www.paypal.me/BandarHL"];
        PSSpecifier *buymecoffee = [self newHBLinkCellWithTitle:@"Buy Me A Coffee" detailTitle:nil url:@"https://www.buymeacoffee.com/bandarHL"];
        PSSpecifier *sourceCode = [self newHBLinkCellWithTitle:@"BHTwitter" detailTitle:@"Code source of BHTwitter" url:@"https://github.com/BandarHL/BHTwitter/"];

        // people who contributed section
        PSSpecifier *actuallyaridan = [self newHBTwitterCellWithTitle:@"aridan" twitterUsername:@"actuallyaridan" customAvatarURL:@"https://avatars.githubusercontent.com/u/96298432?v=4"];
        PSSpecifier *tulugaak = [self newHBTwitterCellWithTitle:@"tekkeitsertok" twitterUsername:@"tulugaak1" customAvatarURL:@"https://unavatar.io/x/tulugaak1"];
        PSSpecifier *timi2506 = [self newHBTwitterCellWithTitle:@"timi2506" twitterUsername:@"timi2506" customAvatarURL:@"https://avatars.githubusercontent.com/u/172171055?v=4"];
        PSSpecifier *nyathea = [self newHBTwitterCellWithTitle:@"nyathea" twitterUsername:@"nyaathea" customAvatarURL:@"https://avatars.githubusercontent.com/u/108613931?v=4"];
        
        _specifiers = [NSMutableArray arrayWithArray:@[
            
            mainSection, // 0
            download,
            voiceFeature,
            customVoice,
            dmReplyLater,
            mediaUpload4k,
            hideTopics,
            hideWhoToFollow,
            hideTopicsToFollow,
            hideTrendVideos,
            videoLayerCaption,
            directSave,
            noHistory,
            bioTranslate,
            likeConfrim,
            tweetConfirm,
            followConfirm,
            padLock,
            autoHighestLoad,
            disableSensitiveTweetWarnings,
            copyProfileInfo,
            tweetToImage,
            hideSpace,
            disableRTL,
            alwaysOpenSafari,
            stripTrackingParams,
            urlHost,
            
            twitterBlueSection, // 1
            undoTweet,
            directSave,
            hideAds,
            hidePremiumOffer,
            appTheme,
            appIcon,
            customTabBarVC,
            
            layoutSection, // 2
            customDirectBackgroundView,
            hideViewCount,
            hideBookmarkButton,
            forceFullFrame,
            showScrollIndicator,
            font,
            regularFontsPicker,
            boldFontsPicker,
            
            legalSection, // 3
            acknowledgements,
            
            developer, // 5
            bandarHL,
            tipJar,
            buymecoffee,
            sourceCode,

            other, // 6
            actuallyaridan,
            tulugaak,
            timi2506,
            nyathea,
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

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BHTwitter" message:@"please select what host you prefer" preferredStyle:UIAlertControllerStyleActionSheet];

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
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BHTwitter" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
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
@end

@implementation BHButtonTableViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        NSString *subTitle = [specifier.properties[@"subtitle"] copy];
        BOOL isBig = specifier.properties[@"big"] ? ((NSNumber *)specifier.properties[@"big"]).boolValue : NO;

        // Keep subtitle style exactly as before
        self.detailTextLabel.text = subTitle;
        self.detailTextLabel.numberOfLines = isBig ? 0 : 1;
        self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    return self;
}

@end

@implementation BHSwitchTableCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier])) {
        NSString *subTitle = [specifier.properties[@"subtitle"] copy];
        BOOL isBig = specifier.properties[@"big"] ? ((NSNumber *)specifier.properties[@"big"]).boolValue : NO;

        // Keep subtitle style exactly as before
        self.detailTextLabel.text = subTitle;
        self.detailTextLabel.numberOfLines = isBig ? 0 : 1;
        self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        
        if (specifier.properties[@"switchAction"]) {
            UISwitch *targetSwitch = ((UISwitch *)[self control]);
            NSString *strAction = [specifier.properties[@"switchAction"] copy];
            [targetSwitch addTarget:[self cellTarget] action:NSSelectorFromString(strAction) forControlEvents:UIControlEventValueChanged];
        }
    }
    return self;
}
@end
