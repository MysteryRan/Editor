//
//  MediaTimeRange.m
//  ffmpegDemo
//
//  Created by zouran on 2022/11/29.
//

#import "MediaTimeRange.h"

@implementation MediaTimeRange

- (id)initWithTimeRangeStart:(uint64_t)start timeRangeDuration:(uint64_t)duration {
    self = [super init];
    if (self) {
        _start = start;
        _duration = duration;
    }
    return self;
}

@end
