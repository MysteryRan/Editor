//
//  EditorAudioPlayer.m
//  Editor
//
//  Created by zouran on 2022/12/14.
//

#import "EditorAudioPlayer.h"
#import "EditorAudioMixEngine.h"
#import <AVFoundation/AVFoundation.h>

@interface EditorAudioPlayer()

@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) EditorAudioMixEngine *mixEngine;

@end


@implementation EditorAudioPlayer

- (instancetype)init {
    self = [super init];
    if (self) {
        self.audioPlayer = [[AVPlayer alloc] init];
        
        self.mixEngine = [[EditorAudioMixEngine alloc] init];
        AVURLAsset *videoAsset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"]]];
        AVURLAsset *musicAsset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"flower" ofType:@"MP4"]]];
        self.mixEngine.videoAsset = videoAsset;
        self.mixEngine.musicAsset = musicAsset;
        self.mixEngine.videoTimeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(0, 1), CMTimeMakeWithSeconds(30, 1));
        
        [self.mixEngine buildCompositionObjectsForPlayback];
        AVPlayerItem *playerItem = [self.mixEngine playerItem];
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
