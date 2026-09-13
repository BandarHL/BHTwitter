#import "BHRDDownloadsViewController.h"
#import "BHRDDownloadStore.h"
#import "BHRDManager.h"
@interface BHRDDownloadsViewController ()
@property(nonatomic, copy) NSArray<NSURL *> *files;
@property(nonatomic, strong) id observer;
@end
@implementation BHRDDownloadsViewController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"已下载的文件";
    __weak BHRDDownloadsViewController *weakSelf = self;
    self.observer = [NSNotificationCenter.defaultCenter addObserverForName:@"BHRDDownloadsChanged" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        BHRDDownloadsViewController *controller=weakSelf; if (!controller) return;
        controller.files=BHRDSavedDownloads(); [controller.tableView reloadData];
    }];
}
- (void)dealloc { if (_observer) [NSNotificationCenter.defaultCenter removeObserver:_observer]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; BHRDCleanSavedDownloads(); self.files = BHRDSavedDownloads(); [self.tableView reloadData]; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.files.count; }
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section { return self.files.count ? @"文件保留 7 天。点击可重新保存或分享，左滑可删除。" : @"暂无保留的下载文件。"; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSURL *url = self.files[path.row]; NSDate *date=nil; NSNumber *size=nil;
    [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil]; [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    cell.textLabel.text = [NSDateFormatter localizedStringFromDate:date ?: NSDate.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle];
    cell.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:size.longLongValue countStyle:NSByteCountFormatterCountStyleFile];
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES]; NSURL *url = self.files[path.row];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"下载文件" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"保存到相册" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [BHRDManager save:url]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"分享文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [BHRDManager showSaveVC:url]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UITableViewCell *cell = [table cellForRowAtIndexPath:path]; sheet.popoverPresentationController.sourceView = cell; sheet.popoverPresentationController.sourceRect = cell.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete) return;
    NSError *error=nil; [NSFileManager.defaultManager removeItemAtURL:self.files[path.row] error:&error];
    if (error) BHRDShowError(@"无法删除文件，请重试。");
    self.files = BHRDSavedDownloads(); [table reloadData];
}
@end
