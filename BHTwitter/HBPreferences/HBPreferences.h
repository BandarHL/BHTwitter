//
//  HBPreferences.h
//  Cephei
#import <UIKit/UIKit.h>

@interface HBPreferences : UITableViewController
@property (nonatomic, strong) NSArray *sections;
+ (instancetype)tableWithSections:(NSArray *)sections title:(NSString *)title TableStyle:(UITableViewStyle)style SeparatorStyle:(UITableViewCellSeparatorStyle)SeparatorStyle;
- (instancetype)initTableWithTableStyle:(UITableViewStyle)style title:(NSString *)title SeparatorStyle:(UITableViewCellSeparatorStyle)SeparatorStyle;
- (void)addSections:(NSArray *)sections;
@end
