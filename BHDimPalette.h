//
//  BHDimPalette.h
//  NeoFreeBird
//
//  Created by nyaathea
//

#import <UIKit/UIKit.h>

@interface BHDimPalette : NSObject

/**
 * Checks if the Twitter app is currently using the dim dark mode.
 * @return YES if in dim mode, NO otherwise
 */
+ (BOOL)isDimMode;

/**
 * Returns the appropriate background color based on the current theme.
 * Will return Twitter's dim color (#15202b) when in dim mode, or system background color otherwise.
 * @return UIColor for current theme's background
 */
+ (UIColor *)currentBackgroundColor;

/**
 * Returns Twitter's dim mode color (#15202b).
 * @return UIColor for dim mode
 */
+ (UIColor *)dimModeColor;

@end 