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

@interface BHColorThemeViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
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
    [self.colors addObject:[[BHColorThemeItem alloc] initWithColorID:7 name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_7"] color:[UIColor colorFromHexString:@"#FFB6C1"]]];
    [self.colors addObject:[[BHColorThemeItem alloc] initWithColorID:8 name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_8"] color:[UIColor colorFromHexString:@"#8B0000"]]];
    
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
    BHColorThemeItem *currCell = self.colors[indexPath.row];
    
    cell.colorLabel.text = currCell.name;
    cell.colorLabel.backgroundColor = currCell.color;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"bh_color_theme_selectedColor"] != nil) {
        NSInteger selectedColor = [[NSUserDefaults standardUserDefaults] integerForKey:@"bh_color_theme_selectedColor"];
        
        switch (selectedColor) {
            case 1:
                if (currCell.colorID == selectedColor) {
                    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull colorCell, NSUInteger idx, BOOL * _Nonnull stop) {
                        BHColorThemeCell *cCell = (BHColorThemeCell *)colorCell;
                        cCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
                    }];
                    cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
                }
            case 2:
                if (currCell.colorID == selectedColor) {
                    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull colorCell, NSUInteger idx, BOOL * _Nonnull stop) {
                        BHColorThemeCell *cCell = (BHColorThemeCell *)colorCell;
                        cCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
                    }];
                    cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
                }
            case 3:
                if (currCell.colorID == selectedColor) {
                    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull colorCell, NSUInteger idx, BOOL * _Nonnull stop) {
                        BHColorThemeCell *cCell = (BHColorThemeCell *)colorCell;
                        cCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
                    }];
                    cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
                }
            case 4:
                if (currCell.colorID == selectedColor) {
                    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull colorCell, NSUInteger idx, BOOL * _Nonnull stop) {
                        BHColorThemeCell *cCell = (BHColorThemeCell *)colorCell;
                        cCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
                    }];
                    cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
                }
            case 5:
                if (currCell.colorID == selectedColor) {
                    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull colorCell, NSUInteger idx, BOOL * _Nonnull stop) {
                        BHColorThemeCell *cCell = (BHColorThemeCell *)colorCell;
                        cCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
                    }];
                    cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
                }
            case 6:
                if (currCell.colorID == selectedColor) {
                    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull colorCell, NSUInteger idx, BOOL * _Nonnull stop) {
                        BHColorThemeCell *cCell = (BHColorThemeCell *)colorCell;
                        cCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
                    }];
                    cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
                }
            case 7:
                if (currCell.colorID == selectedColor) {
                    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull colorCell, NSUInteger idx, BOOL * _Nonnull stop) {
                        BHColorThemeCell *cCell = (BHColorThemeCell *)colorCell;
                        cCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
                    }];
                    cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
                }
            case 8:
                if (currCell.colorID == selectedColor) {
                    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull colorCell, NSUInteger idx, BOOL * _Nonnull stop) {
                        BHColorThemeCell *cCell = (BHColorThemeCell *)colorCell;
                        cCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
                    }];
                    cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
                }
            default:
                break;
        }
    } else {
        if (currCell.colorID == 0) {
            cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
        }
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    BHColorThemeItem *colorItem = self.colors[indexPath.row];
    
    [collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull colorCell, NSUInteger idx, BOOL * _Nonnull stop) {
        BHColorThemeCell *cCell = (BHColorThemeCell *)colorCell;
        cCell.checkIMG.image = [UIImage systemImageNamed:@"circle"];
    }];
    
    BHColorThemeCell *currCell = (BHColorThemeCell *)[collectionView cellForItemAtIndexPath:indexPath];
    currCell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
    
    [[NSUserDefaults standardUserDefaults] setInteger:colorItem.colorID forKey:@"bh_color_theme_selectedColor"];
    BH_changeTwitterColor(colorItem.colorID);

    // Manually trigger tab bar icon refresh
    Class t1TabBarVCClass = NSClassFromString(@"T1TabBarViewController");
    if (t1TabBarVCClass) {
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    // Check if the scene's delegate responds to window selector or if the scene itself has windows
                    if ([scene.delegate respondsToSelector:@selector(window)]) {
                         window = [(id)scene.delegate window];
                    } else if ([scene respondsToSelector:@selector(windows)]) {
                        // For scenes directly managing windows (e.g. iPad with multiple windows)
                        for (UIWindow *sceneWindow in [(id)scene windows]) {
                            if (sceneWindow.isKeyWindow) {
                                window = sceneWindow;
                                break;
                            }
                        }
                        // Fallback to the first window if no key window is found (less ideal)
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
