//
//  HPCell.h
//  Cephei

#import <UIKit/UIKit.h>
#import "../BHTwitter+UIImage.h"
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
