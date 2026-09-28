#import "BHRDSettingsViewController.h"
#import "BHRDSettingsList.h"
#import "BHRDManager.h"
#import "BHRDDownloadsViewController.h"
#import "BHRDRepostPresentation.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation BHRDSettingsViewController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"X 随心";
#if BHRD_AVATAR_DIAGNOSTICS
    self.title = @"X 随心 2.4.2 头像诊断版";
#endif
    BOOL isRoot = self.navigationController.viewControllers.firstObject == self;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:isRoot ? @"完成" : @"返回" style:UIBarButtonItemStylePlain target:self action:@selector(bhrd_close)];
}
- (void)bhrd_close {
    if (self.navigationController.viewControllers.firstObject == self) [self dismissViewControllerAnimated:YES completion:nil];
    else [self.navigationController popViewControllerAnimated:YES];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return BHRDSettingsKeys().count + 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { if (section == BHRDSettingsKeys().count) return 1; return section == 0 ? BHRDSettingsKeys()[0].count + 2 : BHRDSettingsKeys()[section].count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == BHRDSettingsKeys().count) return @"下载文件";
    return @[@"时间线", @"视频与动图下载", @"推文底部元素", @"底部导航栏", @"推荐内容过滤", @"操作确认"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == BHRDSettingsKeys().count) return @"取消分享或保存失败的文件保留 7 天，可重命名、重新保存、分享或删除。单项成功导出后自动移除，批量分享保留文件。";
    return @[@"隐藏条：保留轻量提示，推荐先用此模式测试。缩略图：保留原帖作者与完整媒体预览，图片等比缩小、不裁切，隐藏正文。完全隐藏：移除转推，不保留提示。\n\n点“显示这条”可展开单条转推；点“重新隐藏已展开的转推”可统一收起。切换模式后请刷新时间线，完全隐藏已移除的内容需要重新加载。引用推文不受影响。屏蔽广告默认开启，过滤有推广标记的内容并关闭受支持的视频广告开关；修改后请重启 X 并刷新时间线。",
             @"在推文操作栏点击向下箭头，选择清晰度。私信视频可长按下载。独立下载按钮位于屏幕右侧、从顶部算起 65% 的高度，播放控件淡出时仍显示。分享按钮保留原功能。下载进度显示在底部，点击进度提示可取消，提示以外的页面可正常滑动。关闭直接保存时使用系统分享菜单保存文件。全屏打开图片后，可点击“复制图片”将当前图片复制到剪贴板，不写入相册；此功能独立于视频下载开关。长按“复制图片”或点击旁边“更多”可打开工具箱：离线复制当前图、复制链接、图片信息、仅本机保留 10 分钟的临时复制。",
             @"分别隐藏图标及其数量，保留按钮原生大小；每条推文独立布局，分享图片按钮固定排列在末尾。开启“显示分享图片按钮”后，点击推文底部的相册图标即可进入编辑页；纯文字推文也支持。隐藏转发按钮不会隐藏转推内容。更改后请重新打开推文页面；已有页面可能需要重启 X 才能更新。",
             @"分别隐藏主页、搜索、Grok、通知和私信入口，开启“首页仅保留推荐和关注”后，顶部只保留两个标签，并按页面身份限制首页分页范围；无法确认对应页面时保留原生布局。建议至少保留一个常用入口。返回主界面后生效；若页面未更新，请完全退出并重开 X。\n\n版本 2.4.2 · 标准无根版",
             @"五项过滤独立控制，默认关闭。开启“隐藏推荐关注”才表示屏蔽推荐，关闭则恢复允许显示。Premium 使用上游消息模块过滤，可能同时移除部分其他时间线提示。开启后请重启 X 并刷新页面；关闭后需重新加载已移除内容。仅过滤可识别的推荐模块，避免误删普通推文。趋势视频开关同时隐藏探索区域的轮播模块，可能影响该区域其他轮播。话题推荐依赖当前版本可读取的标识，覆盖范围可能存在差异。",
             @"三个确认开关默认关闭。开启后点击相应操作先确认，取消则不执行。点赞切换（包括取消点赞）及受支持的双击点赞入口也会确认。"][section];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == BHRDSettingsKeys().count) { UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; cell.textLabel.text = @"已下载的文件"; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell; }
    if (indexPath.section == 0 && indexPath.row > 0 && indexPath.row < 3) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.textLabel.text = indexPath.row == 1 ? @"转推显示方式" : @"重新隐藏已展开的转推";
        if (indexPath.row == 1) {
            cell.detailTextLabel.text = BHRDRepostModeTitle(BHRDCurrentRepostMode());
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.enabled = [BHRDManager HideReposts];
        cell.userInteractionEnabled = [BHRDManager HideReposts];
        return cell;
    }
    NSInteger keyRow = indexPath.section == 0 && indexPath.row > 2 ? indexPath.row - 2 : indexPath.row;
    NSString *key = BHRDSettingsKeys()[indexPath.section][keyRow];
    NSString *title = BHRDSettingsTitles()[indexPath.section][keyRow];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.textLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UISwitch *toggle = [UISwitch new];
    toggle.tag = indexPath.section * 100 + keyRow;
    toggle.on = BHRDPreference(key);
    toggle.enabled = indexPath.section != 1 || indexPath.row == 0 || [BHRDManager DownloadingVideos];
    toggle.accessibilityLabel = title;
    cell.textLabel.enabled = toggle.enabled;
    [toggle addTarget:self action:@selector(bhrd_changed:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}
- (void)bhrd_changed:(UISwitch *)sender {
    NSString *key = BHRDSettingsKeys()[sender.tag / 100][sender.tag % 100];
    [NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:key];
    if (sender.tag / 100 == 4 || [key isEqualToString:BHRDHideRepostsKey] || [key isEqualToString:BHRDHideAdsKey]) BHRDRepostPreferencesChanged();
    if ([key isEqualToString:BHRDDownloadKey] || [key isEqualToString:BHRDHideRepostsKey] || [key isEqualToString:BHRDFloatingDownloadKey]) [self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == BHRDSettingsKeys().count) { [self.navigationController pushViewController:[BHRDDownloadsViewController new] animated:YES]; return; }
    if (indexPath.section != 0 || indexPath.row == 0 || indexPath.row > 2 || ![BHRDManager HideReposts]) return;
    if (indexPath.row == 2) {
        BHRDResetExpandedReposts();
        BHRDShowError(@"已重新隐藏展开的转推，返回时间线即可查看。");
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"转推显示方式" message:@"推荐先测试隐藏条模式。完全隐藏移除的数据需刷新时间线后才能恢复。" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger mode = BHRDRepostModeHidden; mode <= BHRDRepostModeBar; mode++) {
        NSString *title = BHRDRepostModeTitle(mode);
        if (mode == BHRDCurrentRepostMode()) title = [title stringByAppendingString:@" ✓"];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults setInteger:mode forKey:BHRDRepostModeKey];
            BHRDRepostPreferencesChanged();
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    sheet.popoverPresentationController.sourceView = cell;
    sheet.popoverPresentationController.sourceRect = cell.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}
@end

@interface TFNSettingsNavigationItem : NSObject
- (instancetype)initWithTitle:(NSString *)title detail:(NSString *)detail iconName:(NSString *)iconName controllerFactory:(UIViewController *(^)(void))factory;
- (instancetype)initWithTitle:(NSString *)title detail:(NSString *)detail controllerFactory:(UIViewController *(^)(void))factory;
@end
static char BHRDSettingsEntryKey;
void BHRDOpenSettings(UIViewController *controller) {
    BHRDSettingsViewController *settings = [BHRDSettingsViewController new];
    if (controller.navigationController) [controller.navigationController pushViewController:settings animated:YES];
    else [controller presentViewController:[[UINavigationController alloc] initWithRootViewController:settings] animated:YES completion:nil];
}
void BHRDInstallSettingsEntry(UIViewController *controller, NSUInteger expectedSections) {
    id entry = objc_getAssociatedObject(controller, &BHRDSettingsEntryKey);
    if (!entry) {
        Class cls = objc_getClass("TFNSettingsNavigationItem");
        UIViewController *(^factory)(void) = ^{ return [BHRDSettingsViewController new]; };
        NSString *detail = @"下载、时间线与界面精简";
        if ([cls instancesRespondToSelector:@selector(initWithTitle:detail:iconName:controllerFactory:)]) {
            entry = [[cls alloc] initWithTitle:@"X 随心" detail:detail iconName:@"gear" controllerFactory:factory];
        } else if ([cls instancesRespondToSelector:@selector(initWithTitle:detail:controllerFactory:)]) {
            entry = [[cls alloc] initWithTitle:@"X 随心" detail:detail controllerFactory:factory];
        }
        if (!entry) return;
        if (class_getInstanceVariable([entry class], "_icon")) {
            @try { [entry setValue:[UIImage systemImageNamed:@"slider.horizontal.3"] forKey:@"_icon"]; }
            @catch (__unused NSException *exception) {}
        }
        objc_setAssociatedObject(controller, &BHRDSettingsEntryKey, entry, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (BHRDInsertSettingsListItem(controller, entry, expectedSections)) {
        if ([controller respondsToSelector:@selector(tableView)]) {
            id table = ((id (*)(id, SEL))objc_msgSend)(controller, @selector(tableView));
            if ([table isKindOfClass:UITableView.class]) [table reloadData];
        }
    }
}
BOOL BHRDIsSettingsEntry(UIViewController *controller, NSIndexPath *indexPath) {
    id entry = objc_getAssociatedObject(controller, &BHRDSettingsEntryKey);
    return entry && BHRDSettingsItemAtIndexPath(controller, indexPath) == entry;
}
UITableViewCell *BHRDSettingsEntryCell(void) {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = @"X 随心";
    cell.detailTextLabel.text = @"下载、时间线与界面精简";
    cell.imageView.image = [UIImage systemImageNamed:@"slider.horizontal.3"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
