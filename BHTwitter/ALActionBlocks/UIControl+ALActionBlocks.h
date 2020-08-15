//
//  UIControl+ALActionBlocks.h
//  ALActionBlocks
//
//  Created by Andy LaVoy on 3/30/13.
//  Copyright (c) 2013 Andy LaVoy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ALActionBlock.h"

@interface UIControl (ALActionBlocks)

- (void)handleControlEvents:(UIControlEvents)controlEvents withBlock:(ALActionBlock)actionBlock;
- (void)removeActionBlocksForControlEvents:(UIControlEvents)controlEvents;

@end