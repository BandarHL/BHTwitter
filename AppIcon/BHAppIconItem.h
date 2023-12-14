//
//  BHAppIconItem.h
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface BHAppIconItem : NSObject
@property (nonatomic, strong) NSString *imageName;
@property (nonatomic, strong) NSString *settingsImageName;
@property(nonatomic, assign) BOOL isPrimaryIcon;
- (instancetype)initWithImageName:(NSString *)imageName settingsImageName:(NSString *)settingsImageName isPrimaryIcon:(bool)isPrimaryIcon;
@end
