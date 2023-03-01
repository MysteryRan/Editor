//
//  EditorAudioPlayer.m
//  Editor
//
//  Created by zouran on 2022/12/14.
//

#import "EditorAudioPlayer.h"
#import "EditorAudioMixEngine.h"
#import <AVFoundation/AVFoundation.h>
#import "MediaTrack.h"

@interface EditorAudioPlayer()

@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) EditorAudioMixEngine *mixEngine;

@end


@implementation EditorAudioPlayer

- (instancetype)initWithMediaTrack:(MediaTrack *)mainTrack {
    self = [super init];
    if (self) {
        self.audioPlayer = [[AVPlayer alloc] init];
        
        self.mixEngine = [[EditorAudioMixEngine alloc] init];
        uint64_t second = 0;
        for (int i = 0; i < mainTrack.segments.count; i ++) {
            MediaSegment *seg = mainTrack.segments[i];
            EditorVideo *videoInfo = [seg segmentFindVideo];
            second += (seg.source_timerange.start + seg.source_timerange.duration);
            AVURLAsset *videoAsset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:videoInfo.path]];
            if (i == 0) {
                self.mixEngine.videoAsset = videoAsset;
            } else {
                self.mixEngine.musicAsset = videoAsset;
            }
        }
        self.mixEngine.videoTimeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(0, 1), CMTimeMakeWithSeconds(second / TIME_BASE, 1));
        
//        [self.mixEngine buildCompositionObjectsForPlayback];
        
        AVPlayerItem *playerItem = [self.mixEngine playerItemWithMainTrack:mainTrack];
        [self.audioPlayer replaceCurrentItemWithPlayerItem:playerItem];
    }
    return self;
}

- (void)play {
    [self.audioPlayer play];
    [self audioexport];
}

- (void)pasue {
    
}

- (void)seek {
    
}

- (void)audioexport {
    
    [self.mixEngine exportAtPath:[self createvideo_file_url:@"audioMix"] completion:^(BOOL success) {
       
        
        
    }];
}

- (NSString *)createvideo_file_url:(NSString *)file {
    NSString * videoPath =  [file stringByAppendingString:@".pcm"];
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Video"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        //创建目录
       BOOL isSuccess =  [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (isSuccess) {
            videoPath = [path stringByAppendingPathComponent:videoPath];
        }else
            videoPath = nil;
    }else
        videoPath = [path stringByAppendingPathComponent:videoPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
    }
    return videoPath;
}

@end
