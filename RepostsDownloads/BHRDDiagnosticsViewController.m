#import "BHRDDiagnosticsViewController.h"
#import "BHRDAvatarDiagnostics.h"
#import "BHRDBuildInfo.h"
@interface BHRDDiagnosticsViewController ()
@property(nonatomic,strong) UITextView *textView;
@property(nonatomic,strong) UIBarButtonItem *exportButton;
@property(nonatomic,strong) UIBarButtonItem *toolsButton;
@end
@implementation BHRDDiagnosticsViewController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=[@"诊断日志 · " stringByAppendingString:BHRD_BUILD_VERSION];
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.textView=[[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.textView.editable=NO; self.textView.alwaysBounceVertical=YES;
    self.textView.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.textView.textColor=UIColor.labelColor; self.textView.backgroundColor=UIColor.systemBackgroundColor;
    self.textView.text=@"正在读取日志…"; [self.view addSubview:self.textView];
    self.exportButton=[[UIBarButtonItem alloc] initWithTitle:@"脱敏导出" style:UIBarButtonItemStylePlain target:self action:@selector(exportLogs)];
    self.toolsButton=[[UIBarButtonItem alloc] initWithTitle:@"管理" style:UIBarButtonItemStylePlain target:self action:@selector(showLogTools)];
    self.navigationItem.rightBarButtonItems=@[self.exportButton,self.toolsButton];
    [self reloadLog];
}
- (void)reloadLog {
    __weak BHRDDiagnosticsViewController *weakSelf=self;
    BHRDAvatarReadLog(^(NSString *text) { weakSelf.textView.text=text; });
}
- (void)showLogTools {
    if (self.presentedViewController) return;
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"日志管理" message:@"基础日志默认保留。临时详细采集会额外记录模型和视图线索，10 分钟后自动停止；导出会移除账号、帖子标识及媒体地址。" preferredStyle:UIAlertControllerStyleActionSheet];
    __weak BHRDDiagnosticsViewController *weakSelf=self;
    [menu addAction:[UIAlertAction actionWithTitle:@"刷新日志" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [weakSelf reloadLog]; }]];
    BOOL collecting=BHRDAvatarDetailedCollectionRemaining()>0;
    [menu addAction:[UIAlertAction actionWithTitle:collecting ? @"停止详细采集" : @"详细采集 10 分钟" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { BHRDAvatarSetDetailedCollection(!collecting); [weakSelf reloadLog]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"清空日志" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        BHRDAvatarClearLogs(^(NSError *error) {
            BHRDDiagnosticsViewController *controller=weakSelf;
            if (error && controller.view.window && !controller.presentedViewController) {
                UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"清空失败" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]]; [controller presentViewController:alert animated:YES completion:nil];
            }
            [controller reloadLog];
        });
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.barButtonItem=self.toolsButton;
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)exportLogs {
    if (self.presentedViewController) return;
    self.exportButton.enabled=NO; __weak BHRDDiagnosticsViewController *weakSelf=self;
    BHRDAvatarExportLogs(^(NSArray<NSURL *> *files,NSError *error) {
        BHRDDiagnosticsViewController *controller=weakSelf; controller.exportButton.enabled=YES;
        if (!controller.view.window || controller.presentedViewController) { BHRDAvatarRemoveExport(files); return; }
        if (error) {
            UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"导出失败" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
            [controller presentViewController:alert animated:YES completion:nil]; return;
        }
        UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:files applicationActivities:nil];
        share.popoverPresentationController.barButtonItem=controller.exportButton;
        share.completionWithItemsHandler=^(__unused UIActivityType type,__unused BOOL completed,__unused NSArray *items,__unused NSError *failure) { BHRDAvatarRemoveExport(files); };
        [controller presentViewController:share animated:YES completion:nil];
    });
}
@end
