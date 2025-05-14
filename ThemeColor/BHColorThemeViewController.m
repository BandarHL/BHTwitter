//
//  BHColorThemeViewController.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import "BHColorThemeViewController.h"
#import "BHColorThemeCell.h"
#import "BHColorThemeItem.h"
#import "../BHTBundle/BHTBundle.h"
#import "../Colours/Colours.h"
#import "../TWHeaders.h"

// Define a constant for the custom theme ID
#define CUSTOM_THEME_ID 7
#define CUSTOM_THEME_HEX_KEY @"bh_color_theme_customColorHex"
#define BHTColorThemeDidChangeNotificationName @"BHTColorThemeDidChangeNotification"

@interface BHColorThemeViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) UICollectionView *colorCollectionView;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) NSMutableArray<BHColorThemeItem *> *colors;
@end

@implementation BHColorThemeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.headerLabel = [[UILabel alloc] init];
    self.headerLabel.text = [[BHTBundle sharedBundle] localizedStringForKey:@"APP_ICON_HEADER_TITLE"];
    self.headerLabel.textColor = [UIColor secondaryLabelColor];
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.font = [UIFont systemFontOfSize:15];
    self.headerLabel.textAlignment = NSTextAlignmentJustified;
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    self.colorCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:flowLayout];
    self.colorCollectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
    [self.colorCollectionView registerClass:[BHColorThemeCell class] forCellWithReuseIdentifier:[BHColorThemeCell reuseIdentifier]];
    self.colorCollectionView.delegate = self;
    self.colorCollectionView.dataSource = self;
    self.colorCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.colors = [NSMutableArray new];
    [self.colors addObject:[[BHColorThemeItem alloc] initWithColorID:1 name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_1"] color:[UIColor colorFromHexString:@"#1D9BF0"]]];
    [self.colors addObject:[[BHColorThemeItem alloc] initWithColorID:2 name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_2"] color:[UIColor colorFromHexString:@"#FFD400"]]];
    [self.colors addObject:[[BHColorThemeItem alloc] initWithColorID:3 name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_3"] color:[UIColor colorFromHexString:@"#F91880"]]];
    [self.colors addObject:[[BHColorThemeItem alloc] initWithColorID:4 name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_4"] color:[UIColor colorFromHexString:@"#7856FF"]]];
    [self.colors addObject:[[BHColorThemeItem alloc] initWithColorID:5 name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_5"] color:[UIColor colorFromHexString:@"#FF7A00"]]];
    [self.colors addObject:[[BHColorThemeItem alloc] initWithColorID:6 name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_6"] color:[UIColor colorFromHexString:@"#00BA7C"]]];
    
    // Add Custom Color Option
    NSString *customColorLabel = [[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_CUSTOM"];
    UIColor *customColorPlaceholder = [UIColor colorWithWhite:0.8 alpha:1.0]; // Placeholder color
    [self.colors addObject:[[BHColorThemeItem alloc] initWithColorID:CUSTOM_THEME_ID name:customColorLabel color:customColorPlaceholder]];

    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.headerLabel];
    [self.view addSubview:self.colorCollectionView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.headerLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.headerLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.headerLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [self.colorCollectionView.topAnchor constraintEqualToAnchor:self.headerLabel.bottomAnchor],
        [self.colorCollectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.colorCollectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.colorCollectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.colors.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BHColorThemeCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[BHColorThemeCell reuseIdentifier] forIndexPath:indexPath];
    BHColorThemeItem *currCellItem = self.colors[indexPath.row];
    
    cell.colorLabel.text = currCellItem.name;
    cell.colorLabel.backgroundColor = currCellItem.color;
    cell.checkIMG.image = [UIImage systemImageNamed:@"circle"];

    NSInteger selectedColorID = -1;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"]) {
        selectedColorID = [[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"];
    }

    if (currCellItem.colorID == CUSTOM_THEME_ID) {
        // Special handling for the custom color cell
        if (selectedColorID == CUSTOM_THEME_ID) {
            NSString *customHex = [[NSUserDefaults standardUserDefaults] stringForKey:CUSTOM_THEME_HEX_KEY];
            if (customHex && customHex.length > 0) {
                UIColor *customColor = [UIColor colorFromHexString:customHex];
                if (customColor) {
                    cell.colorLabel.backgroundColor = customColor;
                }
            }
            cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
        } else {
            cell.colorLabel.backgroundColor = currCellItem.color;
        }
    } else {
        // Predefined colors
        if (currCellItem.colorID == selectedColorID) {
            cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
        }
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    BHColorThemeItem *colorItem = self.colors[indexPath.row];

    if (colorItem.colorID == CUSTOM_THEME_ID) {
        UIColorPickerViewController *colorPicker = [[UIColorPickerViewController alloc] init];
        colorPicker.delegate = self;
        colorPicker.supportsAlpha = NO;

        NSString *currentCustomHex = [[NSUserDefaults standardUserDefaults] stringForKey:CUSTOM_THEME_HEX_KEY];
        if (currentCustomHex) {
            colorPicker.selectedColor = [UIColor colorFromHexString:currentCustomHex];
        }
        [self presentViewController:colorPicker animated:YES completion:nil];

    } else {
        // Predefined color selected
        [[NSUserDefaults standardUserDefaults] setInteger:colorItem.colorID forKey:@"bh_color_theme_selectedColor"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CUSTOM_THEME_HEX_KEY];
        [[NSNotificationCenter defaultCenter] postNotificationName:BHTColorThemeDidChangeNotificationName object:nil];
        [self.colorCollectionView reloadData];
        [self triggerFullThemeUpdate];
    }
}

//MARK: - UIColorPickerViewControllerDelegate

- (void)colorPickerViewControllerDidFinishPicking:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)){
    UIColor *selectedColor = viewController.selectedColor;
    NSString *hexString = [selectedColor hexString];

    [[NSUserDefaults standardUserDefaults] setObject:hexString forKey:CUSTOM_THEME_HEX_KEY];
    [[NSUserDefaults standardUserDefaults] setInteger:CUSTOM_THEME_ID forKey:@"bh_color_theme_selectedColor"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:BHTColorThemeDidChangeNotificationName object:nil];
    
    [viewController dismissViewControllerAnimated:YES completion:^{
        // Reload data and trigger theme update AFTER the picker is dismissed
        [self.colorCollectionView reloadData];
        [self triggerFullThemeUpdate];
    }];
}

// Helper method to trigger full theme update for tab bar etc.
- (void)triggerFullThemeUpdate {
    Class t1TabBarVCClass = NSClassFromString(@"T1TabBarViewController");
    if (t1TabBarVCClass) {
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    if ([scene.delegate respondsToSelector:@selector(window)]) {
                         window = [(id)scene.delegate window];
                    } else if ([scene respondsToSelector:@selector(windows)]) {
                        for (UIWindow *sceneWindow in [(id)scene windows]) {
                            if (sceneWindow.isKeyWindow) {
                                window = sceneWindow;
                                break;
                            }
                        }
                        if (!window && [[(id)scene windows] count] > 0) {
                            window = [[(id)scene windows] firstObject];
                        }
                    }
                    if(window) break; 
                }
            }
        } else {
            #pragma GCC diagnostic push
            #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            window = UIApplication.sharedApplication.keyWindow;
            #pragma GCC diagnostic pop
        }

        if (window && window.rootViewController) {
            NSMutableArray *controllersToVisit = [NSMutableArray arrayWithObject:window.rootViewController];
            while (controllersToVisit.count > 0) {
                UIViewController *currentVC = [controllersToVisit firstObject];
                [controllersToVisit removeObjectAtIndex:0];

                if ([currentVC isKindOfClass:t1TabBarVCClass]) {
                    if ([currentVC respondsToSelector:@selector(tabViews)]) {
                        NSArray *tabViews = [currentVC valueForKey:@"tabViews"];
                        for (id tabView in tabViews) {
                            if ([tabView respondsToSelector:@selector(bh_applyCurrentThemeToIcon)]) {
                                [tabView performSelector:@selector(bh_applyCurrentThemeToIcon)];
                            }
                        }
                    }
                }

                if (currentVC.presentedViewController) {
                    [controllersToVisit addObject:currentVC.presentedViewController];
                }
                if ([currentVC isKindOfClass:[UINavigationController class]]) {
                    [controllersToVisit addObjectsFromArray:((UINavigationController*)currentVC).viewControllers];
                }
                if ([currentVC isKindOfClass:[UITabBarController class]]) {
                    [controllersToVisit addObjectsFromArray:((UITabBarController*)currentVC).viewControllers];
                }
                for (UIViewController *childVC in currentVC.childViewControllers) {
                    [controllersToVisit addObject:childVC];
                }
            }
        }
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(16, 16, 16, 16);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(98, 74);
}

@end
