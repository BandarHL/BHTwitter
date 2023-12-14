//
//  BHColorThemeItem.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import "BHColorThemeItem.h"

@implementation BHColorThemeItem
- (instancetype)initWithColorID:(NSInteger)colorID name:(NSString *)name color:(UIColor *)color {
    self = [super init];
    if (self) {
        _colorID = colorID;
        _name = name;
        _color = color;
    }
    return self;
}
@end
