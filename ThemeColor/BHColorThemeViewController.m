//
//  BHColorThemeViewController.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//  Modified by actuallyaridan on 25/05/2025.
//

#import "BHColorThemeViewController.h"
#import "BHColorThemeCell.h"
#import "BHColorThemeItem.h"
#import "../BHTBundle/BHTBundle.h"
#import "../Colours/Colours.h"
#import "../TWHeaders.h"
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TwitterFontStyle) {
    TwitterFontStyleRegular,
    TwitterFontStyleSemibold,
    TwitterFontStyleBold
};

static UIFont *TwitterChirpFont(TwitterFontStyle style) {
    switch (style) {
        case TwitterFontStyleBold:
            return [UIFont fontWithName:@"ChirpUIVF_wght3200000_opsz150000" size:17]
                   ?: [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
        case TwitterFontStyleSemibold:
            return [UIFont fontWithName:@"ChirpUIVF_wght2BC0000_opszE0000" size:14]
                   ?: [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        case TwitterFontStyleRegular:
        default:
            return [UIFont fontWithName:@"ChirpUIVF_wght1900000_opszE0000" size:12]
                   ?: [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    }
}

@interface BHColorThemeViewController () <
    UICollectionViewDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout
>
@property (nonatomic, strong) UICollectionView *colorCollectionView;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) NSMutableArray<BHColorThemeItem *> *colors;
@end

@implementation BHColorThemeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Header label (below nav bar)
    self.headerLabel = [UILabel new];
    self.headerLabel.text =
      [[BHTBundle sharedBundle] localizedStringForKey:@"THEME_SETTINGS_NAVIGATION_DETAIL"];
    self.headerLabel.textColor    = [UIColor secondaryLabelColor];
    self.headerLabel.numberOfLines = 0;
    // use Chirp regular font at size 15
    self.headerLabel.font =
      [TwitterChirpFont(TwitterFontStyleRegular) fontWithSize:13];
    // left-aligned, wrap words
    self.headerLabel.textAlignment = NSTextAlignmentLeft;
    self.headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // Collection view layout
    UICollectionViewFlowLayout *flowLayout = [UICollectionViewFlowLayout new];
    flowLayout.sectionInset = UIEdgeInsetsMake(16,16,16,16);
    flowLayout.minimumLineSpacing      = 10;
    flowLayout.minimumInteritemSpacing = 10;

    // Collection view itself
    self.colorCollectionView = [[UICollectionView alloc]
      initWithFrame:CGRectZero
      collectionViewLayout:flowLayout];
    self.colorCollectionView.contentInsetAdjustmentBehavior =
      UIScrollViewContentInsetAdjustmentAlways;
    [self.colorCollectionView
      registerClass:[BHColorThemeCell class]
      forCellWithReuseIdentifier:[BHColorThemeCell reuseIdentifier]];
    self.colorCollectionView.delegate   = self;
    self.colorCollectionView.dataSource = self;
    self.colorCollectionView.translatesAutoresizingMaskIntoConstraints = NO;

    // Data source
    self.colors = [NSMutableArray new];
    [self.colors addObject:
      [[BHColorThemeItem alloc]
        initWithColorID:1
                    name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_1"]
                   color:[UIColor colorFromHexString:@"#1D9BF0"]]];
    [self.colors addObject:
      [[BHColorThemeItem alloc]
        initWithColorID:2
                    name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_2"]
                   color:[UIColor colorFromHexString:@"#FFD400"]]];
    [self.colors addObject:
      [[BHColorThemeItem alloc]
        initWithColorID:3
                    name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_3"]
                   color:[UIColor colorFromHexString:@"#F91880"]]];
    [self.colors addObject:
      [[BHColorThemeItem alloc]
        initWithColorID:4
                    name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_4"]
                   color:[UIColor colorFromHexString:@"#7856FF"]]];
    [self.colors addObject:
      [[BHColorThemeItem alloc]
        initWithColorID:5
                    name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_5"]
                   color:[UIColor colorFromHexString:@"#FF7A00"]]];
    [self.colors addObject:
      [[BHColorThemeItem alloc]
        initWithColorID:6
                    name:[[BHTBundle sharedBundle] localizedStringForKey:@"THEME_OPTION_6"]
                   color:[UIColor colorFromHexString:@"#00BA7C"]]];

    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.headerLabel];
    [self.view addSubview:self.colorCollectionView];

    [NSLayoutConstraint activateConstraints:@[
        // header at top
        [self.headerLabel.topAnchor
            constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.headerLabel.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.headerLabel.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        // collection view below header
        [self.colorCollectionView.topAnchor
            constraintEqualToAnchor:self.headerLabel.bottomAnchor constant:8],
        [self.colorCollectionView.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],
        [self.colorCollectionView.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],
        [self.colorCollectionView.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self hideFloatingActionButtonIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self hideFloatingActionButtonIfNeeded];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.colors.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BHColorThemeCell *cell =
      [collectionView dequeueReusableCellWithReuseIdentifier:
        [BHColorThemeCell reuseIdentifier]
                                                 forIndexPath:indexPath];
    BHColorThemeItem *item = self.colors[indexPath.item];

    // label text + force white text
    cell.colorLabel.text = item.name;
    cell.colorLabel.font = TwitterChirpFont(TwitterFontStyleSemibold);
    cell.colorLabel.textColor = [UIColor whiteColor];
    cell.colorLabel.textAlignment = NSTextAlignmentCenter;
    // background as item.color
    cell.colorLabel.backgroundColor = item.color;

    // checkmark logic
    NSInteger selected = [[NSUserDefaults standardUserDefaults]
                           integerForKey:@"bh_color_theme_selectedColor"];
    [collectionView.visibleCells
      enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHColorThemeCell*)c).checkIMG.image =
          [UIImage systemImageNamed:@"circle"];
    }];
    if (item.colorID == selected) {
        cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];
    }

    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    BHColorThemeItem *item = self.colors[indexPath.item];
    // reset all
    [collectionView.visibleCells
      enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell *c, NSUInteger idx, BOOL *stop) {
        ((BHColorThemeCell*)c).checkIMG.image =
          [UIImage systemImageNamed:@"circle"];
    }];
    // mark this one
    BHColorThemeCell *cell =
      (BHColorThemeCell*)[collectionView cellForItemAtIndexPath:indexPath];
    cell.checkIMG.image = [UIImage systemImageNamed:@"checkmark.circle"];

    [[NSUserDefaults standardUserDefaults]
      setInteger:item.colorID forKey:@"bh_color_theme_selectedColor"];
    BH_changeTwitterColor(item.colorID);

    // trigger tab bar refresh (unchanged)…
    Class t1TabBarVCClass = NSClassFromString(@"T1TabBarViewController");
    if (!t1TabBarVCClass) return;
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                if ([scene.delegate respondsToSelector:@selector(window)]) {
                    window = [(id)scene.delegate window];
                } else {
                    for (UIWindow *w in [(id)scene windows]) {
                        if (w.isKeyWindow) { window = w; break; }
                    }
                }
                if (window) break;
            }
        }
    } else {
        window = UIApplication.sharedApplication.keyWindow;
    }
    if (!window) return;
    NSMutableArray *stack = [NSMutableArray arrayWithObject:window.rootViewController];
    while (stack.count) {
        UIViewController *vc = stack.firstObject;
        [stack removeObjectAtIndex:0];
        if ([vc isKindOfClass:t1TabBarVCClass] &&
            [vc respondsToSelector:@selector(tabViews)]) {
            for (id tab in [vc valueForKey:@"tabViews"]) {
                if ([tab respondsToSelector:@selector(bh_applyCurrentThemeToIcon)]) {
                    [tab performSelector:@selector(bh_applyCurrentThemeToIcon)];
                }
            }
        }
        if (vc.presentedViewController) [stack addObject:vc.presentedViewController];
        if ([vc isKindOfClass:[UINavigationController class]])
            [stack addObjectsFromArray:((UINavigationController*)vc).viewControllers];
        if ([vc isKindOfClass:[UITabBarController class]])
            [stack addObjectsFromArray:((UITabBarController*)vc).viewControllers];
        [stack addObjectsFromArray:vc.childViewControllers];
    }
}

#pragma mark – FlowLayout sizing

- (UIEdgeInsets)collectionView:(UICollectionView*)collectionView
                        layout:(UICollectionViewLayout*)layout
        insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(16, 16, 16, 16);
}

- (CGFloat)collectionView:(UICollectionView*)collectionView
                   layout:(UICollectionViewLayout*)layout
minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGFloat)collectionView:(UICollectionView*)collectionView
                   layout:(UICollectionViewLayout*)layout
minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGSize)collectionView:(UICollectionView*)collectionView
                  layout:(UICollectionViewLayout*)layout
  sizeForItemAtIndexPath:(NSIndexPath*)indexPath {
    return CGSizeMake(98, 74);
}

@end
