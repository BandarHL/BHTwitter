//
//  BHDownloadInlineButton.h
//  BHTwitter
//
//  Created by BandarHelal on 09/04/2022.
//

#import <UIKit/UIKit.h>
#import "BHTManager.h"

@interface BHDownloadInlineButton : UIButton
{
    NSUInteger _displayType;
    NSUInteger _inlineActionType;
    T1StatusInlineActionsView *_delegate;
    id _buttonAnimator;
    id _viewModel;
}

+ (CGSize)buttonImageSizeUsingViewModel:(id)arg1 options:(NSUInteger)arg2 overrideButtonSize:(CGSize)arg3 account:(id)arg4;
@property(retain, nonatomic) id buttonAnimator;
@property(retain, nonatomic) T1StatusInlineActionsView *delegate;
@property(nonatomic, assign) UIEdgeInsets hitTestEdgeInsets;
@property (nonatomic, assign, readwrite) UIEdgeInsets touchInsets;
@property(nonatomic) NSUInteger inlineActionType;
@property(nonatomic) NSUInteger displayType;
@property (nonatomic) id viewModel;
- (void)setTouchInsets:(UIEdgeInsets)arg1;
- (id)_t1_imageNamed:(id)arg1 fitSize:(CGSize)arg2 fillColor:(id)arg3;
- (_Bool)shouldShowCount;
- (double)extraWidth;
- (CGFloat)trailingEdgeInset;
- (NSUInteger)touchInsetPriority;
- (NSUInteger)alternateInlineActionType;
- (NSUInteger)visibility;
- (NSString *)actionSheetTitle;
- (_Bool)enabled;
- (void)statusDidUpdate:(id)arg1 options:(NSUInteger)arg2 displayTextOptions:(NSUInteger)arg3 animated:(BOOL)arg4;
- (void)statusDidUpdate:(id)arg1 options:(NSUInteger)arg2 displayTextOptions:(NSUInteger)arg3 animated:(BOOL)arg4 featureSwitches:(id)arg5;
- (instancetype)initWithOptions:(NSUInteger)arg1 overrideSize:(id)arg2 account:(id)arg3;
- (instancetype)initWithInlineActionType:(NSUInteger)arg1 options:(NSUInteger)arg2 overrideSize:(id)arg3 account:(id)arg4;
@end
