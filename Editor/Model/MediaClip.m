//
//  MediaClip.m
//  Editor
//
//  Created by zouran on 2023/3/2.
//

#import "MediaClip.h"

@implementation MediaClip

- (instancetype)init {
    self = [super init];
    if (self) {
        self.scale = [[MediaFloat alloc] initWithXValue:1 andYValue:1];
        self.transform = [[MediaFloat alloc] initWithXValue:0 andYValue:0];
    }
    return self;
}

+ (NSDictionary *)modelContainerPropertyGenericClass {
    return @{@"scale": [MediaFloat class],
             @"transform": [MediaFloat class],
    };
}

@end
