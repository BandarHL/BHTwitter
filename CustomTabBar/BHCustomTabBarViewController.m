//
//  BHCustomTabBarViewController.m
//  NeoFeeBird
//
//  Created by Bandar Alruwaili on 11/12/2023.
//  Modified by actuallyaridan on 28/04/2025.
//

#import "BHCustomTabBarViewController.h"
#import "BHCustomTabBarUtility.h"
#import "../BHTBundle/BHTBundle.h"
#import "Colours/Colours.h" 

// Declare the TwitterChirpFont here (or import it if it already exists)
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

@interface BHCustomTabBarViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray <BHCustomTabBarSection *> *data;
@end

@implementation BHCustomTabBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.dragInteractionEnabled = YES;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.editing = YES;

    // Style
    self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    self.tableView.separatorColor = [UIColor separatorColor];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
    self.tableView.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 16);
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.data = [NSMutableArray new];
    [self getData];
    [self.tableView reloadData];
    [self resetSettingsBarButton];
}

- (void)resetSettingsBarButton {
    UIBarButtonItem *resetButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"trash"] style:UIBarButtonItemStylePlain target:self action:@selector(resetSettingsBarButtonHandler:)];
    self.navigationItem.rightBarButtonItem = resetButton;
}

- (void)resetSettingsBarButtonHandler:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BHTwitter"
                                                                   message:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_REST_MESSAGE"]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"YES_BUTTON_TITLE"]
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"allowed"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"hidden"];
        [self getData];
        [self.tableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"NO_BUTTON_TITLE"]
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (NSArray<BHCustomTabBarItem *> *)getItemsForKey:(NSString *)key {
    NSData *savedItems = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (savedItems) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:savedItems];
    }
    return nil;
}

- (void)getData {
    NSArray<BHCustomTabBarItem *> *savedAllowedArr = [self getItemsForKey:@"allowed"];
    NSArray<BHCustomTabBarItem *> *savedHiddenArr = [self getItemsForKey:@"hidden"];

    if (savedAllowedArr && savedHiddenArr) {
        self.data = [@[
            [[BHCustomTabBarSection alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_SECTION_1_TITLE"] items:savedAllowedArr],
            [[BHCustomTabBarSection alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_SECTION_2_TITLE"] items:savedHiddenArr]
        ] mutableCopy];
    } else {
        self.data = [@[
            [[BHCustomTabBarSection alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_SECTION_1_TITLE"] items:@[
                [[BHCustomTabBarItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_1"] pageID:@"home"],
                [[BHCustomTabBarItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_2"] pageID:@"guide"],
                [[BHCustomTabBarItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_3"] pageID:@"audiospace"],
                [[BHCustomTabBarItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_4"] pageID:@"communities"],
                [[BHCustomTabBarItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_5"] pageID:@"ntab"],
                [[BHCustomTabBarItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_6"] pageID:@"messages"],
                [[BHCustomTabBarItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_7"] pageID:@"grok"],
                [[BHCustomTabBarItem alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_OPTION_8"] pageID:@"media"]
            ]],
            [[BHCustomTabBarSection alloc] initWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"CUSTOM_TAB_BAR_SECTION_2_TITLE"] items:@[]]
        ] mutableCopy];
    }
}

- (void)updateData {
    [self.data[0] saveItemsForKey:@"allowed"];
    [self.data[1] saveItemsForKey:@"hidden"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.data.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.data[section].items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = self.data[indexPath.section].items[indexPath.row].title;

    // Style each cell properly
    cell.backgroundColor = [UIColor systemBackgroundColor];
    cell.textLabel.font = TwitterChirpFont(TwitterFontStyleSemibold);
    cell.textLabel.textColor = [UIColor labelColor];

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.data[section].title;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (indexPath.section == 0) ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleInsert;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        BHCustomTabBarItem *item = self.data[indexPath.section].items[indexPath.row];
        [self.data[1].items addObject:item];
        [self.data[indexPath.section].items removeObjectAtIndex:indexPath.row];
        [tableView moveRowAtIndexPath:indexPath toIndexPath:[NSIndexPath indexPathForRow:(self.data[1].items.count - 1) inSection:1]];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        BHCustomTabBarItem *item = self.data[indexPath.section].items[indexPath.row];
        [self.data[0].items addObject:item];
        [self.data[indexPath.section].items removeObjectAtIndex:indexPath.row];
        [tableView moveRowAtIndexPath:indexPath toIndexPath:[NSIndexPath indexPathForRow:(self.data[0].items.count - 1) inSection:0]];
    }
    [self updateData];
}

@end
