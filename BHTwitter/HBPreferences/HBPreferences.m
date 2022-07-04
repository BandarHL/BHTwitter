//
//  HBPreferences.m
//  Cephei

#import "HBPreferences.h"
#import "HBCell.h"
#import "HBSection.h"
#import "HBTwitterCell.h"
#import "HBGithubCell.h"
#import "HBSwitchCell.h"
#import "HBlinkCell.h"
#import "HBViewControllerCell.h"
#include <objc/runtime.h>
#import <SafariServices/SafariServices.h>

@interface HBPreferences () <UIFontPickerViewControllerDelegate>

@end

@implementation HBPreferences
+ (instancetype)tableWithSections:(NSArray *)sections title:(NSString *)title TableStyle:(UITableViewStyle)style SeparatorStyle:(UITableViewCellSeparatorStyle)SeparatorStyle {
    HBPreferences *table = [[self alloc] initTableWithSections:sections TableStyle:style SeparatorStyle:SeparatorStyle];
    table.title = title;
    return table;
}

- (instancetype)initTableWithTableStyle:(UITableViewStyle)style title:(NSString *)title SeparatorStyle:(UITableViewCellSeparatorStyle)SeparatorStyle {
    if (self = [super initWithStyle:style]) {
        [self.tableView setSeparatorStyle:SeparatorStyle];
        self.title = title;
    }
    return self;
}
- (instancetype)initTableWithSections:(NSArray *)sections TableStyle:(UITableViewStyle)style SeparatorStyle:(UITableViewCellSeparatorStyle)SeparatorStyle {
    if (self = [super initWithStyle:style]) {
        self.sections = sections;
        [self.tableView setSeparatorStyle:SeparatorStyle];
    }
    return self;
}
- (void)addSections:(NSArray *)sections {
    self.sections = sections;
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

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    HBCell *cell = [self cellForIndexPath:indexPath];
    if ([cell isKindOfClass:HBGithubCell.class] || [cell isKindOfClass:HBTwitterCell.class] || [cell isKindOfClass:HBViewControllerCell.class] || [cell isKindOfClass:HBlinkCell.class]) {
        return [cell contextMenuConfigurationForRowAtCell:cell FromTable:self];
    } else {
        return UIContextMenuConfiguration.new;
    }
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator {
    [animator addCompletion:^{
        UIViewController *vcFromIdentifier = [RuntimeExplore tryExploreAddress:configuration.identifier safely:true];
        if (vcFromIdentifier != nil) {
            [self presentViewController:vcFromIdentifier animated:true completion:nil];
        }
    }];
}

- (void)fontPickerViewControllerDidCancel:(UIFontPickerViewController *)viewController {
    [viewController dismissViewControllerAnimated:true completion:nil];
}

- (void)fontPickerViewControllerDidPickFont:(UIFontPickerViewController *)viewController {
    NSString *fontName = viewController.selectedFontDescriptor.fontAttributes[UIFontDescriptorNameAttribute];
    NSString *fontFamily = viewController.selectedFontDescriptor.fontAttributes[UIFontDescriptorFamilyAttribute];
    
    if (viewController.configuration.includeFaces) {
        [[NSUserDefaults standardUserDefaults] setObject:fontName forKey:@"bhtwitter_font_2"];
        [viewController dismissViewControllerAnimated:true completion:^{
            HBCell *cell = [self.sections[2] cells][4];
            [cell.detailTextLabel setText:fontName];
        }];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:fontFamily forKey:@"bhtwitter_font_1"];
        [viewController dismissViewControllerAnimated:true completion:^{
            HBCell *cell = [self.sections[2] cells][3];
            [cell.detailTextLabel setText:fontFamily];
        }];
    }
    [viewController.navigationController popViewControllerAnimated:true];
}
@end
