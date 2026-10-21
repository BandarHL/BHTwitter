#import "BHRDAcceptanceViewController.h"
#import "BHRDAcceptance.h"
#import "BHRDPerformanceMonitor.h"
#import "BHRDAvatarDiagnostics.h"
#import "BHRDDiagnosticsViewController.h"
#import "BHRDBuildInfo.h"

static NSString *StatusTitle(NSDictionary *item) {
    if ([item[@"stage"] isEqual:@"user_confirmed"]) return @"人工确认通过";
    if ([item[@"stage"] isEqual:@"user_reported_failure"]) return @"人工报告失败";
    if ([item[@"lastOutcome"] isEqual:@"cancelled"] && [item[@"status"] isEqual:@"success"])
        return [item[@"manualConfirmed"] boolValue] ? @"此前人工确认 / 本次取消" : @"此前成功 / 本次取消";
    return @{@"pending":@"待验证",@"running":@"观察中 / 待确认",@"success":@"已观察到成功",
        @"failed":@"失败 / 异常",@"cancelled":@"已取消",@"unsupported":@"条件未满足"}[item[@"status"]] ?: @"待验证";
}
static NSString *ManualTitle(NSDictionary *item) {
    return @{@"unrated":@"未评价",@"passed":@"符合预期",@"failed":@"存在问题"}[item[@"manualResult"]] ?: @"未评价";
}
static NSString *Instruction(NSString *key) {
    return @{
        @"photo_permission":@"全屏打开图片，点右侧更多 → 保存图片，按系统提示允许添加照片。若之前已授权，不会再次弹窗；页面记录实际权限状态。",
        @"photo_save":@"全屏图片 → 右侧更多 → 保存图片。到系统照片核对内容、方向与尺寸是否正确。系统写入成功仅证明事务完成，图片是否符合预期请人工确认。切图或退出前取消属于正常取消。",
        @"recovery_gesture":@"先离开验收页，在 X 普通页面用三根手指同时长按 1.5 秒。恢复菜单实际出现才记录成功。暂停启动时自动弹出的菜单不能证明手势成功。",
        @"pause_restart":@"在 X 随心设置或三指恢复菜单中暂停全部功能，彻底退出并重开 X。返回验收页查看下一次启动是否确认跳过功能注入；保存开关本身不算验证成功。",
        @"resume_restart":@"暂停启动后，用恢复菜单恢复插件，再彻底退出并重开 X。查看新启动是否已启用功能。已有时间线需刷新。无法启动时可用 Filza 操作暂停标记；验收页不能捕获自身启动前的崩溃。",
        @"repost_detail":@"开启隐藏转推和缩略图模式，在时间线上点击隐藏转推的用户名、图片等位置，确认进入同一原帖详情；返回后应仍显示隐藏缩略图。自动验证需要详情身份和原时间线行都能确认；不满足时保留待验证，请人工核对。",
        @"performance":@"启动下面的性能观察，离开此页连续浏览视频、图片与时间线，再回来查看样本。后台时间不计入前台观察，20 分钟自动停止。显示回调间隔不是视频 FPS；进程内存也包含 X 自身占用，不能直接归因插件或推算耗电。请实际确认是否流畅、发热异常。",
        @"log_export":@"点“导出报告与日志”并保存或分享附件。自动结果只能确认系统分享活动完成；接收端是否收到需人工核对。本次分享结果会在页面和下一份报告中显示。",
        @"video_resolution":@"直接进入全屏视频，点击下载图标，无需先点评论加载帖子。页面会记录当前播放资源读取、质量菜单实际呈现和失败原因；滑到下一视频应取消旧读取。菜单呈现只证明读取入口成功，不代表文件下载或照片保存完成。请核对下载文件是否为所选视频。",
        @"stream_transfer":@"若只有流媒体选项，点“下载流媒体视频”后观察等待/读取清晰度阶段。每次网络读取有 15 秒时限，探测最多等待 45 秒；取消或超时分别记录。清晰度读取成功不等于下载完成，选定清晰度并生成本地文件才记传输成功，保存到相册或接收端仍需核对。日志有会话状态、耗时及固定网络错误类别。"
    }[key] ?: @"实际操作后核对结果；异常时导出报告和日志。";
}
static void ExportEvent(NSString *phase,NSString *session,NSError *error) {
    BHRDAvatarLog(@"acceptance_export",@{@"phase":phase,@"acceptanceSession":session ?: @"",
        @"errorDomain":error.domain ?: @"",@"errorCode":@(error.code)});
}
static NSString *Metric(NSDictionary *values,NSString *key,double scale,NSString *suffix) {
    id number=values[key];
    return [number isKindOfClass:NSNumber.class] ? [NSString stringWithFormat:@"%.1f%@",[number doubleValue]*scale,suffix] : @"不可用";
}
static NSDictionary *CurrentSessionPerformance(void) {
    NSDictionary *summary=BHRDPerformanceCurrentSummary();
    if (summary[@"acceptanceSession"] && ![summary[@"acceptanceSession"] isEqual:BHRDAcceptanceCurrentSessionIdentifier()])
        return @{@"status":@"pending",@"running":@NO,@"active":@NO,@"pendingReason":@"different_acceptance_session"};
    return summary;
}
@interface BHRDAcceptanceViewController ()
@property(nonatomic,copy) NSDictionary *snapshot;
@property(nonatomic,copy) NSDictionary *performance;
@property(nonatomic,strong) NSTimer *refreshTimer;
@property(nonatomic) BOOL exporting;
@property(nonatomic) BOOL displayedExporting;
- (BOOL)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)path;
@end
@implementation BHRDAcceptanceViewController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"实际运行验收";
    if (self.navigationController.viewControllers.firstObject==self)
        self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStylePlain target:self action:@selector(closePage)];
    self.tableView.rowHeight=UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight=100;
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"刷新" style:UIBarButtonItemStylePlain target:self action:@selector(reloadStatus)];
    [self reloadStatus];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; [self reloadStatus];
    [self.refreshTimer invalidate]; __weak BHRDAcceptanceViewController *weakSelf=self;
    self.refreshTimer=[NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(__unused NSTimer *timer) { if (!weakSelf.presentedViewController) [weakSelf reloadStatus]; }];
}
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [self.refreshTimer invalidate]; self.refreshTimer=nil; }
- (void)dealloc { [_refreshTimer invalidate]; }
- (void)closePage { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)reloadStatus {
    if (self.tableView.dragging || self.tableView.decelerating) return;
    NSDictionary *snapshot=BHRDAcceptanceSnapshot(), *performance=CurrentSessionPerformance();
    if ([self.snapshot isEqual:snapshot] && [self.performance isEqual:performance] && self.displayedExporting==self.exporting) return;
    UITableView *table=self.tableView;
    // Keep the visible cells alive for accessibility and automation. Reloading
    // the entire table every two seconds also throws away its measured heights.
    BOOL needsReload=!self.snapshot || [self.snapshot[@"items"] count]!=[snapshot[@"items"] count];
    NSIndexPath *anchor=[[table.indexPathsForVisibleRows sortedArrayUsingSelector:@selector(compare:)] firstObject];
    __block CGPoint offset=table.contentOffset;
    CGFloat anchorOffset=anchor ? offset.y-CGRectGetMinY([table rectForRowAtIndexPath:anchor]) : 0;
    self.snapshot=snapshot; self.performance=performance;
    self.displayedExporting=self.exporting;
    [UIView performWithoutAnimation:^{
        if (needsReload) [table reloadData];
        else {
            BOOL contentChanged=NO;
            for (UITableViewCell *cell in table.visibleCells) {
                NSIndexPath *path=[table indexPathForCell:cell];
                if (path) contentChanged=[self configureCell:cell atIndexPath:path] || contentChanged;
            }
            for (NSInteger section=0;section<[self numberOfSectionsInTableView:table];section++) {
                UITableViewHeaderFooterView *header=[table headerViewForSection:section], *footer=[table footerViewForSection:section];
                NSString *headerTitle=[self tableView:table titleForHeaderInSection:section], *footerTitle=[self tableView:table titleForFooterInSection:section];
                if (header && ![header.textLabel.text isEqual:headerTitle]) { header.textLabel.text=headerTitle; contentChanged=YES; }
                if (footer && ![footer.textLabel.text isEqual:footerTitle]) { footer.textLabel.text=footerTitle; contentChanged=YES; }
            }
            if (contentChanged) { [table beginUpdates]; [table endUpdates]; }
        }
        [table layoutIfNeeded];
        if (anchor && !needsReload) offset.y=CGRectGetMinY([table rectForRowAtIndexPath:anchor])+anchorOffset;
        CGFloat minimum=-table.adjustedContentInset.top;
        CGFloat maximum=MAX(minimum,table.contentSize.height-table.bounds.size.height+table.adjustedContentInset.bottom);
        offset.y=MAX(minimum,MIN(maximum,offset.y));
        [table setContentOffset:offset animated:NO];
    }];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate { if (!decelerate) [self reloadStatus]; }
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView { [self reloadStatus]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 4; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return section==0 ? 3 : section==1 ? [self.snapshot[@"items"] count] : section==2 ? 2 : 1;
}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    return @[@"验收轮次",@"实际结果（点击查看步骤 / 人工确认）",@"性能观察",@"排查与反馈"][section];
}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if (section==0) {
        NSString *mode=[self.snapshot[@"mode"] isEqual:@"session"] ? @"本轮验收，结果可跨重启保留" : @"最近观察，非本轮验收；建议先开始一轮";
        NSDate *date=[NSDate dateWithTimeIntervalSince1970:[self.snapshot[@"startedAt"] doubleValue]];
        NSDateFormatter *format=[NSDateFormatter new]; format.dateStyle=NSDateFormatterShortStyle; format.timeStyle=NSDateFormatterShortStyle;
        return [NSString stringWithFormat:@"%@ · %@\n构建 %@ · 提交 %@\n%@",mode,[format stringFromDate:date],BHRD_BUILD_VERSION,BHRD_BUILD_COMMIT,
            self.snapshot[@"storageError"] ? @"验收记录保存失败，跨重启结果可能丢失，请导出排查。" : @"每次新构建重新验收。尚未触发的功能不会自动标为通过。"];
    }
    if (section==1) return @"结果来自运行事件或明确标注的人工确认。人工评价单独保留，性能告警优先显示；成功、失败和取消计数保留。自动结果不能证明所有未来操作都成功。";
    if (section==2) return @"观察只在你启动后进行，离开此页可继续操作 X；后台暂停，最多 20 分钟。重新观察只清零采样数值，人工评价与本轮告警保留；开始新一轮验收才清零。内存峰值来自间隔采样，不是系统精确峰值；没有耗电测量。";
    return @"导出包含本轮阶段、构建身份、性能采样及脱敏日志，不自动上传。发现异常后把附件和复现步骤发回，再用下一构建复验。";
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"AcceptanceCell"];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AcceptanceCell"];
    [self configureCell:cell atIndexPath:path];
    return cell;
}
- (BOOL)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)path {
    NSString *title, *detail;
    BOOL enabled=!(path.section==0 && self.exporting);
    BOOL metric=path.section==2 && path.row==0;
    if (path.section==0) {
        title=@[@"开始一次新验收",@"验收方式与限制",@"导出报告与日志"][path.row];
        detail=@[@"清零当前结果并开始新的轮次；此前已导出的文件保留。",@"先开始验收 → 实际操作 → 回看结果 → 异常时导出。",self.exporting ? @"正在生成脱敏附件…" : @"验收 JSON、性能 JSON 与脱敏诊断日志，可保存到文件。"][path.row];
    } else if (path.section==1) {
        NSDictionary *item=self.snapshot[@"items"][path.row]; NSDictionary *error=item[@"error"];
        title=[NSString stringWithFormat:@"%@ · %@",item[@"title"],StatusTitle(item)];
        detail=[NSString stringWithFormat:@"%@\n人工评价：%@\n阶段 %@ · 成功 %@ / 失败 %@ / 取消 %@%@",item[@"detail"],ManualTitle(item),item[@"stage"],item[@"successCount"],item[@"failureCount"],item[@"cancelledCount"],error ? [NSString stringWithFormat:@"\n错误 %@ (%@)",error[@"domain"],error[@"code"]] : @""];
    } else if (path.section==2 && path.row==0) {
        NSDictionary *p=self.performance; BOOL started=p[@"sessionID"]!=nil;
        title=started ? ([p[@"running"] boolValue] ? ([p[@"active"] boolValue] ? @"正在观察前台使用" : @"观察已暂停（非前台）") : @"最近一次性能观察") : @"尚未开始性能观察";
        detail=started ? [NSString stringWithFormat:@"前台 %@ · %@ 次回调间隔\n超过 50ms %@ · 最大 %@\n进程内存 %@ · 采样峰值 %@\n内存警告 %@ · 热状态 %@\n%@",Metric(p,@"visibleSeconds",1,@" 秒"),p[@"frameIntervals"] ?: @0,Metric(p,@"slowIntervalRatio",100,@"%"),Metric(p,@"maxIntervalMs",1,@"ms"),Metric(p,@"memoryMB",1,@"MB"),Metric(p,@"peakMemoryMB",1,@"MB"),p[@"memoryWarnings"] ?: @0,p[@"thermalState"] ?: @"未知",[p[@"status"] isEqual:@"observed"] ? @"已有观察样本，请人工确认实际体验。" : @"样本不足，继续观察；不算通过。"] : @"只测显示回调间隔、进程内存与热状态，不测真实视频帧率或耗电。";
    } else if (path.section==2) {
        title=[self.performance[@"running"] boolValue] ? @"停止性能观察" : @"开始性能观察（最长 20 分钟）";
        detail=@"开始后返回 X 连续浏览，再回到此页核对。";
    } else { title=@"查看诊断日志"; detail=@"可临时详细采集 10 分钟，辅助定位无法自动确认的阶段。"; }
    BOOL changed=![cell.textLabel.text isEqual:title] || ![cell.detailTextLabel.text isEqual:detail] || cell.userInteractionEnabled!=enabled;
    // Leave unchanged labels untouched so a focused accessibility element does
    // not receive a new value on a timer tick for an unrelated observation.
    if (![cell.textLabel.text isEqual:title]) cell.textLabel.text=title;
    if (![cell.detailTextLabel.text isEqual:detail]) cell.detailTextLabel.text=detail;
    cell.textLabel.numberOfLines=0; cell.detailTextLabel.numberOfLines=0;
    cell.selectionStyle=metric ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    cell.accessoryType=metric ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    cell.userInteractionEnabled=enabled; cell.textLabel.enabled=enabled;
    return changed;
}
- (void)showNotice:(NSString *)title message:(NSString *)message {
    if (!self.view.window || self.presentedViewController) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)beginSession {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"开始新一轮验收？" message:@"替换当前验收结果，停止此前的性能观察。需要保留旧结果请先导出。请先完成或取消正在进行的保存、导航和分享。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak BHRDAcceptanceViewController *weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"开始" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { BHRDPerformanceStop(); BHRDAcceptanceBeginSession(); [weakSelf reloadStatus]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)showItem:(NSDictionary *)item source:(UITableViewCell *)cell {
    NSString *session=self.snapshot[@"sessionID"], *key=item[@"id"];
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:item[@"title"] message:[NSString stringWithFormat:@"%@\n\n当前：%@\n人工评价：%@\n%@",Instruction(key),StatusTitle(item),ManualTitle(item),item[@"detail"]] preferredStyle:UIAlertControllerStyleActionSheet];
    __weak BHRDAcceptanceViewController *weakSelf=self;
    for (NSNumber *passed in @[@YES,@NO]) {
        [sheet addAction:[UIAlertAction actionWithTitle:passed.boolValue ? @"我已实际核对：符合预期" : @"我已实际核对：存在问题" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            if ([session isEqual:BHRDAcceptanceCurrentSessionIdentifier()]) BHRDAcceptanceRecordManualResult(key,passed.boolValue);
            [weakSelf reloadStatus];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"暂不确认" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView=self.view;
    sheet.popoverPresentationController.sourceRect=[cell convertRect:cell.bounds toView:self.view];
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)exportReport {
    if (self.exporting || self.presentedViewController) return;
    self.exporting=YES; [self reloadStatus];
    NSString *session=BHRDAcceptanceCurrentSessionIdentifier(); NSDictionary *performance=CurrentSessionPerformance();
    __weak BHRDAcceptanceViewController *weakSelf=self;
    BHRDAvatarExportLogs(^(NSArray<NSURL *> *logs,NSError *logError) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
            NSError *error=logError; NSURL *report=error ? nil : BHRDAcceptanceExportReport(&error);
            if (![session isEqual:BHRDAcceptanceCurrentSessionIdentifier()])
                error=[NSError errorWithDomain:@"XSuixinAcceptance" code:1 userInfo:@{NSLocalizedDescriptionKey:@"验收轮次已改变，请在新轮次重新导出。"}];
            NSURL *metrics=report ? [[report URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"XSuixin-性能采样.json"] : nil;
            if (metrics) {
                NSData *data=[NSJSONSerialization dataWithJSONObject:performance options:NSJSONWritingPrettyPrinted error:&error];
                if (data && [data writeToURL:metrics options:NSDataWritingAtomic error:&error]) [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:metrics.path error:NULL];
            }
            dispatch_async(dispatch_get_main_queue(),^{
                BHRDAcceptanceViewController *controller=weakSelf; controller.exporting=NO; [controller reloadStatus];
                if (error || !report) {
                    ExportEvent(@"failed",session,error); BHRDAvatarRemoveExport(logs); BHRDAcceptanceRemoveExport(report);
                    [controller showNotice:@"导出失败" message:error.localizedDescription ?: @"无法生成验收报告，请重试。"];
                    return;
                }
                ExportEvent(@"generated",session,nil);
                if (!controller.view.window || controller.presentedViewController) {
                    ExportEvent(@"cancelled",session,nil); BHRDAvatarRemoveExport(logs); BHRDAcceptanceRemoveExport(report); return;
                }
                NSMutableArray *files=[logs mutableCopy]; if (!files) files=[NSMutableArray array]; [files addObject:report]; [files addObject:metrics];
                UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:files applicationActivities:nil];
                share.popoverPresentationController.sourceView=controller.view;
                share.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(controller.view.bounds),CGRectGetMidY(controller.view.bounds),1,1);
                share.completionWithItemsHandler=^(__unused UIActivityType type,BOOL completed,__unused NSArray *items,NSError *failure) {
                    ExportEvent(failure ? @"failed" : completed ? @"completed" : @"cancelled",session,failure);
                    BHRDAvatarRemoveExport(logs); BHRDAcceptanceRemoveExport(report); [weakSelf reloadStatus];
                };
                [controller presentViewController:share animated:YES completion:^{ ExportEvent(@"presented",session,nil); }];
            });
        });
    });
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES]; if (self.presentedViewController) return;
    if (path.section==0) {
        if (path.row==0) [self beginSession];
        else if (path.row==1) [self showNotice:@"验收方式" message:@"开始新验收后，离开本页逐项操作，再回来查看结果。权限、系统保存、恢复手势、重启和转推返回会记录实际阶段。没有触发的项目保留待验证。\n\n性能需要手动开始观察；顺畅、图片内容正确和导出接收成功仍需你核对。失败时导出报告与日志，并补充复现步骤；下一构建不会沿用上一构建的通过结果。"];
        else [self exportReport];
    } else if (path.section==1) [self showItem:self.snapshot[@"items"][path.row] source:[table cellForRowAtIndexPath:path]];
    else if (path.section==2 && path.row==1) {
        if ([self.performance[@"running"] boolValue]) BHRDPerformanceStop();
        else BHRDPerformanceStartInScene(self.view.window.windowScene);
        [self reloadStatus];
    } else if (path.section==3) [self.navigationController pushViewController:[BHRDDiagnosticsViewController new] animated:YES];
}
@end
