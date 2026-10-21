#import <UIKit/UIKit.h>
#import "BHRDFullscreenActionRouter.h"
void BHRDUpdateFloatingDownloadControl(UIViewController *owner, BOOL active, BHRDFullscreenActionRouter *router);
void BHRDRemoveFloatingDownloadControl(UIViewController *owner);
void BHRDFullscreenControllerDidAppear(UIViewController *controller);
void BHRDFullscreenControllerDidDisappear(UIViewController *controller);
