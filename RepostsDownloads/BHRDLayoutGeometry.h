#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
CGRect BHRDInlineActionFrame(CGRect bounds, CGRect original, NSUInteger count, NSUInteger index);
CGRect BHRDFloatingDownloadFrame(CGRect bounds, double safeTop, double safeLeft, double safeBottom, double safeRight);
CGRect BHRDAlignedInlineActionFrame(CGRect columns, CGRect original, NSArray<NSNumber *> *minimumWidths, NSUInteger index);
BOOL BHRDAddedActionGroupStart(CGRect bounds, CGRect nativeExtent, NSArray<NSNumber *> *widths, BOOL leading, CGFloat *start);
CGRect BHRDMatchedInlineGlyphFrame(CGRect bounds, CGFloat centerY, CGSize nativeSize);

NSInteger BHRDInlineActionOrder(NSString *className);
