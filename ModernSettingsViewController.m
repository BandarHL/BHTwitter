#import "ModernSettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "TWHeaders.h"

@interface ModernSettingsViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) TFNTwitterAccount *account;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;
@end

@implementation ModernSettingsViewController

- (instancetype)initWithAccount:(TFNTwitterAccount *)account {
    self = [super init];
    if (self) {
        self.account = account;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Modern BHTwitter";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];

    id descriptionItem = [[objc_getClass("TFNSettingsDescriptionItem") alloc] initWithText:@"Welcome to the new BHTwitter settings! This is a work in progress." callsToAction:nil];
    id section = @[descriptionItem]; // For now, a section is just an array of items
    self.sections = @[section];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = self.sections[indexPath.section][indexPath.row];
    
    // For now, we only have one type of item. We will expand this.
    if ([item isKindOfClass:objc_getClass("TFNSettingsDescriptionItem")]) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DescriptionCell"];
        cell.textLabel.text = [item text];
        cell.textLabel.numberOfLines = 0;
        return cell;
    }
    
    return [[UITableViewCell alloc] init];
}

@end 