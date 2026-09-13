#import "BHRDShareImageController.h"
#import "BHRDShareRenderer.h"
#import "BHRDShareRenderState.h"
#import "BHRDManager.h"
#import "BHRDShareMediaQuality.h"
#import <Photos/Photos.h>

static UIColor *RGB(NSNumber *value) { NSUInteger n = value.unsignedIntegerValue; return [UIColor colorWithRed:((n >> 16) & 255) / 255.0 green:((n >> 8) & 255) / 255.0 blue:(n & 255) / 255.0 alpha:1]; }
@interface BHRDShareEditController : UITableViewController
@property(nonatomic, strong) BHRDSharePost *post;
@property(nonatomic, copy) void (^done)(BHRDSharePost *);
@property(nonatomic, strong) NSMutableArray<UITextView *> *fields;
@end
@implementation BHRDShareEditController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"编辑内容";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStyleDone target:self action:@selector(save)];
    self.fields = [NSMutableArray array];
    for (NSString *text in @[self.post.title, self.post.author, self.post.handle, self.post.body, self.post.translatedBody ?: @"", self.post.link]) {
        UITextView *field = [UITextView new]; field.text = text; field.font = [UIFont systemFontOfSize:16]; field.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; [self.fields addObject:field];
    }
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 6; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 1; }
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return @[@"标题", @"作者名称", @"用户名（不含 @）", @"原文正文", @"中文译文 / 译文", @"原文链接"][section]; }
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path { return (path.section == 3 || path.section == 4) ? 240 : 64; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    UITextView *field = self.fields[path.section]; field.frame = CGRectInset(cell.contentView.bounds, 8, 2); field.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [cell.contentView addSubview:field]; return cell;
}
- (void)save {
    NSString *link = [self.fields[5].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (link.length && (![@[@"https", @"http"] containsObject:[NSURL URLWithString:link].scheme.lowercaseString] || ![NSURL URLWithString:link].host.length)) { BHRDShowError(@"链接需以 https:// 或 http:// 开头。"); return; }
    self.post.title = self.fields[0].text; self.post.author = self.fields[1].text; self.post.handle = self.fields[2].text;
    self.post.body = self.fields[3].text; self.post.bodyIsOriginal = YES; self.post.translatedBody = self.fields[4].text; self.post.link = link;
    if (self.done) self.done(self.post);
    [self.navigationController popViewControllerAnimated:YES];
}
@end

@interface BHRDShareImageController ()
@property(nonatomic, strong) BHRDSharePost *post;
@property(nonatomic) NSInteger theme;
@property(nonatomic, strong) NSMutableDictionary *options;
@property(nonatomic, strong) NSMutableDictionary *images;
@property(nonatomic, strong) NSMutableArray<NSURLSessionTask *> *tasks;
@property(nonatomic, strong) UIScrollView *preview;
@property(nonatomic, strong) UIImageView *imageView;
@property(nonatomic, strong) UIView *controls;
@property(nonatomic, strong) UILabel *hint;
@property(nonatomic, strong) NSMutableArray<UIButton *> *themes;
@property(nonatomic, strong) NSMutableArray<UIButton *> *toggles;
@property(nonatomic, strong) NSMutableArray<UIButton *> *actions;
@property(nonatomic, strong) NSData *png;
@property(nonatomic, strong) BHRDShareRenderState *renderState;
@property(nonatomic) NSUInteger imageGeneration;
@property(nonatomic) NSUInteger pendingImages;
@property(nonatomic) NSUInteger failedImages;
@property(nonatomic) NSUInteger pendingUpgrades;
@property(nonatomic) NSUInteger activeImageRequests;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *imageRequests;
@property(nonatomic) BOOL closing;

@property(nonatomic) BOOL exporting;
@property(nonatomic, strong) dispatch_queue_t renderQueue;
@end
@implementation BHRDShareImageController
- (instancetype)initWithPost:(BHRDSharePost *)post {
    if ((self = [super init])) {
        _renderState = [BHRDShareRenderState new];
        _post = [post copy]; _images = [BHRDShareEmbeddedImages(post) mutableCopy]; _tasks = [NSMutableArray array];
        BHRDRestoreShareAuthorOption(NSUserDefaults.standardUserDefaults);
        _options = [BHRDShareOptions(NSUserDefaults.standardUserDefaults) mutableCopy];
        NSInteger saved = [NSUserDefaults.standardUserDefaults integerForKey:@"bhrd_share_theme"];
        _theme = saved >= 0 && saved < 6 ? saved : 0;
        _renderQueue = dispatch_queue_create("com.caun.xsuixin.share-render", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"生成分享图片"; self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"编辑内容" style:UIBarButtonItemStylePlain target:self action:@selector(edit)];
    self.preview = [UIScrollView new]; self.preview.backgroundColor = UIColor.systemGroupedBackgroundColor; [self.view addSubview:self.preview];
    self.imageView = [UIImageView new]; self.imageView.layer.cornerRadius = 12; self.imageView.clipsToBounds = YES; self.imageView.contentMode = UIViewContentModeScaleAspectFit; [self.preview addSubview:self.imageView];
    self.controls = [UIView new]; self.controls.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; [self.view addSubview:self.controls];
    self.themes = [NSMutableArray array]; self.toggles = [NSMutableArray array]; self.actions = [NSMutableArray array];
    for (NSUInteger i = 0; i < 6; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem]; button.tag = i;
        [button addTarget:self action:@selector(themeChanged:) forControlEvents:UIControlEventTouchUpInside]; [self.controls addSubview:button]; [self.themes addObject:button];
    }
    self.hint = [UILabel new]; self.hint.font = [UIFont systemFontOfSize:11]; self.hint.textColor = UIColor.secondaryLabelColor; [self.controls addSubview:self.hint];
    for (NSUInteger i = 0; i < BHRDShareOptionKeys().count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem]; button.tag = i;
        [button addTarget:self action:@selector(optionChanged:) forControlEvents:UIControlEventTouchUpInside]; [self.controls addSubview:button]; [self.toggles addObject:button];
    }
    NSArray *names = @[@"分享", @"保存到相册", @"复制"], *icons = @[@"square.and.arrow.up", @"square.and.arrow.down", @"doc.on.doc"];
    for (NSUInteger i = 0; i < 3; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem]; button.tag = i;
        UIButtonConfiguration *config = i == 0 ? UIButtonConfiguration.filledButtonConfiguration : UIButtonConfiguration.borderedButtonConfiguration;
        config.title = names[i]; config.image = [UIImage systemImageNamed:icons[i]]; config.imagePadding = 5; config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attrs) { NSMutableDictionary *a = [attrs mutableCopy]; a[NSFontAttributeName] = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]; return a; };
        button.configuration = config; [button addTarget:self action:@selector(export:) forControlEvents:UIControlEventTouchUpInside];
        [self.controls addSubview:button]; [self.actions addObject:button];
    }
    [self updateControls]; [self render]; [self loadImages];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width, bottom = self.view.safeAreaInsets.bottom, top = self.view.safeAreaInsets.top;
    CGFloat chipX = 16, chipY = 96;
    NSMutableArray<NSValue *> *chipFrames = [NSMutableArray array];
    for (NSString *title in BHRDShareOptionTitles()) {
        CGFloat w = ceil([title sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12]}].width) + 32;
        if (chipX + w > width - 16) { chipX = 16; chipY += 40; }
        [chipFrames addObject:[NSValue valueWithCGRect:CGRectMake(chipX, chipY, w, 36)]];
        chipX += w + 6;
    }
    CGFloat actionsY = chipY + 48;
    CGFloat controlsHeight = actionsY + 56 + bottom;
    self.controls.frame = CGRectMake(0, self.view.bounds.size.height - controlsHeight, width, controlsHeight);
    self.preview.frame = CGRectMake(0, top, width, MAX(0, self.controls.frame.origin.y - top));
    for (NSUInteger i = 0; i < 6; i++) self.themes[i].frame = CGRectMake(12 + i * (width - 24) / 6, 8, (width - 24) / 6, 60);
    self.hint.frame = CGRectMake(16, 74, width - 32, 18);
    for (NSUInteger i = 0; i < BHRDShareOptionKeys().count; i++) self.toggles[i].frame = chipFrames[i].CGRectValue;
    CGFloat action = (width - 48) / 3;
    for (NSUInteger i = 0; i < 3; i++) self.actions[i].frame = CGRectMake(16 + i * (action + 8), actionsY, action, 44);
    [self layoutImage];
}
- (void)layoutImage {
    UIImage *image = self.imageView.image;
    if (!image) return;
    CGFloat width = MIN(375, MAX(100, self.preview.bounds.size.width - 32));
    CGFloat height = width * image.size.height / image.size.width;
    self.imageView.frame = CGRectMake((self.preview.bounds.size.width - width) / 2, 16, width, height);
    self.preview.contentSize = CGSizeMake(self.preview.bounds.size.width, height + 32);
}
- (void)updateControls {
    NSArray *themes = BHRDShareThemes();
    for (NSUInteger i = 0; i < themes.count; i++) {
        NSDictionary *theme = themes[i]; BOOL selected = i == (NSUInteger)self.theme;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(38, 38)];
        UIImage *swatch = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [RGB(theme[@"background"]) setFill]; UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(2, 2, 34, 34)]; [circle fill];
            [(selected ? UIColor.systemBlueColor : UIColor.separatorColor) setStroke]; circle.lineWidth = selected ? 2.5 : 1; [circle stroke];
            if (selected) [[@"✓" description] drawAtPoint:CGPointMake(11, 8) withAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:18], NSForegroundColorAttributeName: [theme[@"dark"] boolValue] ? UIColor.whiteColor : UIColor.blackColor}];
        }];
        UIButtonConfiguration *config = UIButtonConfiguration.plainButtonConfiguration; config.title = theme[@"name"]; config.image = swatch; config.imagePlacement = NSDirectionalRectEdgeTop; config.imagePadding = 2; config.contentInsets = NSDirectionalEdgeInsetsZero;
        config.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attrs) { NSMutableDictionary *a = [attrs mutableCopy]; a[NSFontAttributeName] = [UIFont systemFontOfSize:10]; return a; };
        self.themes[i].configuration = config; self.themes[i].accessibilityTraits = selected ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    }
    NSArray *keys = BHRDShareOptionKeys(), *titles = BHRDShareOptionTitles();
    for (NSUInteger i = 0; i < keys.count; i++) {
        BOOL selected = [self.options[keys[i]] boolValue];
        UIButtonConfiguration *config = UIButtonConfiguration.tintedButtonConfiguration; config.title = titles[i]; config.image = selected ? [UIImage systemImageNamed:@"checkmark"] : nil; config.imagePadding = 2; config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:10]; config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.baseForegroundColor = selected ? UIColor.systemBlueColor : UIColor.secondaryLabelColor;
        config.baseBackgroundColor = selected ? UIColor.systemBlueColor : UIColor.systemGrayColor;
        config.contentInsets = NSDirectionalEdgeInsetsMake(4, 2, 4, 2);
        config.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attrs) { NSMutableDictionary *a = [attrs mutableCopy]; a[NSFontAttributeName] = [UIFont systemFontOfSize:12 weight:selected ? UIFontWeightSemibold : UIFontWeightRegular]; return a; };
        self.toggles[i].configuration = config; self.toggles[i].accessibilityTraits = selected ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    }
    BOOL enabled = [self.renderState canExportPNG:self.png != nil pendingImages:self.pendingImages exporting:self.exporting];
    for (UIButton *button in self.actions) button.enabled = enabled;
    self.hint.text = self.pendingImages ? @"正在补充尚未加载的媒体…" : self.renderState.rendering ? @"正在生成预览…" : self.pendingUpgrades ? @"高清图补充中，可先分享当前画质" : self.failedImages ? @"部分媒体未加载，可返回原推文加载后再试" : (self.post.replyToIdentifier.length && !self.post.replyContextPost) ? @"原帖尚未加载，请打开完整对话后再生成" : @"显示内容 · 双语显示原文与已有译文";
}
- (void)themeChanged:(UIButton *)sender { self.theme = sender.tag; [NSUserDefaults.standardUserDefaults setInteger:self.theme forKey:@"bhrd_share_theme"]; [self updateControls]; [self render]; }
- (void)optionChanged:(UIButton *)sender {
    NSString *key = BHRDShareOptionKeys()[sender.tag]; self.options[key] = @(![self.options[key] boolValue]);
    [NSUserDefaults.standardUserDefaults setBool:[self.options[key] boolValue] forKey:[@"bhrd_share_" stringByAppendingString:key]];
    [self loadImages];
}
- (void)render {
    NSUInteger generation = [self.renderState invalidate]; [self updateControls];
    BHRDSharePost *post = [self.post copy]; NSDictionary *options = [self.options copy], *images = [self.images copy]; NSInteger theme = self.theme;
    __weak BHRDShareImageController *weakSelf = self;
    dispatch_async(self.renderQueue, ^{
        @autoreleasepool {
            if (![weakSelf.renderState isCurrent:generation]) return;
            NSError *error = nil; NSData *png = BHRDRenderSharePNG(post, theme, options, images, &error);
            dispatch_async(dispatch_get_main_queue(), ^{
                BHRDShareImageController *controller = weakSelf;
                if (!controller || controller.closing || ![controller.renderState accept:generation]) return;
                controller.png = png;
                controller.imageView.image = png ? [UIImage imageWithData:png] : nil;
                [controller layoutImage]; [controller updateControls];
                if (!png) controller.hint.text = error.localizedDescription ?: @"无法生成图片，请减少正文长度后重试。";
            });
        }
    });
}
- (void)loadImages {
    ++self.imageGeneration;
    for (NSURLSessionTask *task in self.tasks) [task cancel];
    [self.tasks removeAllObjects]; self.activeImageRequests = 0; self.pendingImages = 0; self.pendingUpgrades = 0; self.failedImages = 0;
    self.imageRequests = [NSMutableArray array];
    for (NSURL *url in BHRDShareVisibleImageURLs(self.post, self.options)) {
        if (![url.scheme hasPrefix:@"http"]) continue;
        NSData *current = self.images[url.absoluteString];
        if (!current) {
            NSCachedURLResponse *cached = [NSURLCache.sharedURLCache cachedResponseForRequest:[NSURLRequest requestWithURL:url]];
            if (BHRDShareImagePixelSize(cached.data).width > 0) current = self.images[url.absoluteString] = cached.data;
        }
        NSURL *qualityURL = BHRDHighQualityShareURL(url);
        NSURL *requestURL = qualityURL ?: url;
        NSData *cached = BHRDCachedQualityImage(requestURL) ?: [NSURLCache.sharedURLCache cachedResponseForRequest:[NSURLRequest requestWithURL:requestURL]].data;
        if (BHRDShareImageIsBetter(cached, current)) current = self.images[url.absoluteString] = cached;
        BOOL required = BHRDShareImagePixelSize(current).width <= 0;
        BOOL upgrade = !required && qualityURL && BHRDShareImageNeedsUpgrade(current) && !BHRDShareImagePixelSize(cached).width;
        if (!required && !upgrade) continue;
        [self.imageRequests addObject:@{@"url": requestURL, @"key": url.absoluteString, @"required": @(required)}];
        if (required) self.pendingImages++; else self.pendingUpgrades++;
    }
    [self render]; [self startNextImageRequests];
}
- (void)scheduleQualityRender {
    if (self.closing) return;
    BOOL schedule = [self.renderState scheduleImageRender]; [self updateControls];
    if (!schedule) return;
    __weak BHRDShareImageController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BHRDShareImageController *controller = weakSelf;
        if (!controller || controller.closing) return;
        [controller.renderState clearImageRenderSchedule]; [controller render];
    });
}
- (void)startNextImageRequests {
    if (self.closing) return;
    while (self.activeImageRequests < 2 && self.imageRequests.count) {
        NSDictionary *item = self.imageRequests.firstObject; [self.imageRequests removeObjectAtIndex:0];
        self.activeImageRequests++;
        NSUInteger imageGeneration = self.imageGeneration;
        NSURL *url = item[@"url"]; NSString *key = item[@"key"]; BOOL required = [item[@"required"] boolValue];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url]; request.timeoutInterval = 12;
        __weak BHRDShareImageController *weakSelf = self;
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            BOOL valid = !error && [response.MIMEType hasPrefix:@"image/"] && BHRDShareImagePixelSize(data).width > 0;
            if (valid) BHRDCacheQualityImage(url, data);
            dispatch_async(dispatch_get_main_queue(), ^{
                BHRDShareImageController *controller = weakSelf;
                if (!controller || controller.closing || controller.imageGeneration != imageGeneration) return;
                controller.activeImageRequests--;
                if (required) controller.pendingImages--; else controller.pendingUpgrades--;
                if (valid && BHRDShareImageIsBetter(data, controller.images[key])) {
                    controller.images[key] = data; [controller scheduleQualityRender];
                } else if (required && !BHRDShareImagePixelSize(controller.images[key]).width) controller.failedImages++;
                [controller updateControls]; [controller startNextImageRequests];
            });
        }];
        [self.tasks addObject:task]; [task resume];
    }
}
- (void)edit {
    BHRDShareEditController *editor = [[BHRDShareEditController alloc] initWithStyle:UITableViewStyleInsetGrouped]; editor.post = [self.post copy];
    __weak BHRDShareImageController *weakSelf = self;
    editor.done = ^(BHRDSharePost *post) { weakSelf.post = post; [weakSelf render]; };
    [self.navigationController pushViewController:editor animated:YES];
}
- (void)close { self.closing = YES; [self.renderState invalidate]; [self.imageRequests removeAllObjects]; for (NSURLSessionTask *task in self.tasks) [task cancel]; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.navigationController.isBeingDismissed) { self.closing = YES; [self.renderState invalidate]; for (NSURLSessionTask *task in self.tasks) [task cancel]; }
}
- (void)dealloc { for (NSURLSessionTask *task in _tasks) [task cancel]; }
- (void)export:(UIButton *)sender {
    if (![self.renderState canExportPNG:self.png != nil pendingImages:self.pendingImages exporting:self.exporting]) return;
    NSData *png = self.png;
    if (sender.tag == 2) { [UIPasteboard.generalPasteboard setData:png forPasteboardType:@"public.png"]; return; }
    if (sender.tag == 0) {
        NSURL *file = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSString stringWithFormat:@"X随心分享-%@.png", NSUUID.UUID.UUIDString]];
        NSError *error = nil;
        if (![png writeToURL:file options:NSDataWritingAtomic error:&error]) { BHRDShowError(@"无法写入分享图片，请检查剩余存储空间。"); return; }
        UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
        sheet.popoverPresentationController.sourceView = sender; sheet.popoverPresentationController.sourceRect = sender.bounds;
        sheet.completionWithItemsHandler = ^(UIActivityType type, BOOL done, NSArray *items, NSError *err) { [[NSFileManager defaultManager] removeItemAtURL:file error:nil]; };
        [self presentViewController:sheet animated:YES completion:nil]; return;
    }
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    if (![info[@"NSPhotoLibraryAddUsageDescription"] length] && ![info[@"NSPhotoLibraryUsageDescription"] length]) { BHRDShowError(@"当前应用未提供相册权限说明，请通过“分享”菜单保存图片。" ); return; }
    self.exporting = YES; [self updateControls];
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            dispatch_async(dispatch_get_main_queue(), ^{ self.exporting = NO; [self updateControls]; BHRDShowError(@"未获得相册写入权限，可前往系统设置允许，或通过“分享”保存。"); }); return;
        }
        [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
            PHAssetResourceCreationOptions *options = [PHAssetResourceCreationOptions new]; options.originalFilename = @"X随心分享.png";
            [[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypePhoto data:png options:options];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{ self.exporting = NO; [self updateControls]; BHRDShowError(success ? @"分享图片已保存到相册。" : @"保存失败，请检查相册权限与存储空间。"); });
        }];
    }];
}
@end
