//
//  MediaTrack.m
//  ffmpegDemo
//
//  Created by zouran on 2022/12/1.
//

#import "MediaTrack.h"

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

@end
