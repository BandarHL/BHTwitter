#import "BHRDDiagnosticsViewController.h"
#import "BHRDAvatarDiagnostics.h"
@interface BHRDDiagnosticsViewController ()
@property(nonatomic,strong) UITextView *textView;
@property(nonatomic,strong) UIBarButtonItem *exportButton;
@end
@implementation BHRDDiagnosticsViewController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"诊断日志";
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.textView=[[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.textView.editable=NO; self.textView.alwaysBounceVertical=YES;
    self.textView.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.textView.textColor=UIColor.labelColor; self.textView.backgroundColor=UIColor.systemBackgroundColor;
    self.textView.text=@"正在读取日志…"; [self.view addSubview:self.textView];
    self.exportButton=[[UIBarButtonItem alloc] initWithTitle:@"导出" style:UIBarButtonItemStylePlain target:self action:@selector(exportLogs)];
    self.navigationItem.rightBarButtonItems=@[self.exportButton,[[UIBarButtonItem alloc] initWithTitle:@"刷新" style:UIBarButtonItemStylePlain target:self action:@selector(reloadLog)]];
    [self reloadLog];
}
- (void)reloadLog {
    __weak BHRDDiagnosticsViewController *weakSelf=self;
    BHRDAvatarReadLog(^(NSString *text) { weakSelf.textView.text=[@"显示当前日志末尾最多 300 行；导出包含完整日志及上一份轮转日志。\n\n" stringByAppendingString:text]; });
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
