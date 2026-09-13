#import "BHRDShareImageController.h"
#import "BHRDMediaResolver.h"
#import "BHRDManager.h"
#import "BHRDShareVisibleData.h"

static __weak UIViewController *activeEditor;
void BHRDOpenShareImageEditor(UIView *button, id preferredModel) {
    if (!button.window || activeEditor.viewIfLoaded.window) return;
    id model = preferredModel ?: BHRDMediaObject(button, @"viewModel") ?: BHRDMediaObject(BHRDMediaObject(button, @"delegate"), @"viewModel");
    UIView *card = nil;
    for (UIView *view = button.superview; view; view = view.superview) {
        if (!model) model = BHRDMediaObject(view, @"viewModel");
        if ([view isKindOfClass:UITableViewCell.class]) { card = view; break; }
        if ([NSStringFromClass(view.class) containsString:@"StatusView"]) card = view;
    }
    BHRDSharePost *post = BHRDSharePostFromSource(model);
    BHRDEnrichSharePostFromView(post, card);
    BHRDEnrichShareReplyContextFromView(post, card);
    BHRDShareImageController *editor = [[BHRDShareImageController alloc] initWithPost:post];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:editor];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    navigation.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.largeDetent];
    navigation.sheetPresentationController.prefersGrabberVisible = YES;
    navigation.sheetPresentationController.preferredCornerRadius = 16;
    if (@available(iOS 16.0, *)) {
        navigation.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent customDetentWithIdentifier:@"xsuixin-share" resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) { return context.maximumDetentValue * 0.9; }]];
    }
    activeEditor = editor;
    [BHRDTopViewController() presentViewController:navigation animated:YES completion:nil];
}
