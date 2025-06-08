#import "ModernSettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "TWHeaders.h"

@interface ModernSettingsViewController ()
@end

@implementation ModernSettingsViewController

- (instancetype)initWithAccount:(TFNTwitterAccount *)account {
    self = [super init];
    if (self) {
        [self setAccount:account];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Modern BHTwitter";

    id descriptionItem = [[objc_getClass("TFNSettingsDescriptionItem") alloc] initWithText:@"Welcome to the new BHTwitter settings! This is a work in progress." callsToAction:nil];

    id section = [objc_getClass("TFNItemsDataViewSection") sectionWithItem:descriptionItem];

    self.sections = @[
        section
    ];
}

@end 