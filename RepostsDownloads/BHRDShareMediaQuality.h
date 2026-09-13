#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NSURL *BHRDHighQualityShareURL(NSURL *url);
CGSize BHRDShareImagePixelSize(NSData *data);
BOOL BHRDShareImageNeedsUpgrade(NSData *data);
BOOL BHRDShareImageIsBetter(NSData *candidate, NSData *current);
NSData *BHRDCachedQualityImage(NSURL *url);
void BHRDCacheQualityImage(NSURL *url, NSData *data);
