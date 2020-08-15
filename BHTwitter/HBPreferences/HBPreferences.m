//
//  HBPreferences.m
//  Cephei
//
//  Created by BandarHelal on 03/05/1441 AH.
//  Copyright © 1441 BandarHelal. All rights reserved.
//

#import "HBPreferences.h"
#import "HBCell.h"
#import "HBSection.h"
#import "HBTwitterCell.h"
#import "HBGithubCell.h"
#import "HBLinkCell.h"
#import "HBSwitchCell.h"
#import "HBButtonCell.h"
#include <objc/runtime.h>

@interface HBPreferences () //<UIDocumentPickerDelegate>

@end

@implementation HBPreferences

+ (instancetype)tableWithSections:(NSArray *)sections title:(NSString *)title TableStyle:(UITableViewStyle *)style SeparatorStyle:(UITableViewCellSeparatorStyle)SeparatorStyle {
    HBPreferences *table = [[self alloc] initTableWithSections:sections TableStyle:style SeparatorStyle:SeparatorStyle];
    table.title = title;
    return table;
}

- (instancetype)initTableWithSections:(NSArray *)sections TableStyle:(UITableViewStyle *)style SeparatorStyle:(UITableViewCellSeparatorStyle)SeparatorStyle {
    if (self = [super initWithStyle:style]) {
        self.sections = sections;
        [self.tableView setSeparatorStyle:SeparatorStyle];
    }
    return self;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setupStyle];
}
- (void)setupStyle {
    if ([self isDarkMode]) {
        [self setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
        [self.navigationController.navigationBar setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
        [self.navigationController setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
        [self.tableView setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
        [self.navigationController.navigationBar setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor whiteColor]
        }];
    } else {
        [self setOverrideUserInterfaceStyle:UIUserInterfaceStyleLight];
        [self.navigationController.navigationBar setOverrideUserInterfaceStyle:UIUserInterfaceStyleLight];
        [self.navigationController setOverrideUserInterfaceStyle:UIUserInterfaceStyleLight];
        [self.tableView setOverrideUserInterfaceStyle:UIUserInterfaceStyleLight];
        [self.navigationController.navigationBar setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor blackColor]
        }];
    }
}

- (HBCell *)cellForIndexPath:(NSIndexPath *)indexPath {
    return [self.sections[indexPath.section] cells][indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.sections[section] headerTitle];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex {
    HBSection *section = self.sections[sectionIndex];
    
    return section.cells.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    HBCell *cell = [self cellForIndexPath:indexPath];
    
    if ([cell isKindOfClass:HBTwitterCell.class]) {
        return 53;
    }
    
    if ([cell isKindOfClass:HBGithubCell.class]) {
        return 53;
    }
    
    if ([cell isKindOfClass:HBLinkCell.class]) {
        return 53;
    }
    
    if ([cell isKindOfClass:HBButtonCell.class]) {
        return 53;
    }
    if ([cell isKindOfClass:HBSwitchCell.class]) {
        return 53;
    }
    return UITableViewAutomaticDimension;
}
- (CGFloat)getLabelHeight:(UILabel*)label
{
    CGSize constraint = CGSizeMake(label.frame.size.width, CGFLOAT_MAX);
    CGSize size;
    
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    CGSize boundingBox = [label.text boundingRectWithSize:constraint
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                               attributes:@{NSFontAttributeName:label.font}
                                                  context:context].size;
    
    size = CGSizeMake(ceil(boundingBox.width), ceil(boundingBox.height));
    
    return size.height;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HBCell *cell = [self cellForIndexPath:indexPath];
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [self.sections[section] footerTitle];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    HBCell *cell = [self cellForIndexPath:indexPath];
    
    if ([cell respondsToSelector:@selector(didSelectFromTable:)]) {
        [cell didSelectFromTable:self];
    }
}
- (BOOL)isDarkMode {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return true;
    } else {
        return false;
    }
}
@end
