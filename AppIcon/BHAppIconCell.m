//
//  AppIconCell.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import "BHAppIconCell.h"

@implementation BHAppIconCell
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.imageView = [[UIImageView alloc] init];
        self.imageView.translatesAutoresizingMaskIntoConstraints = false;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.clipsToBounds = YES;
        self.imageView.layer.cornerRadius = 22;
        
        self.checkIMG = [[UIImageView alloc] init];
        self.checkIMG.image = [UIImage systemImageNamed:@"circle"];
        self.checkIMG.translatesAutoresizingMaskIntoConstraints = false;
        
        [self addSubview:self.imageView];
        [self addSubview:self.checkIMG];

        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.imageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.imageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.imageView.heightAnchor constraintEqualToConstant:98],
            [self.imageView.widthAnchor constraintEqualToConstant:98],

            [self.checkIMG.topAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:12],
            [self.checkIMG.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [self.checkIMG.widthAnchor constraintEqualToConstant:24],
            [self.checkIMG.heightAnchor constraintEqualToConstant:24],
        ]];
    }
    return self;
}
+ (NSString *)reuseIdentifier {
    return @"appicon";
}
@end
