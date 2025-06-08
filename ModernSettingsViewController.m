#import "ModernSettingsViewController.h"
#import "BHTBundle/BHTBundle.h"

@interface ModernSettingsViewController ()
@property (nonatomic, strong) TFNTwitterAccount *account;
@end

@implementation ModernSettingsViewController

- (instancetype)initWithAccount:(TFNTwitterAccount *)account {
    self = [super init];
    if (self) {
        _account = account;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    if (self.account) {
        self.title = [NSString stringWithFormat:@"Modern Settings (%@)", self.account.displayUsername];
    } else {
        self.title = @"Modern Settings";
    }
}

@end 