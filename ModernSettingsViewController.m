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

        // Create and assign the backing store, which is the real data source for the view controller.
        id backingStore = [[objc_getClass("TFNItemsDataViewControllerBackingStore") alloc] init];
        [self setValue:backingStore forKey:@"backingStore"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Modern BHTwitter";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Only configure sections the first time the view appears
    if (self.isMovingToParentViewController) {
        self.title = @"Modern BHTwitter";

        id descriptionItem = [[objc_getClass("TFNSettingsDescriptionItem") alloc] initWithText:@"Welcome to the new BHTwitter settings! This is a work in progress." callsToAction:@[]];
        id section = [[objc_getClass("TFNItemsSection") alloc] initWithItems:@[descriptionItem]];
        
        // Set the sections on the backing store, not the view controller itself.
        id backingStore = [self valueForKey:@"backingStore"];
        [backingStore setValue:@[section] forKey:@"sections"];
    }
}

@end 