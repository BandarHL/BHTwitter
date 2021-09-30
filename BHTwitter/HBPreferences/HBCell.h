//
//  HPCell.h
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HBPreferences.h"
#import "../Classes/GlobalStateExplorers/RuntimeExplore.h"
#import <SafariServices/SafariServices.h>
#import "ALActionBlocks.h"

typedef void (^HBPValueChanged)(id sender);

@interface HBCell : UITableViewCell
+ (instancetype)initCell;
- (instancetype)init;
- (void)didSelectFromTable:(HBPreferences *)viewController;
- (UIContextMenuConfiguration *)contextMenuConfigurationForRowAtCell:(HBCell *)cell FromTable:(HBPreferences *)viewController;
@property (nonatomic, copy) HBPValueChanged valueChanged;
@end
