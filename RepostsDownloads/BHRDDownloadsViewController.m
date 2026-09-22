#import "BHRDDownloadsViewController.h"
#import "BHRDDownloadStore.h"
#import "BHRDFileNaming.h"
#import "BHRDManager.h"
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
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; BHRDCleanSavedDownloads(); [self reloadFiles]; [self.navigationController setToolbarHidden:!self.editing animated:animated]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.navigationController setToolbarHidden:YES animated:animated]; }
- (void)toggleSelection { [self setEditing:!self.editing animated:YES]; }
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated]; self.navigationItem.rightBarButtonItem.title=editing ? @"完成" : @"选择";
    if (!editing) [self.selected removeAllObjects];
    [self.navigationController setToolbarHidden:!editing animated:animated]; [self reloadFiles];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.files.count; }
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    return self.files.count ? @"文件保留 7 天。点击可重命名、保存或分享；选择多项可批量分享，批量分享后保留文件。" : @"暂无保留的下载文件。";
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSURL *url=self.files[path.row]; NSDate *date=nil; NSNumber *size=nil;
    [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil]; [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    cell.accessoryType=self.editing && [self.selected containsObject:url] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.textLabel.text=url.lastPathComponent.stringByDeletingPathExtension; cell.textLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;
    cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@",[NSDateFormatter localizedStringFromDate:date ?: NSDate.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle],[NSByteCountFormatter stringFromByteCount:size.longLongValue countStyle:NSByteCountFormatterCountStyleFile]];
    return cell;
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
    if (path.row>=self.files.count) return;
    NSURL *url=self.files[path.row];
    if (self.editing) { [self.selected addObject:url]; [table cellForRowAtIndexPath:path].accessoryType=UITableViewCellAccessoryCheckmark; [self updateSelection]; return; }
    [table deselectRowAtIndexPath:path animated:YES];
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:url.lastPathComponent message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"重命名" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self renameFile:url]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"保存到相册" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [BHRDManager save:url]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"分享文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [BHRDManager showSaveVC:url]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UITableViewCell *cell=[table cellForRowAtIndexPath:path]; sheet.popoverPresentationController.sourceView=cell; sheet.popoverPresentationController.sourceRect=cell.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)tableView:(UITableView *)table didDeselectRowAtIndexPath:(NSIndexPath *)path { if (self.editing && path.row<self.files.count) { [self.selected removeObject:self.files[path.row]]; [table cellForRowAtIndexPath:path].accessoryType=UITableViewCellAccessoryNone; [self updateSelection]; } }
- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path { return self.editing ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete; }
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style!=UITableViewCellEditingStyleDelete || path.row>=self.files.count) return;
    NSError *error=nil; [NSFileManager.defaultManager removeItemAtURL:self.files[path.row] error:&error];
    if (error) BHRDShowError(@"无法删除文件，请重试。"); [self reloadFiles];
}
@end
