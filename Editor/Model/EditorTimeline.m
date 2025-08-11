//
//  EditorTimeline.m
//  Editor
//
//  Created by zouran on 01/08/2025.
//

#import "EditorTimeline.h"

static EditorTimeline *sharedInstance = nil;
static dispatch_once_t onceToken;

@interface EditorTimeline()

@property (nonatomic,strong)NSMutableArray *videoTracks;
@property (nonatomic,strong)NSMutableArray *audioTracks;


@end

@implementation EditorTimeline

+ (EditorTimeline *)sharedInstance {
    if (nil != sharedInstance) {
        return sharedInstance;
    }
    dispatch_once(&onceToken, ^{
        sharedInstance = [[EditorTimeline alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.videoTracks = [NSMutableArray arrayWithCapacity:0];
        self.audioTracks = [NSMutableArray arrayWithCapacity:0];
    }
    return self;
}

- (VideoTrack *)appendVideoTrack {
    VideoTrack *track = [VideoTrack new];
    [self.videoTracks addObject:track];
    
    return track;
}

- (VideoTrack *)getVideoTrackByIndex:(unsigned int)trackIndex {
    if (trackIndex < 0 || trackIndex > (self.videoTracks.count - 1)) {
        return nil;
    }
    VideoTrack *track = [self.videoTracks objectAtIndex:trackIndex];
    return track;
}


@end
