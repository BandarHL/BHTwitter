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
}

+ (CGSize)buttonImageSizeUsingViewModel:(id)arg1 options:(NSUInteger)arg2 overrideButtonSize:(CGSize)arg3 account:(id)arg4;
@property(retain, nonatomic) id buttonAnimator;
@property(retain, nonatomic) T1StatusInlineActionsView *delegate;
@property(nonatomic, assign) UIEdgeInsets hitTestEdgeInsets;
@property(nonatomic) NSUInteger inlineActionType;
@property(nonatomic) NSUInteger displayType;
- (void)setTouchInsets:(UIEdgeInsets)arg1;
- (id)_t1_imageNamed:(id)arg1 fitSize:(CGSize)arg2 fillColor:(id)arg3;
- (_Bool)shouldShowCount;
- (double)extraWidth;
- (NSUInteger)touchInsetPriority;
- (NSUInteger)alternateInlineActionType;
- (NSUInteger)visibility;
- (NSString *)actionSheetTitle;
- (_Bool)enabled;
- (void)statusDidUpdate:(id)arg1 options:(NSUInteger)arg2 displayTextOptions:(NSUInteger)arg3 animated:(BOOL)arg4;
- (void)statusDidUpdate:(id)arg1 options:(NSUInteger)arg2 displayTextOptions:(NSUInteger)arg3 animated:(BOOL)arg4 featureSwitches:(id)arg5;
- (instancetype)initWithOptions:(NSUInteger)arg1 overrideSize:(CGSize)arg2 account:(id)arg3;
@end
