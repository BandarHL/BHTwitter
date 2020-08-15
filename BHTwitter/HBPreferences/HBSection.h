//
//  HBSection.h
//  Cephei
//
//  Created by BandarHelal on 04/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HBSection : UITableViewCell
@property (nonatomic, strong) NSString *headerTitle;
@property (nonatomic, strong) NSString *footerTitle;
@property (nonatomic, strong) NSMutableArray *cells;
+ (instancetype)sectionWithTitle:(NSString *)title footer:(NSString *)footer;
- (void)addCell:(UITableViewCell *)cell;
@end
