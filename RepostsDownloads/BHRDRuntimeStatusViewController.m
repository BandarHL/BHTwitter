#import "BHRDRuntimeStatusViewController.h"
#import "BHRDRuntimeStatus.h"
#import "BHRDSafety.h"
#import "BHRDBuildInfo.h"
#import "BHRDAcceptanceViewController.h"
@interface BHRDRuntimeStatusViewController ()
@property(nonatomic,copy) NSArray *rows;
@end
@implementation BHRDRuntimeStatusViewController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad { [super viewDidLoad]; self.title=@"运行状态"; self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"刷新" style:UIBarButtonItemStylePlain target:self action:@selector(reloadStatus)]; [self reloadStatus]; }
- (void)reloadStatus {
    NSMutableArray *rows=[NSMutableArray arrayWithArray:@[
        @{@"feature":@"插件构建",@"status":BHRD_BUILD_VERSION,@"detail":[NSString stringWithFormat:@"修订 %@ · 提交 %@",BHRD_BUILD_REVISION,BHRD_BUILD_COMMIT]},
        @{@"feature":@"X 版本",@"status":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"未知",@"detail":[NSString stringWithFormat:@"build %@",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"未知"]},
        @{@"feature":@"iOS",@"status":UIDevice.currentDevice.systemVersion,@"detail":NSProcessInfo.processInfo.operatingSystemVersionString},
        @{@"feature":@"整体状态",@"status":BHRDIsPaused() ? @"已暂停" : BHRDTweakEnabled() ? @"已启用" : @"等待重启",@"detail":BHRDFeatureHooksEnabledAtLaunch() ? @"本次启动已加载功能。已移除的时间线内容需刷新恢复。" : @"本次启动跳过功能 hook，恢复后请重启 X。"},
        @{@"feature":@"恢复入口",@"status":@"三指长按 1.5 秒",@"detail":@"设置入口不见时可打开恢复菜单。无法启动时，用 Filza 在 X 数据容器 Library/Application Support/XSuixinSafety 中创建 disabled 文件，再重启 X。"},
        @{@"feature":@"视频流广告覆盖",@"status":@"部分覆盖",@"detail":@"过滤明确推广标记，保留旧视频广告开关。Google/SSP 无推广元数据路径未验证覆盖。"},
        @{@"feature":@"真机验收",@"status":@"查看实际运行结果",@"detail":@"打开验收页开始一轮，在手机上实际操作后查看阶段、失败原因并导出。",@"acceptance":@YES}
    ]];
    [rows addObjectsFromArray:BHRDRuntimeCapabilities()]; self.rows=rows; [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.rows.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row=self.rows[path.row]; UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text=[NSString stringWithFormat:@"%@：%@",row[@"feature"],row[@"status"]]; cell.detailTextLabel.text=row[@"detail"];
    cell.textLabel.numberOfLines=0; cell.detailTextLabel.numberOfLines=0;
    cell.selectionStyle=[row[@"acceptance"] boolValue] ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    if ([row[@"acceptance"] boolValue]) cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if ([self.rows[path.row][@"acceptance"] boolValue]) [self.navigationController pushViewController:[BHRDAcceptanceViewController new] animated:YES];
}
@end
