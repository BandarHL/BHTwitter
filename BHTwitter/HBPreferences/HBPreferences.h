//
//  HBPreferences.h
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HBPreferences : UITableViewController
@property (nonatomic, strong) NSArray *sections;
+ (instancetype)tableWithSections:(NSArray *)sections title:(NSString *)title TableStyle:(UITableViewStyle *)style SeparatorStyle:(UITableViewCellSeparatorStyle)SeparatorStyle;

@end
