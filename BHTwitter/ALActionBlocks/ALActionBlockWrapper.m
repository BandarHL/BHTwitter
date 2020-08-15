//
//  ALActionBlockWrapper.m
//  ALActionBlocks
//
//  Created by Andy LaVoy on 5/16/13.
//  Copyright (c) 2013 Andy LaVoy. All rights reserved.
//

#import "ALActionBlockWrapper.h"


@implementation ALActionBlockWrapper


- (void)invokeBlock:(id)sender {
    if (self.actionBlock) {
        self.actionBlock(sender);
    }
}


@end
