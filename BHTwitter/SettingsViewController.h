//
//  SettingsViewController.h
//  FlexCrack
//
//  Created by BandarHelal on 25/11/2021.
//

#import "TWHeaders.h"
#import <CepheiPrefs/CepheiPrefs.h>
#import <Cephei/HBPreferences.h>

typedef NS_ENUM(NSInteger, DynamicSpecifierOperatorType) {
  EqualToOperatorType,
  NotEqualToOperatorType,
  GreaterThanOperatorType,
  LessThanOperatorType,
};

@interface SettingsViewController : HBListController
- (instancetype)initWithTwitterAccount:(TFNTwitterAccount *)account;
@end

@interface BHButtonTableViewCell : HBTintedTableCell
@end

@interface BHSwitchTableCell : PSSwitchTableCell
@end
