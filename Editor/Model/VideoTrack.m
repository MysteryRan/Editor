//
//  VideoTrack.m
//  Editor
//
//  Created by zouran on 01/08/2025.
//

#import "VideoTrack.h"
@interface VideoTrack()<EditorFFmpegDecodeDelegate>

//记录每一个clip的入点 根据入点进行解码 seek
@property(nonatomic, strong)NSMutableArray *inpoints;

@property(nonatomic, assign)int64_t current_time;

@property(nonatomic, assign)int64_t current_in_point;

@end

@implementation VideoTrack

- (instancetype)init {
    self = [super init];
    if (self) {
        self.clips = [NSMutableArray arrayWithCapacity:0];
    }
    return self;
}

- (EditorFFmpegDecode *)appendClip:(NSString *)filePath trimIn:(int64_t)trimIn trimOut:(int64_t)trimOut {
    EditorFFmpegDecode *clip = [[EditorFFmpegDecode alloc] init];
    clip.decodeDelegate = self;
    [clip appendClip:filePath trimIn:trimIn trimOut:trimOut];
    clip.inPoint = self.current_in_point;
    clip.trimIn = trimIn;
    clip.trimOut = trimOut;
    clip.outPoint = clip.inPoint + trimOut - trimIn;
    self.current_in_point = clip.outPoint;
    [self.clips addObject:clip];
    return clip;
}

- (void)clipCurrentTime:(int64_t)current withDecode:(EditorFFmpegDecode *)deocde {
    if (current >= deocde.outPoint) {
        deocde.delegate = nil;
    }
    if (self.decodeDelegate && [self.decodeDelegate respondsToSelector:@selector(clipCurrentTime:withDecode:)]) {
        [self.decodeDelegate clipCurrentTime:current withDecode:deocde];
    }
}


@end
