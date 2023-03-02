//
//  MediaFloat.m
//  Editor
//
//  Created by zouran on 2023/3/2.
//

#import "MediaFloat.h"

@implementation MediaFloat


- (instancetype)initWithXValue:(float)x andYValue:(float)y {
    self = [super init];
    if (self) {
        self.x = x;
        self.y = y;
    }
    return self;
}


@end
