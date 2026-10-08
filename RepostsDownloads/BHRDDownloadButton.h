//
//  BHRDDownloadButton.h
//  BHTwitter
//
//  Created by BandarHelal on 09/04/2022.
//

@import UIKit;
#import "BHRDManager.h"

@class T1StatusInlineActionsView; // Forward declaration instead of assuming it's imported

NS_ASSUME_NONNULL_BEGIN

@interface BHRDDownloadButton : UIButton
{
    NSUInteger _displayType;
    NSUInteger _inlineActionType;
    __weak T1StatusInlineActionsView *_delegate; // Added weak reference
    id _buttonAnimator;
    id _viewModel;
}

+ (CGSize)buttonImageSizeUsingViewModel:(id)viewModel
                               options:(NSUInteger)options
                    overrideButtonSize:(CGSize)overrideSize
                             account:(id)account;

@property (nonatomic, weak) T1StatusInlineActionsView *delegate; // Changed to weak
@property (nonatomic, strong, nullable) id buttonAnimator;
@property (nonatomic, assign) UIEdgeInsets hitTestEdgeInsets;
@property (nonatomic, assign) UIEdgeInsets touchInsets;
@property (nonatomic, assign) NSUInteger inlineActionType;
@property (nonatomic, assign) NSUInteger displayType;
@property (nonatomic, strong, nullable) id viewModel;

+ (NSArray *)downloadableMediaEntitiesFromSource:(nullable id)source;

- (void)presentDownloadOptionsForMediaEntities:(NSArray *)mediaEntities
                                    sourceView:(UIView *)sourceView;
- (void)presentDownloadOptionsForMediaEntities:(NSArray *)mediaEntities
                                    sourceView:(UIView *)sourceView
                         selectionStillCurrent:(nullable BOOL (^)(void))selectionStillCurrent
                                     presented:(nullable void (^)(BOOL shown))presented;
- (void)DownloadHandler:(UIButton *)sender;

- (void)setTouchInsets:(UIEdgeInsets)touchInsets;
- (nullable id)_t1_imageNamed:(NSString *)name
                     fitSize:(CGSize)fitSize
                   fillColor:(nullable id)fillColor;
- (BOOL)shouldShowCount;
- (CGFloat)horizontalLayoutOffset;
- (double)extraWidth;
- (CGFloat)trailingEdgeInset;
- (NSUInteger)touchInsetPriority;
- (NSUInteger)alternateInlineActionType;
- (NSUInteger)visibility;
- (nullable NSString *)actionSheetTitle;
- (BOOL)enabled;

// Status update methods
- (void)statusDidUpdate:(id)status
                options:(NSUInteger)options
    displayTextOptions:(NSUInteger)displayTextOptions
             animated:(BOOL)animated;

- (void)statusDidUpdate:(id)status
                options:(NSUInteger)options
    displayTextOptions:(NSUInteger)displayTextOptions
             animated:(BOOL)animated
      featureSwitches:(nullable id)featureSwitches;

// Initializers
- (instancetype)initWithOptions:(NSUInteger)options
                  overrideSize:(nullable id)overrideSize
                       account:(nullable id)account;

- (instancetype)initWithInlineActionType:(NSUInteger)inlineActionType
                                options:(NSUInteger)options
                          overrideSize:(nullable id)overrideSize
                               account:(nullable id)account;

@end

NS_ASSUME_NONNULL_END
