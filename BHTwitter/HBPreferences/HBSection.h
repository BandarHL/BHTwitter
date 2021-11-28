//
//  HBSection.h
//  Cephei

#import <UIKit/UIKit.h>

@interface HBSection : UITableViewCell
@property (nonatomic, strong) NSString *headerTitle;
@property (nonatomic, strong) NSString *footerTitle;
@property (nonatomic, strong) NSMutableArray *cells;
+ (instancetype)sectionWithTitle:(NSString *)title footer:(NSString *)footer;
- (void)addCell:(UITableViewCell *)cell;
- (void)removeCell:(UITableViewCell *)cell;
- (void)addCells:(NSArray <UITableViewCell *> *)cells;
- (void)removeCells:(NSArray <UITableViewCell *> *)cells;
@end
