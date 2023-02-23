//
//  MediaTrack.m
//  ffmpegDemo
//
//  Created by zouran on 2022/12/1.
//

#import "MediaTrack.h"
#import "NSObject+YYModel.h"

NSString * const MediaTrackTypeVideo = @"video";
NSString * const MediaTrackTypeEffect = @"effect";

@implementation MediaTrack

- (instancetype)init {
    self = [super init];
    if (self) {
        self.segments = [NSMutableArray arrayWithCapacity:0];
    }
    return self;
}

+ (NSDictionary *)modelContainerPropertyGenericClass {
    return @{@"segments": [MediaSegment class],
    };
}

@end
