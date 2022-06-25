//
//  AuthViewController.m
//  BHTwitter
//
//  Created by BandarHelal on 25/09/2021.
//

#import "AuthViewController.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "keychain.h"

@interface AuthViewController ()

@end

@implementation AuthViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    LAContext *context = [[LAContext alloc] init];
    if ([self canEvaluateBiometrics]) {
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:@"Touch ID or Face ID is required to use Twitter" reply:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                [[keychain shared] saveDictionary:@{@"isAuthenticated": @YES}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self dismissViewControllerAnimated:true completion:nil];
                });
            } else {
                [[keychain shared] saveDictionary:@{@"isAuthenticated": @NO}];
                NSLog(@"%@", error);
            }
        }];
    } else if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:nil]) {
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:@"Passcode is required to use Twitter" reply:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                [[keychain shared] saveDictionary:@{@"isAuthenticated": @YES}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self dismissViewControllerAnimated:true completion:nil];
                });
            } else {
                [[keychain shared] saveDictionary:@{@"isAuthenticated": @NO}];
                NSLog(@"%@", error);
            }
        }];
    } else {
        [[keychain shared] saveDictionary:@{@"isAuthenticated": @NO}];
    }
}

- (BOOL)canEvaluateBiometrics {
    NSMutableDictionary *infoPlistDict = [NSMutableDictionary dictionaryWithDictionary:[[NSBundle mainBundle] infoDictionary]];
    return [infoPlistDict objectForKey:@"NSFaceIDUsageDescription"] != nil ? true : false;
}
@end
