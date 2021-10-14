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
@end
