//
//  EditorMaterial.m
//  ffmpegDemo
//
//  Created by zouran on 2022/11/30.
//

#import "EditorMaterial.h"

@implementation EditorMaterial

- (instancetype)init {
    self = [super init];
    if (self) {
        self.videos = [NSMutableArray arrayWithCapacity:0];
        self.transitions = [NSMutableArray arrayWithCapacity:0];
        self.video_effects = [NSMutableArray arrayWithCapacity:0];
    }
    return self;
}

+ (NSDictionary *)modelContainerPropertyGenericClass {
    // value should be Class or Class name.
    return @{@"videos" : [EditorVideo class],
             @"transitions" : [EditorTransition class],
             @"video_effects" : [EditorVideoEffect class],
    };
}

@end
