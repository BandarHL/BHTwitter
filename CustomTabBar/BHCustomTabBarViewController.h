//
//  BHCustomTabBarViewController.h
//  BHTwitter
//
//  Created by Bandar Alruwaili on 11/12/2023.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BHCustomTabBarViewController : UIViewController

@end

// Forward declaration of TFNFloatingActionButton
@interface TFNFloatingActionButton : UIView
- (void)hideAnimated:(BOOL)animated completion:(void(^)(void))completion;
@end

// Category on UIViewController to handle hiding floating action button in all BH settings views
@interface UIViewController (BHFloatingActionButtonHiding)
- (void)hideFloatingActionButtonIfNeeded;
@end

NS_ASSUME_NONNULL_END
