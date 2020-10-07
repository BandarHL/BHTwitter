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
#import <SafariServices/SafariServices.h>

@interface HBPreferences ()

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

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)) {
    HBCell *cell = [self cellForIndexPath:indexPath];
    if ([cell isKindOfClass:HBGithubCell.class] || [cell isKindOfClass:HBTwitterCell.class] || [cell isKindOfClass:HBLinkCell.class]) {
        return [cell contextMenuConfigurationForRowAtCell:cell FromTable:self];
    } else {
        return UIContextMenuConfiguration.new;
    }
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator API_AVAILABLE(ios(13.0)) {
    [animator addCompletion:^{
        SFSafariViewController *vcFromIdentifier = [RuntimeExplore tryExploreAddress:configuration.identifier safely:true];
        if (!(vcFromIdentifier == nil)) {
            [self presentViewController:vcFromIdentifier animated:true completion:nil];
        }
    }];
}
@end
