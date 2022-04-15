//
//  BHDownloadInlineButton.h
//  BHTwitter
//
//  Created by BandarHelal on 09/04/2022.
//

#import <UIKit/UIKit.h>
#import "TWHeaders.h"

@interface BHDownloadInlineButton : UIButton
{
    unsigned long long _displayType;
    unsigned long long _inlineActionType;
    T1StatusInlineActionsView *_delegate;
    id _buttonAnimator;
}

+ (CGSize)buttonImageSizeUsingViewModel:(id)arg1 options:(unsigned long long)arg2 overrideButtonSize:(CGSize)arg3 account:(id)arg4;
@property(retain, nonatomic) id buttonAnimator;
@property(retain, nonatomic) T1StatusInlineActionsView *delegate;
@property(nonatomic) unsigned long long inlineActionType;
@property(nonatomic) unsigned long long displayType;
- (id)_t1_imageNamed:(id)arg1 fitSize:(struct CGSize)arg2 fillColor:(id)arg3;
- (void)setTouchInsets:(struct UIEdgeInsets)arg1;
- (_Bool)shouldShowCount;
- (double)extraWidth;
- (unsigned long long)touchInsetPriority;
- (unsigned long long)alternateInlineActionType;
- (unsigned long long)visibility;
- (NSString *)actionSheetTitle;
- (_Bool)enabled;
- (void)statusDidUpdate:(id)arg1 options:(unsigned long long)arg2 displayTextOptions:(unsigned long long)arg3 animated:(_Bool)arg4;
- (id)initWithOptions:(unsigned long long)arg1 overrideSize:(struct CGSize)arg2 account:(id)arg3;

@end

