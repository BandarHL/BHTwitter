#import "BHRDInlineButtonStyle.h"
#import <objc/runtime.h>
#import "BHRDLayoutGeometry.h"

@interface BHRDInlineAppearance : NSObject
@property(nonatomic, strong) UIColor *tint;
@property(nonatomic) CGSize glyphSize;
@property(nonatomic) CGFloat glyphCenterY;
@end
@implementation BHRDInlineAppearance @end
static char AppearanceKey;
static BOOL Custom(UIView *view) {
    NSString *name = NSStringFromClass(view.class);
    return [name isEqual:@"BHRDDownloadButton"] || [name isEqual:@"BHRDShareImageButton"];
}
static BOOL Native(UIView *view) {
    for (Class cls = view.class; cls; cls = class_getSuperclass(cls)) {
        NSString *name = NSStringFromClass(cls);
        if ([name containsString:@"StatusInline"] && [name hasSuffix:@"Button"]) return YES;
    }
    return NO;
}
UIImage *BHRDInlineButtonGlyph(BOOL album) {
    static UIImage *download, *photo; static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24, 24)];
        download = [[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            CGContextRef c = context.CGContext; CGContextSetRGBStrokeColor(c, 0, 0, 0, 1); CGContextSetLineWidth(c, 1.8); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
            CGContextMoveToPoint(c, 12, 3); CGContextAddLineToPoint(c, 12, 16); CGContextMoveToPoint(c, 7, 11); CGContextAddLineToPoint(c, 12, 16); CGContextAddLineToPoint(c, 17, 11);
            CGContextMoveToPoint(c, 4, 15); CGContextAddLineToPoint(c, 4, 20); CGContextAddLineToPoint(c, 20, 20); CGContextAddLineToPoint(c, 20, 15); CGContextStrokePath(c);
        }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        photo = [[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            CGContextRef c = context.CGContext; CGContextSetRGBStrokeColor(c, 0, 0, 0, 1); CGContextSetLineWidth(c, 1.8); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
            CGPathRef frame = CGPathCreateWithRoundedRect(CGRectMake(5, 6, 16, 15), 2, 2, NULL); CGContextAddPath(c, frame); CGPathRelease(frame);
            CGContextMoveToPoint(c, 2, 16); CGContextAddLineToPoint(c, 2, 4); CGContextAddQuadCurveToPoint(c, 2, 2, 4, 2); CGContextAddLineToPoint(c, 16, 2);
            CGContextMoveToPoint(c, 5, 17); CGContextAddLineToPoint(c, 10, 12); CGContextAddLineToPoint(c, 14, 16); CGContextAddLineToPoint(c, 17, 13); CGContextAddLineToPoint(c, 21, 17); CGContextStrokePath(c);
            CGContextSetRGBFillColor(c, 0, 0, 0, 1); CGContextFillEllipseInRect(c, CGRectMake(15, 9, 2.5, 2.5));
        }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    });
    return album ? photo : download;
}
static UIImageView *GlyphView(UIView *view) {
    if ([view isKindOfClass:UIButton.class] && [(UIButton *)view imageView].image) return [(UIButton *)view imageView];
    NSMutableArray *pending = [view.subviews mutableCopy]; NSUInteger budget = 40;
    while (pending.count && budget--) {
        UIView *child = pending.firstObject; [pending removeObjectAtIndex:0];
        if (child.hidden || child.alpha <= 0.01) continue;
        if ([child isKindOfClass:UIImageView.class] && [(UIImageView *)child image] && child.bounds.size.width >= 8 && child.bounds.size.width <= 48) return (UIImageView *)child;
        [pending addObjectsFromArray:child.subviews];
    }
    return nil;
}
static UIColor *NativeColor(UIImageView *view) {
    UIImage *image = view.image;
    if (!image.CGImage || image.renderingMode == UIImageRenderingModeAlwaysTemplate) return view.tintColor;
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 64; });
    NSString *key = [NSString stringWithFormat:@"%p/%ld", image.CGImage, (long)view.traitCollection.userInterfaceStyle];
    UIColor *color = [cache objectForKey:key]; if (color) return color;
    unsigned char pixels[24 * 24 * 4] = {0}; CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(pixels, 24, 24, 8, 96, space, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast); CGColorSpaceRelease(space);
    if (!ctx) return view.tintColor;
    CGContextDrawImage(ctx, CGRectMake(0, 0, 24, 24), image.CGImage); CGContextRelease(ctx);
    double r = 0, g = 0, b = 0, alpha = 0;
    for (NSUInteger i = 0; i < 24 * 24; i++) if (pixels[i * 4 + 3] > 100) { r += pixels[i * 4]; g += pixels[i * 4 + 1]; b += pixels[i * 4 + 2]; alpha += pixels[i * 4 + 3]; }
    if (alpha > 0) color = [UIColor colorWithRed:MIN(1, r / alpha) green:MIN(1, g / alpha) blue:MIN(1, b / alpha) alpha:1];
    if (color) [cache setObject:color forKey:key];
    return color ?: view.tintColor;
}
void BHRDRefreshCustomInlineTint(UIButton *button) {
    BHRDInlineAppearance *style = objc_getAssociatedObject(button, &AppearanceKey);
    button.tintColor = style.tint ?: [UIColor colorWithRed:83/255.0 green:100/255.0 blue:113/255.0 alpha:1];
}
void BHRDLayoutCustomInlineGlyph(UIButton *button) {
    BHRDInlineAppearance *style = objc_getAssociatedObject(button, &AppearanceKey);
    if (!style) return;
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.imageView.frame = BHRDMatchedInlineGlyphFrame(button.bounds, style.glyphCenterY, style.glyphSize);
}
static UIView *SurfaceView(UIView *reference, UIImageView *glyph) {
    NSMutableArray *pending = [NSMutableArray arrayWithObject:reference]; NSUInteger budget = 30;
    while (pending.count && budget--) {
        UIView *view = pending.firstObject; [pending removeObjectAtIndex:0];
        if (view == glyph || view.hidden) continue;
        if (view.backgroundColor && CGColorGetAlpha(view.backgroundColor.CGColor) > 0.01 && view.bounds.size.width >= 28 && view.bounds.size.height >= 28) return view;
        [pending addObjectsFromArray:view.subviews];
    }
    return reference;
}
void BHRDMatchAddedButtonsToNative(UIView *actionsView) {
    NSMutableArray<UIView *> *native = [NSMutableArray array]; NSMutableArray<UIButton *> *custom = [NSMutableArray array];
    NSMutableArray *pending = [actionsView.subviews mutableCopy]; NSUInteger budget = 128;
    while (pending.count && budget--) {
        UIView *view = pending.firstObject; [pending removeObjectAtIndex:0];
        if (view.hidden || view.alpha <= 0.01) continue;
        if (Custom(view)) [custom addObject:(UIButton *)view];
        else if (Native(view)) [native addObject:view];
        else [pending addObjectsFromArray:view.subviews];
    }
    if (!custom.count) return;
    [native sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        NSString *aName = NSStringFromClass(a.class), *bName = NSStringFromClass(b.class);
        NSInteger aRank = [aName containsString:@"ShareButton"] ? 0 : [aName containsString:@"ReplyButton"] ? 1 : 2;
        NSInteger bRank = [bName containsString:@"ShareButton"] ? 0 : [bName containsString:@"ReplyButton"] ? 1 : 2;
        return aRank < bRank ? NSOrderedAscending : aRank > bRank ? NSOrderedDescending : NSOrderedSame;
    }];
    UIView *reference = nil; UIImageView *glyph = nil;
    for (UIView *view in native) { glyph = GlyphView(view); if (glyph) { reference = view; break; } }
    if (!glyph) return;
    UIView *surface = SurfaceView(reference, glyph);
    CGRect glyphRect = [glyph convertRect:glyph.bounds toView:actionsView];
    CGRect referenceRect = [reference convertRect:reference.bounds toView:actionsView];
    for (UIButton *button in custom) {
        BHRDInlineAppearance *style = [BHRDInlineAppearance new]; style.tint = NativeColor(glyph);
        style.glyphSize = CGSizeMake(MAX(16, MIN(28, glyphRect.size.width)), MAX(16, MIN(28, glyphRect.size.height)));
        // 只校准新增控件，原生按钮的宽高、数量文本和事件保持由 X 管理。
        if (referenceRect.size.height >= 24 && referenceRect.size.height <= 64) {
            CGRect frame = button.frame;
            CGRect ref = [actionsView convertRect:referenceRect toView:button.superview];
            frame.origin.y = ref.origin.y; frame.size.height = ref.size.height; button.frame = frame;
        }
        CGPoint nativeCenter = [actionsView convertPoint:CGPointMake(CGRectGetMidX([button convertRect:button.bounds toView:actionsView]), CGRectGetMidY(glyphRect)) toView:button];
        style.glyphCenterY = nativeCenter.y;
        objc_setAssociatedObject(button, &AppearanceKey, style, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        button.imageEdgeInsets = UIEdgeInsetsZero; button.contentEdgeInsets = UIEdgeInsetsZero;
        button.clipsToBounds = reference.clipsToBounds;
        button.layer.zPosition = reference.layer.zPosition;
        button.backgroundColor = surface.backgroundColor;
        button.layer.cornerRadius = surface.layer.cornerRadius;
        button.layer.borderWidth = surface.layer.borderWidth;
        button.layer.borderColor = surface.layer.borderColor;
        [button setImage:BHRDInlineButtonGlyph([NSStringFromClass(button.class) isEqual:@"BHRDShareImageButton"]) forState:UIControlStateNormal];
        BHRDRefreshCustomInlineTint(button); BHRDLayoutCustomInlineGlyph(button);
    }
    // Horizontal placement belongs exclusively to BHRDLayoutInlineActions.
}
