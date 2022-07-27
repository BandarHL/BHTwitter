//
//  SettingsViewController.m
//  BHTwitter
//
//  Created by BandarHelal
//

#import "SettingsViewController.h"
#import "BHTwitter+NSURL.h"
#import "BHTwitter-Swift.h"

@interface SettingsViewController () <UIFontPickerViewControllerDelegate>
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
    }
    return self;
}

- (void)setupAppearance {
    NSUInteger colorOption = [[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"];
    TAEColorSettings *colorSettings = [objc_getClass("TAEColorSettings") sharedSettings];
    UIColor *primaryColor = [[[colorSettings currentColorPalette] colorPalette] primaryColorForOption:colorOption];
    
    HBAppearanceSettings *appearanceSettings = [[HBAppearanceSettings alloc] init];
    appearanceSettings.tintColor = primaryColor;
    self.hb_appearanceSettings = appearanceSettings;
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
- (PSSpecifier *)newSwitchCellWithTitle:(NSString *)titleText detailTitle:(NSString *)detailText key:(NSString *)keyText defaultValue:(BOOL)defValue {
    PSSpecifier *switchCell = [PSSpecifier preferenceSpecifierNamed:titleText target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    
    [switchCell setProperty:keyText forKey:@"key"];
    [switchCell setProperty:keyText forKey:@"id"];
    [switchCell setProperty:@YES forKey:@"big"];
    [switchCell setProperty:BHSwitchTableCell.class forKey:@"cellClass"];
    [switchCell setProperty:NSBundle.mainBundle.bundleIdentifier forKey:@"defaults"];
    [switchCell setProperty:@(defValue) forKey:@"default"];
    if (detailText != nil ){
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
- (PSSpecifier *)newHBTwitterCellWithTitle:(NSString *)titleText twitterUsername:(NSString *)user {
    PSSpecifier *TwitterCell = [PSSpecifier preferenceSpecifierNamed:titleText target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:1 edit:nil];
    
    [TwitterCell setButtonAction:@selector(hb_openURL:)];
    [TwitterCell setProperty:HBTwitterCell.class forKey:@"cellClass"];
    [TwitterCell setProperty:user forKey:@"user"];
    [TwitterCell setProperty:@YES forKey:@"big"];
    [TwitterCell setProperty:@56 forKey:@"height"];
    
    return TwitterCell;
}
- (NSArray *)specifiers {
    if (!_specifiers) {
        
        PSSpecifier *mainSection = [self newSectionWithTitle:@"BHTwitter Preferences" footer:nil];
        PSSpecifier *twitterBlueSection = [self newSectionWithTitle:@"Twitter blue features" footer:@"You may need to restart Twitter app to apply changes"];
        PSSpecifier *layoutSection = [self newSectionWithTitle:@"Layout customization" footer:@"Restart Twitter app to apply changes"];
        PSSpecifier *debug = [self newSectionWithTitle:@"Debugging" footer:nil];
        PSSpecifier *legalSection = [self newSectionWithTitle:@"Legal notices" footer:nil];
        PSSpecifier *developer = [self newSectionWithTitle:@"Developer" footer:@"BHTwitter v2.9.8"];
        
        PSSpecifier *download = [self newSwitchCellWithTitle:@"Downloading videos" detailTitle:@"Downloading videos. By adding button in tweet and inside video tab bar." key:@"dw_v" defaultValue:true];
        
        PSSpecifier *directSave = [self newSwitchCellWithTitle:@"Direct save" detailTitle:@"Save video directly after downloading." key:@"direct_save" defaultValue:false];
        
        PSSpecifier *hideAds = [self newSwitchCellWithTitle:@"Hide Ads" detailTitle:@"Remove all Ads in Twitter." key:@"hide_promoted" defaultValue:true];
        
        PSSpecifier *hideTopics = [self newSwitchCellWithTitle:@"Hide topics tweets" detailTitle:@"Remove all topics tweets from the timeline." key:@"hide_topics" defaultValue:false];
        
        PSSpecifier *videoLayerCaption = [self newSwitchCellWithTitle:@"Disable video layer captions" detailTitle:nil key:@"dis_VODCaptions" defaultValue:false];
        
        PSSpecifier *voice = [self newSwitchCellWithTitle:@"Voice feature" detailTitle:@"Enable voice in tweet and DM." key:@"voice" defaultValue:true];
        
        PSSpecifier *videoZoom = [self newSwitchCellWithTitle:@"Video zoom feature" detailTitle:@"You can zoom the video by double clicking in the center of the video." key:@"video_zoom" defaultValue:false];
        
        PSSpecifier *noHistory = [self newSwitchCellWithTitle:@"No search history" detailTitle:@"Force Twitter to stop recording search history." key:@"no_his" defaultValue:false];
        
        PSSpecifier *bioTranslate = [self newSwitchCellWithTitle:@"Translate bio" detailTitle:@"show you a button in user bio to translate it." key:@"bio_translate" defaultValue:false];
        
        PSSpecifier *likeConfrim = [self newSwitchCellWithTitle:@"Like confirm" detailTitle:@"Show a confirm alert when you press like button." key:@"like_con" defaultValue:false];
        
        PSSpecifier *tweetConfirm = [self newSwitchCellWithTitle:@"Tweet confirm" detailTitle:@"Show a confirm alert when you press tweet button." key:@"tweet_con" defaultValue:false];
        
        PSSpecifier *followConfirm = [self newSwitchCellWithTitle:@"User follow confirm" detailTitle:@"Show a confirm alert when you press follow button." key:@"follow_con" defaultValue:false];
        
        PSSpecifier *padLock = [self newSwitchCellWithTitle:@"Padlock" detailTitle:@"Lock Twitter with passcode." key:@"padlock" defaultValue:false];
        
        PSSpecifier *DmModularSearch = [self newSwitchCellWithTitle:@"Enable DM Modular Search" detailTitle:@"Enable the new UI of DM search." key:@"DmModularSearch" defaultValue:false];
        
        PSSpecifier *autoHighestLoad = [self newSwitchCellWithTitle:@"Auto load photos in highest quality" detailTitle:@"This option let you upload photos and load it in highest quality possible." key:@"autoHighestLoad" defaultValue:true];
        
        PSSpecifier *disableSensitiveTweetWarnings = [self newSwitchCellWithTitle:@"Disable sensitive tweet warning view" detailTitle:nil key:@"disableSensitiveTweetWarnings" defaultValue:true];
        
        PSSpecifier *trustedFriends = [self newSwitchCellWithTitle:@"Enable Twitter Circle feature" detailTitle:nil key:@"TrustedFriends" defaultValue:false];
        
        PSSpecifier *copyProfileInfo = [self newSwitchCellWithTitle:@"Enable Copying profile information feature" detailTitle:@"Add new button in Twitter profile that let you copy whatever info you want." key:@"CopyProfileInfo" defaultValue:false];
        
        PSSpecifier *tweetToImage = [self newSwitchCellWithTitle:@"Save tweet as an image" detailTitle:@"You can export tweets as image, by long pressing on the Tweet Share button." key:@"TweetToImage" defaultValue:false];
        
        PSSpecifier *hideSpace = [self newSwitchCellWithTitle:@"Hide spaces bar" detailTitle:nil key:@"hide_spaces" defaultValue:false];
        
        PSSpecifier *disableRTL = [self newSwitchCellWithTitle:@"Disable RTL" detailTitle:@"Force Twitter use LTR with RTL language.\nRestart Twitter app to apply changes." key:@"dis_rtl" defaultValue:false];
        
        PSSpecifier *alwaysOpenSafari = [self newSwitchCellWithTitle:@"Always open in Safari" detailTitle:@"Force twitter to open URLs in Safari or your default browser." key:@"openInBrowser" defaultValue:false];
        
        // Twitter bule section
        PSSpecifier *undoTweet = [self newSwitchCellWithTitle:@"Undo tweets feature" detailTitle:@"Undo tweets after tweeting." key:@"undo_tweet" defaultValue:false];
        
        PSSpecifier *readerMode = [self newSwitchCellWithTitle:@"Reader mode feature" detailTitle:@"Enable reader mode in threads." key:@"reader_mode" defaultValue:false];
        
        PSSpecifier *appTheme = [self newButtonCellWithTitle:@"Theme" detailTitle:@"Choose a theme color for you Twitter experience that can only be seen by you." dynamicRule:nil action:@selector(showThemeViewController:)];
        
        PSSpecifier *customTabBarVC = [self newButtonCellWithTitle:@"Custom Tab Bar" detailTitle:nil dynamicRule:nil action:@selector(showCustomTabBarVC:)];
        
        // Layout customization section
        PSSpecifier *origTweetStyle = [self newSwitchCellWithTitle:@"Disable edge to edge tweet style" detailTitle:@"Force Twitter to use the original tweet style." key:@"old_style" defaultValue:true];
        
        PSSpecifier *font = [self newSwitchCellWithTitle:@"Enable changing font" detailTitle:@"Option to allow changing Twitter font and show font picker." key:@"en_font" defaultValue:false];
        
        PSSpecifier *regularFontsPicker = [self newButtonCellWithTitle:@"Font" detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_1"] dynamicRule:@"en_font, ==, 0" action:@selector(showRegularFontPicker:)];
        
        PSSpecifier *boldFontsPicker = [self newButtonCellWithTitle:@"Bold Font" detailTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"bhtwitter_font_2"] dynamicRule:@"en_font, ==, 0" action:@selector(showBoldFontPicker:)];
        
        // dubug section
        PSSpecifier *flex = [self newSwitchCellWithTitle:@"Enable FLEX" detailTitle:@"Show FLEX on twitter app." key:@"flex_twitter" defaultValue:false];
        
        // legal section
        PSSpecifier *acknowledgements = [self newButtonCellWithTitle:@"Acknowledgements" detailTitle:nil dynamicRule:nil action:@selector(showAcknowledgements:)];
        
        // dvelopers section
        PSSpecifier *bandarHL = [self newHBTwitterCellWithTitle:@"BandarHelal" twitterUsername:@"BandarHL"];
        PSSpecifier *tipJar = [self newHBLinkCellWithTitle:@"Tip Jar" detailTitle:@"Donate Via Paypal" url:@"https://www.paypal.me/BandarHL"];
        PSSpecifier *sourceCode = [self newHBLinkCellWithTitle:@"BHTwitter" detailTitle:@"Code source of BHTwitter" url:@"https://github.com/BandarHL/BHTwitter/"];
        
        _specifiers = [NSMutableArray arrayWithArray:@[
            
            mainSection, // 0
            download,
            hideAds,
            hideTopics,
            videoLayerCaption,
            directSave,
            voice,
            videoZoom,
            noHistory,
            bioTranslate,
            likeConfrim,
            tweetConfirm,
            followConfirm,
            padLock,
            DmModularSearch,
            autoHighestLoad,
            disableSensitiveTweetWarnings,
            copyProfileInfo,
            tweetToImage,
            hideSpace,
            disableRTL,
            alwaysOpenSafari,
            trustedFriends,
            
            twitterBlueSection, // 1
            undoTweet,
            readerMode,
            appTheme,
            customTabBarVC,
            
            layoutSection, // 2
            origTweetStyle,
            font,
            regularFontsPicker,
            boldFontsPicker,
            
            legalSection, // 3
            acknowledgements,
            
            debug, // 4
            flex,
            
            developer, // 5
            bandarHL,
            tipJar,
            sourceCode
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
    T1RichTextFormatViewController *acknowledgementsVC = [[objc_getClass("T1RichTextFormatViewController") alloc] initWithRichTextFormatDocumentPath:[NSURL bhtwitter_fileURLWithPath:@"Acknowledgements.rtf"].path];
    if (self.twAccount != nil) {
        [acknowledgementsVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"Acknowledgements" subtitle:self.twAccount.displayUsername]];
    }
    [self.navigationController pushViewController:acknowledgementsVC animated:true];
}
- (void)showCustomTabBarVC:(PSSpecifier *)specifier {
    CustomTabBarViewController *customTabBarVC = [[CustomTabBarViewController alloc] init];
    if (self.twAccount != nil) {
        [customTabBarVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"Custom Tab Bar" subtitle:self.twAccount.displayUsername]];
    }
    [self.navigationController pushViewController:customTabBarVC animated:true];
}
- (void)showThemeViewController:(PSSpecifier *)specifier {
    // I create my own Color Theme ViewController for two main reasons:
    // 1- Twitter use swift to build their view controller, so I can't hook anything on it.
    // 2- Twitter knows you do not actually subscribe with Twitter Blue, so it keeps resting the changes and resting 'T1ColorSettingsPrimaryColorOptionKey' key, so I had to create another key to track the original one and keep sure no changes, but it still not enough to keep the new theme after relaunching app, so i had to force the changes again with new lunch.
    BHColorThemeViewController *themeVC = [[BHColorThemeViewController alloc] init];
    if (self.twAccount != nil) {
        [themeVC.navigationItem setTitleView:[objc_getClass("TFNTitleView") titleViewWithTitle:@"Theme" subtitle:self.twAccount.displayUsername]];
    }
    [self.navigationController pushViewController:themeVC animated:true];
}
@end

@implementation BHButtonTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        NSString *subTitle = [specifier.properties[@"subtitle"] copy];
        BOOL isBig = specifier.properties[@"big"] ? ((NSNumber *)specifier.properties[@"big"]).boolValue : NO;
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
        self.detailTextLabel.text = subTitle;
        self.detailTextLabel.numberOfLines = isBig ? 0 : 1;
        self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    return self;
}
@end
