#import "BHRDShareImageButton.h"
#import "BHRDShareImageController.h"
#import "BHRDPreferences.h"
#import "BHRDMediaResolver.h"
#import "BHRDInlineButtonStyle.h"

@implementation BHRDShareImageButton
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _inlineActionType = 132;
        BHRDRefreshCustomInlineTint(self);
        [self setImage:BHRDInlineButtonGlyph(YES) forState:UIControlStateNormal];
        self.accessibilityLabel = @"生成分享图片";
        self.accessibilityHint = @"打开配色和内容编辑页";
        [self addTarget:self action:@selector(openShareImage:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (instancetype)initWithOptions:(NSUInteger)options overrideSize:(id)size account:(id)account { return [self initWithFrame:CGRectZero]; }
- (instancetype)initWithInlineActionType:(NSUInteger)type options:(NSUInteger)options overrideSize:(id)size account:(id)account { return [self initWithFrame:CGRectZero]; }
+ (CGSize)buttonImageSizeUsingViewModel:(id)model options:(NSUInteger)options overrideButtonSize:(CGSize)size account:(id)account { return CGSizeZero; }
- (void)updateAppearance { BHRDRefreshCustomInlineTint(self); }
- (void)layoutSubviews { [super layoutSubviews]; BHRDLayoutCustomInlineGlyph(self); }
- (void)statusDidUpdate:(id)status options:(NSUInteger)options displayTextOptions:(NSUInteger)textOptions animated:(BOOL)animated {
    self.viewModel = status;
    [self updateAppearance];
}
- (void)statusDidUpdate:(id)status options:(NSUInteger)options displayTextOptions:(NSUInteger)textOptions animated:(BOOL)animated featureSwitches:(id)switches {
    self.viewModel = status;
    [self updateAppearance];
}
- (void)openShareImage:(UIButton *)sender {
    if (!BHRDPreference(BHRDShowShareImageKey)) return;
    // 优先读取当前操作栏模型，避免复用后持有上一条推文。
    id model = BHRDMediaObject(self.delegate, @"viewModel") ?: self.viewModel;
    BHRDOpenShareImageEditor(self, model);
}
- (void)setTouchInsets:(UIEdgeInsets)insets { _touchInsets = insets; self.hitTestEdgeInsets = insets; }
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || !self.isEnabled) return NO;
    return UIEdgeInsetsEqualToEdgeInsets(self.hitTestEdgeInsets, UIEdgeInsetsZero) ? [super pointInside:point withEvent:event] : CGRectContainsPoint(UIEdgeInsetsInsetRect(self.bounds, self.hitTestEdgeInsets), point);
}
- (id)_t1_imageNamed:(id)name fitSize:(CGSize)size fillColor:(id)fill { return nil; }
+ (id)_t1_imageNamed:(id)name fitSize:(CGSize)size fillColor:(id)fill { return nil; }
#define BHRD_METRIC(type, name, value) - (type)name { return value; } + (type)name { return value; }
BHRD_METRIC(double, extraWidth, 40.0)
BHRD_METRIC(double, extraWidthWithStyle, 40.0)
BHRD_METRIC(double, horizontalLayoutOffset, 0.0)
BHRD_METRIC(double, trailingEdgeInset, 6.0)
BHRD_METRIC(NSUInteger, visibility, 1)
BHRD_METRIC(NSUInteger, alternateInlineActionType, 6)
BHRD_METRIC(NSUInteger, touchInsetPriority, 2)
BHRD_METRIC(BOOL, shouldShowCount, NO)
#undef BHRD_METRIC
+ (NSUInteger)displayType { return 0; }
- (BOOL)enabled { return self.isEnabled; }
- (NSString *)actionSheetTitle { return @"生成分享图片"; }
@end
