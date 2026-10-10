#import <UIKit/UIKit.h>
@interface BHRDShareImageButton : UIButton
@property(nonatomic, weak) id delegate;
@property(nonatomic, strong) id viewModel;
@property(nonatomic, strong) id buttonAnimator;
@property(nonatomic) NSUInteger inlineActionType;
@property(nonatomic) NSUInteger displayType;
@property(nonatomic) UIEdgeInsets touchInsets;
@property(nonatomic) UIEdgeInsets hitTestEdgeInsets;
@end
