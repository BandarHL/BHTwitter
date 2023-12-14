//
//  BHColorThemeCell.m
//  BHTwitter
//
//  Created by Bandar Alruwaili on 10/12/2023.
//

#import "BHColorThemeCell.h"

@implementation BHColorThemeCell
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.colorLabel = [[UILabel alloc] init];
        self.colorLabel.translatesAutoresizingMaskIntoConstraints = false;
        self.colorLabel.textColor = [UIColor labelColor];
        self.colorLabel.textAlignment = NSTextAlignmentCenter;
        self.colorLabel.layer.masksToBounds = true;
        self.colorLabel.layer.cornerRadius = 18;
        self.colorLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        
        self.checkIMG = [[UIImageView alloc] init];
        self.checkIMG.image = [UIImage systemImageNamed:@"circle"];
        self.checkIMG.translatesAutoresizingMaskIntoConstraints = false;
        
        [self addSubview:self.colorLabel];
        [self addSubview:self.checkIMG];

        [NSLayoutConstraint activateConstraints:@[
            [self.colorLabel.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.colorLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.colorLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.colorLabel.heightAnchor constraintEqualToConstant:36],

            [self.checkIMG.topAnchor constraintEqualToAnchor:self.colorLabel.bottomAnchor constant:12],
            [self.checkIMG.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [self.checkIMG.widthAnchor constraintEqualToConstant:24],
            [self.checkIMG.heightAnchor constraintEqualToConstant:24],
        ]];

    }
    return self;
}

+ (NSString *)reuseIdentifier {
    return @"colorItem";
}
@end
