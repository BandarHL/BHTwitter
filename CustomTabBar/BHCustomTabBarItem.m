//
//  BHCustomTabBarItem.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import "BHCustomTabBarItem.h"

@implementation BHCustomTabBarItem
- (instancetype)initWithTitle:(NSString *)title pageID:(NSString *)pageID {
    self = [super init];
    if (self) {
        _title = title;
        _pageID = pageID;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.title forKey:@"title"];
    [encoder encodeObject:self.pageID forKey:@"pageID"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        _title = [decoder decodeObjectForKey:@"title"];
        _pageID = [decoder decodeObjectForKey:@"pageID"];
    }
    return self;
}
@end
