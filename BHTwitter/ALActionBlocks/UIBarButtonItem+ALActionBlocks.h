//
//  UIBarButtonItem+ALActionBlocks.h
//  ALActionBlocks
//
//  Created by Andy LaVoy on 5/16/13.
//  Copyright (c) 2013 Andy LaVoy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIControl+ALActionBlocks.h"


@interface UIBarButtonItem (ALActionBlocks)

- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem block:(ALActionBlock)actionBlock;
- (instancetype)initWithImage:(UIImage *)image landscapeImagePhone:(UIImage *)landscapeImagePhone style:(UIBarButtonItemStyle)style block:(ALActionBlock)actionBlock;
- (instancetype)initWithImage:(UIImage *)image style:(UIBarButtonItemStyle)style block:(ALActionBlock)actionBlock;
- (instancetype)initWithTitle:(NSString *)title style:(UIBarButtonItemStyle)style block:(ALActionBlock)actionBlock;

- (void)setBlock:(ALActionBlock)actionBlock;

@end
