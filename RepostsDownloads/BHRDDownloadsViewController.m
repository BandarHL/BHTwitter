#import "BHRDDownloadsViewController.h"
#import "BHRDDownloadStore.h"
#import "BHRDFileNaming.h"
#import "BHRDManager.h"
#import "BHRDPreferences.h"
@interface BHRDDownloadsViewController ()
@property(nonatomic, copy) NSArray<NSURL *> *files;
@property(nonatomic, strong) id observer;
@property(nonatomic, strong) NSMutableSet<NSURL *> *selected;
@property(nonatomic, strong) UIBarButtonItem *shareButton;
@end
@implementation BHRDDownloadsViewController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"已下载的文件"; self.selected=[NSMutableSet set];
    self.tableView.allowsMultipleSelectionDuringEditing=YES;
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"选择" style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelection)];
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"保留规则" style:UIBarButtonItemStylePlain target:self action:@selector(showRetentionRules)];
    self.navigationItem.leftItemsSupplementBackButton=YES;
    self.shareButton=[[UIBarButtonItem alloc] initWithTitle:@"分享所选" style:UIBarButtonItemStylePlain target:self action:@selector(shareSelected)];
    self.toolbarItems=@[self.shareButton];
    __weak BHRDDownloadsViewController *weakSelf=self;
    self.observer=[NSNotificationCenter.defaultCenter addObserverForName:@"BHRDDownloadsChanged" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { [weakSelf reloadFiles]; }];
}
- (void)dealloc { if (_observer) [NSNotificationCenter.defaultCenter removeObserver:_observer]; }
- (void)reloadFiles {
    self.files=BHRDSavedDownloads(); [self.selected intersectSet:[NSSet setWithArray:self.files]];
    [self.tableView reloadData];
    if (self.editing) for (NSUInteger i=0;i<self.files.count;i++) if ([self.selected containsObject:self.files[i]]) [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    [self updateSelection];
}
- (void)updateSelection {
    self.shareButton.title=self.selected.count ? [NSString stringWithFormat:@"分享所选（%lu）",(unsigned long)self.selected.count] : @"分享所选";
    self.shareButton.enabled=self.selected.count>0;
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reloadFiles]; [self.navigationController setToolbarHidden:!self.editing animated:animated]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.navigationController setToolbarHidden:YES animated:animated]; }
- (void)toggleSelection { [self setEditing:!self.editing animated:YES]; }
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated]; self.navigationItem.rightBarButtonItem.title=editing ? @"完成" : @"选择";
    if (!editing) [self.selected removeAllObjects];
    [self.navigationController setToolbarHidden:!editing animated:animated]; [self reloadFiles];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.files.count; }
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    NSString *rule = BHRDDownloadRetentionDays() ? [NSString stringWithFormat:@"普通文件保留 %@，在启动、回到 X 或开始下载时清理到期文件。", BHRDDownloadRetentionTitle()] : @"普通文件永久保留，不会按时间自动清理。";
    NSString *empty = self.files.count ? @"" : @"暂无保留的下载文件。\n";
    return [NSString stringWithFormat:@"%@%@\n标记‘永久保留’的文件不自动清理，保存或分享后仍保留；普通文件单独保存或成功分享后移除，批量分享后保留。左上角可修改规则或确认清理到期文件。", empty, rule];
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSURL *url=self.files[path.row]; NSDate *date=nil; NSNumber *size=nil;
    [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil]; [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    cell.accessoryType=self.editing && [self.selected containsObject:url] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.textLabel.text=url.lastPathComponent.stringByDeletingPathExtension; cell.textLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;
    cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@%@",[NSDateFormatter localizedStringFromDate:date ?: NSDate.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle],[NSByteCountFormatter stringFromByteCount:size.longLongValue countStyle:NSByteCountFormatterCountStyleFile], BHRDDownloadIsPermanent(url) ? @" · 永久保留" : @""];
    return cell;
}
- (void)showRetentionRules {
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"下载文件保留规则" message:@"更改规则只保存设置，不会立即删除文件；下次自动清理按新规则执行。单独成功保存或分享普通文件仍会移除下载副本。标记‘永久保留’的单个文件也会在导出后保留。" preferredStyle:UIAlertControllerStyleActionSheet];
    NSInteger current=BHRDDownloadRetentionDays();
    for (NSNumber *days in @[@7,@30,@0]) {
        NSString *title=days.integerValue ? [NSString stringWithFormat:@"保留 %@ 天",days] : @"不按时间清理（永久）";
        if (days.integerValue==current) title=[@"✓ " stringByAppendingString:title];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [NSUserDefaults.standardUserDefaults setInteger:days.integerValue forKey:BHRDDownloadRetentionKey];
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"清理到期文件…" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { [self confirmCleanup]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.barButtonItem=self.navigationItem.leftBarButtonItem;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)confirmCleanup {
    NSInteger days=BHRDDownloadRetentionDays();
    NSString *message=days ? [NSString stringWithFormat:@"将删除超过 %ld 天的普通视频文件。永久保留的文件、正在下载的文件和其他类型文件不会删除。",(long)days] : @"当前为永久保留所有文件，没有按时间到期的文件需要清理。";
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"清理到期文件" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (days) [alert addAction:[UIAlertAction actionWithTitle:@"清理" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { BHRDCleanSavedDownloads(); [self reloadFiles]; }]];
    if (self.presentedViewController) [self dismissViewControllerAnimated:YES completion:^{ [self presentViewController:alert animated:YES completion:nil]; }];
    else [self presentViewController:alert animated:YES completion:nil];
}
- (void)renameFile:(NSURL *)url {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"重命名视频" message:@"保留 .mp4 格式，不改变文件内容和保留期限。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text=url.lastPathComponent.stringByDeletingPathExtension; field.clearButtonMode=UITextFieldViewModeWhileEditing; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak UIAlertController *weakAlert=alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name=weakAlert.textFields.firstObject.text;
        if (!BHRDVideoFilename(name)) { BHRDShowError(@"名称需为 1～80 字，不能以点开头或包含 /、\\、: 等路径字符。"); return; }
        NSError *error=nil;
        if (!BHRDRenameVideoFile(url,name,&error)) BHRDShowError(@"重命名失败，请检查文件是否仍存在或名称是否已被使用。");
    }]];
    if (self.presentedViewController) [self dismissViewControllerAnimated:YES completion:^{ [self presentViewController:alert animated:YES completion:nil]; }];
    else [self presentViewController:alert animated:YES completion:nil];
}
- (void)shareSelected {
    NSMutableArray *urls=[NSMutableArray array];
    for (NSURL *url in self.files) if ([self.selected containsObject:url] && [NSFileManager.defaultManager fileExistsAtPath:url.path]) [urls addObject:url];
    if (!urls.count) { [self reloadFiles]; return; }
    UIActivityViewController *sheet=[[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
    sheet.popoverPresentationController.barButtonItem=self.shareButton;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    if (path.row<0 || (NSUInteger)path.row>=self.files.count) return;
    NSURL *url=self.files[path.row];
    if (self.editing) { [self.selected addObject:url]; [table cellForRowAtIndexPath:path].accessoryType=UITableViewCellAccessoryCheckmark; [self updateSelection]; return; }
    [table deselectRowAtIndexPath:path animated:YES];
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:url.lastPathComponent message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    BOOL permanent=BHRDDownloadIsPermanent(url);
    [sheet addAction:[UIAlertAction actionWithTitle:permanent ? @"取消永久保留" : @"永久保留此文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSError *error=nil;
        if (!BHRDSetDownloadPermanent(url,!permanent,&error)) BHRDShowError(@"无法更改保留设置，请检查文件是否仍存在。请勿依赖未成功保存的保留标记。");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"重命名" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self renameFile:url]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"保存到相册" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [BHRDManager save:url]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"分享文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [BHRDManager showSaveVC:url]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UITableViewCell *cell=[table cellForRowAtIndexPath:path]; sheet.popoverPresentationController.sourceView=cell; sheet.popoverPresentationController.sourceRect=cell.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)tableView:(UITableView *)table didDeselectRowAtIndexPath:(NSIndexPath *)path { if (self.editing && path.row>=0 && (NSUInteger)path.row<self.files.count) { [self.selected removeObject:self.files[path.row]]; [table cellForRowAtIndexPath:path].accessoryType=UITableViewCellAccessoryNone; [self updateSelection]; } }
- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path { return self.editing ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete; }
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style!=UITableViewCellEditingStyleDelete || path.row<0 || (NSUInteger)path.row>=self.files.count) return;
    NSURL *url=self.files[path.row];
    if (BHRDDownloadIsPermanent(url)) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"删除永久保留的文件？" message:@"这会删除下载列表中的文件。已保存到照片或其他位置的副本不受影响。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { [self deleteFile:url]; }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else [self deleteFile:url];
}
- (void)deleteFile:(NSURL *)url {
    NSError *error=nil; [NSFileManager.defaultManager removeItemAtURL:url error:&error];
    if (error) BHRDShowError(@"无法删除文件，请重试。"); [self reloadFiles];
}
@end
