//
//  UIGestureRecognizer+ALActionBlocks.m
//  ALActionBlocks
//
//  Created by Andy LaVoy on 10/17/13.
//  Copyright (c) 2013 Andy LaVoy. All rights reserved.
//

#import "UIGestureRecognizer+ALActionBlocks.h"
#import "ALActionBlockWrapper.h"
#import <objc/runtime.h>

@implementation UIGestureRecognizer (ALActionBlocks)


- (instancetype)initWithBlock:(ALActionBlock)actionBlock {
    UIGestureRecognizer *gestureRecognizer = [[[self class] alloc] init];
    [gestureRecognizer setBlock:actionBlock];
    return gestureRecognizer;
}


- (void)setBlock:(ALActionBlock)actionBlock {
    NSMutableArray *actionBlocksArray = [self actionBlocksArray];
    
    ALActionBlockWrapper *blockActionWrapper = [[ALActionBlockWrapper alloc] init];
    blockActionWrapper.actionBlock = actionBlock;
    [actionBlocksArray addObject:blockActionWrapper];
    
    [self addTarget:blockActionWrapper action:@selector(invokeBlock:)];
}


- (NSMutableArray *)actionBlocksArray {
    NSMutableArray *actionBlocksArray = objc_getAssociatedObject(self, &ALActionBlocksArray);
    if (!actionBlocksArray) {
        actionBlocksArray = [NSMutableArray array];
        objc_setAssociatedObject(self, &ALActionBlocksArray, actionBlocksArray, OBJC_ASSOCIATION_RETAIN);
    }
    return actionBlocksArray;
}

@end
