#import "ModernSettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "TWHeaders.h"

@interface ModernSettingsViewController ()
@property (nonatomic, strong) TFNTwitterAccount *account;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) id descriptionAdapter;
@end

@implementation ModernSettingsViewController

- (instancetype)initWithAccount:(TFNTwitterAccount *)account {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        NSLog(@"[BHTwitter] Initializing ModernSettingsViewController as a UITableViewController subclass.");
        self.account = account;
        self.descriptionAdapter = [[objc_getClass("TFNSettingsDescriptionItemTableRowAdapter") alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Modern BHTwitter";
    self.view.backgroundColor = [UIColor blueColor]; 
    self.tableView.backgroundColor = [UIColor greenColor];
    // id descriptionItem = [[objc_getClass("TFNSettingsDescriptionItem") alloc] initWithText:@"Welcome to the new BHTwitter settings! This is a work in progress." callsToAction:nil];
    // id section = @[descriptionItem];
    // self.sections = @[section];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // id item = self.sections[indexPath.section][indexPath.row];
    
    // For now, we only have one type of item. We will expand this.
    // if ([item isKindOfClass:objc_getClass("TFNSettingsDescriptionItem")]) {
    //     return [self.descriptionAdapter dataViewController:self tableViewCellForItem:item withOptions:nil atIndexPath:indexPath];
    // }
    
    return [[UITableViewCell alloc] init];
}

@end 