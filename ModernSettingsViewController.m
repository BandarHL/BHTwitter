#import "ModernSettingsViewController.h"
#import "BHTBundle/BHTBundle.h"
#import "TWHeaders.h"
#import <objc/runtime.h>

@interface ModernSettingsViewController ()
// All properties are in the header or superclass now
@end

@implementation ModernSettingsViewController

+ (void)load {
    Class superclass = objc_getClass("TFNItemsDataViewController");
    if (superclass) {
        class_setSuperclass(self, superclass);
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"[BHTwitter] Initializing ModernSettingsViewController as a TFNItemsDataViewController subclass.");
        // The account will be set after initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Modern BHTwitter";

    id descriptionItem = [[objc_getClass("TFNSettingsDescriptionItem") alloc] initWithText:@"Welcome to the new BHTwitter settings! This is a work in progress." callsToAction:@[]];
    id section = [[objc_getClass("TFNItemsSection") alloc] initWithItems:@[descriptionItem]];
    [self setValue:@[section] forKey:@"sections"];
}

@end 