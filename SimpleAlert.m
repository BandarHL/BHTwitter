#import "SimpleAlert.h"

@interface SimpleAlert ()
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) NSString *messageText;
@property (nonatomic, strong) NSMutableArray<SimpleAlertButton *> *buttons;
@end

@implementation SimpleAlertButton

- (instancetype)initWithTitle:(NSString *)title {
    if (self = [super init]) {
        self.title = title;
        self.isCancel = NO;
    }
    return self;
}

- (SimpleAlertButton *)handler:(SimpleAlertHandler)handler {
    self.handler = handler;
    return self;
}

- (SimpleAlertButton *)cancelStyle {
    self.isCancel = YES;
    return self;
}

@end

@implementation SimpleAlert

+ (void)makeAlert:(void (^)(SimpleAlert *make))block showFrom:(UIViewController *)viewController {
    SimpleAlert *alert = [[SimpleAlert alloc] init];
    alert.buttons = [NSMutableArray array];
    block(alert);
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:alert.titleText
                                                                             message:alert.messageText
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    for (SimpleAlertButton *btn in alert.buttons) {
        UIAlertActionStyle style = btn.isCancel ? UIAlertActionStyleCancel : UIAlertActionStyleDefault;
        UIAlertAction *action = [UIAlertAction actionWithTitle:btn.title style:style handler:^(UIAlertAction * _Nonnull action) {
            if (btn.handler) {
                btn.handler(@[btn.title]);
            }
        }];
        [alertController addAction:action];
    }
    
    [viewController presentViewController:alertController animated:YES completion:nil];
}

- (void)title:(NSString *)title {
    self.titleText = title;
}

- (void)message:(NSString *)message {
    self.messageText = message;
}

- (SimpleAlertButton *)button:(NSString *)title {
    SimpleAlertButton *btn = [[SimpleAlertButton alloc] initWithTitle:title];
    [self.buttons addObject:btn];
    return btn;
}

@end