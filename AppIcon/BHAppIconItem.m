//
//  BHAppIconItem.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import "BHAppIconItem.h"

@implementation BHAppIconItem
- (instancetype)initWithImageName:(NSString *)imageName settingsImageName:(NSString *)settingsImageName isPrimaryIcon:(bool)isPrimaryIcon {
    self = [super init];
    if (self) {
        _imageName = imageName;
        _settingsImageName = settingsImageName;
        _isPrimaryIcon = isPrimaryIcon;
    }
    return self;
}
@end
