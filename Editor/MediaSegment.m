//
//  MediaSegment.m
//  Editor
//
//  Created by zouran on 2022/12/19.
//

#import "MediaSegment.h"
#import "EditorData.h"

@implementation MediaSegment

- (EditorVideo *)segmentFindVideo {
    
    EditorData *editorData = [EditorData sharedInstance];
    for (EditorVideo *video in editorData.materials.videos) {
        if ([self.material_id isEqualToString:video.media_id]) {
            return video;
        }
    }
    EditorVideo *emptyVideo = [EditorVideo new];
    emptyVideo.path = [[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"];
    emptyVideo.width = 100;
    emptyVideo.height = 100;
    return emptyVideo;
}

- (CMTimeRange)getAVFoundationTargetTimeRange {
    CMTimeRange insideRange = CMTimeRangeMake(CMTimeMake(self.target_timerange.start, 1), CMTimeMake(self.target_timerange.duration, 1));
    return insideRange;
}

- (CMTime)getAVFoundationTargetTimeStart {
    CMTime insideTime = CMTimeMake(self.target_timerange.start, 1);
    return insideTime;
}

- (CMTime)getAVFoundationTargetTimeDuration {
    CMTime insideTime = CMTimeMake(self.target_timerange.duration, 1);
    return insideTime;
}

@end
