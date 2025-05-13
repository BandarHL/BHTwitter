// Simple Alert class like FLEXAlert
// https://github.com/FLEXTool/FLEX/blob/2bfba6715eff664ef84a02e8eb0ad9b5a609c684/Classes/Utility/FLEXAlert.h

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SimpleAlertHandler)(NSArray<NSString *> *strings);

@interface SimpleAlertButton : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) SimpleAlertHandler handler;
@property (nonatomic, assign) BOOL isCancel;
- (SimpleAlertButton *)handler:(SimpleAlertHandler)handler;
- (SimpleAlertButton *)cancelStyle;
@end

@interface SimpleAlert : NSObject
+ (void)makeAlert:(void (^)(SimpleAlert *make))block showFrom:(UIViewController *)viewController;
- (void)title:(NSString *)title;
- (void)message:(NSString *)message;
- (SimpleAlertButton *)button:(NSString *)title;
@end

NS_ASSUME_NONNULL_END