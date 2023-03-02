//
//  EditorAudioMixEngine.m
//  Editor
//
//  Created by zouran on 2022/12/14.
//

#import "EditorAudioMixEngine.h"
#import "MediaTrack.h"
#import "MediaSegment.h"

@interface EditorAudioMixEngine ()

@property (nonatomic, strong) AVMutableComposition *composition;
@property (nonatomic, strong) AVMutableVideoComposition *videoComposition;
@property (nonatomic, strong) AVMutableAudioMix *audioMix;

@end


@implementation EditorAudioMixEngine {
    AVPlayerItem *_currentItem;
    
    AVMutableCompositionTrack *_comTrack1;
    AVMutableCompositionTrack *_comTrack2;
    
    CGFloat _videoVolume;
    CGFloat _musicVolume;
}


- (instancetype)init {
    self = [super init];
    if (self) {
        _videoVolume = 1.0;
        _musicVolume = 0.1;
    }
    return self;
}


- (void)buildTransitionComposition:(AVMutableComposition *)composition andVideoComposition:(AVMutableVideoComposition *)videoComposition andAudioMix:(AVMutableAudioMix *)audioMix
{
    // Add two video tracks and two audio tracks.
    AVMutableCompositionTrack *compositionVideoTracks = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *compositionAudioTracks[2];
    compositionAudioTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionAudioTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    _comTrack1 = compositionAudioTracks[0];
    _comTrack2 = compositionAudioTracks[1];
    
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    {
        AVURLAsset *asset = self.videoAsset;
        
        AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        NSError* error;
        [compositionVideoTracks insertTimeRange:self.videoTimeRange ofTrack:videoTrack atTime:kCMTimeZero error:&error];
        
        AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
        [_comTrack1 insertTimeRange:self.videoTimeRange ofTrack:audioTrack atTime:CMTimeMake(11, 1) error:&error];
        
        if (self.musicAsset) {
            AVAssetTrack *musicTrack = [[self.musicAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            if (musicTrack) {
                [_comTrack2 insertTimeRange:self.videoTimeRange ofTrack:musicTrack atTime:kCMTimeZero error:&error];
            }
        }
    }
    
    NSMutableArray *instructions = [NSMutableArray array];
    
    AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    passThroughInstruction.timeRange = self.videoTimeRange;
    AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTracks];
    passThroughInstruction.layerInstructions = [NSArray arrayWithObject:passThroughLayer];
    [instructions addObject:passThroughInstruction];
    
    NSMutableArray<AVAudioMixInputParameters *> *trackMixArray = [NSMutableArray<AVAudioMixInputParameters *> array];
    {
        AVMutableAudioMixInputParameters *trackMix1 = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:_comTrack1];
        trackMix1.trackID = _comTrack1.trackID;
        [trackMix1 setVolume:_videoVolume atTime:kCMTimeZero];
        [trackMixArray addObject:trackMix1];
        
        AVMutableAudioMixInputParameters *trackMix2 = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:_comTrack2];
        trackMix2.trackID = _comTrack2.trackID;
        [trackMix2 setVolume:_musicVolume atTime:kCMTimeZero];
        [trackMixArray addObject:trackMix2];
    }
    
    audioMix.inputParameters = trackMixArray;
    videoComposition.instructions = instructions;
}

- (void)setVideoVolume:(CGFloat)volume {
    // https://stackoverflow.com/questions/33347256/avmutableaudiomixinputparameters-setvolume-doesnt-work-with-audio-file-ios-9
    NSMutableArray *allAudioParams = [NSMutableArray array];
    
    AVMutableAudioMixInputParameters *audioInputParams =
    [AVMutableAudioMixInputParameters audioMixInputParameters];
    [audioInputParams setTrackID:_comTrack1.trackID];
    _videoVolume = volume;
    [audioInputParams setVolume:_videoVolume atTime:kCMTimeZero];
    [allAudioParams addObject:audioInputParams];
    
    AVMutableAudioMixInputParameters *audioInputParams2 =
    [AVMutableAudioMixInputParameters audioMixInputParameters];
    [audioInputParams2 setTrackID:_comTrack2.trackID];
    [audioInputParams2 setVolume:_musicVolume atTime:kCMTimeZero];
    [allAudioParams addObject:audioInputParams2];
    
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    [audioMix setInputParameters:allAudioParams];
    
    [_currentItem setAudioMix:audioMix];
}

- (void)setMusicVolume:(CGFloat)volume {
    NSMutableArray *allAudioParams = [NSMutableArray array];
    
    AVMutableAudioMixInputParameters *audioInputParams =
    [AVMutableAudioMixInputParameters audioMixInputParameters];
    [audioInputParams setTrackID:_comTrack1.trackID];
    [audioInputParams setVolume:_videoVolume atTime:kCMTimeZero];
    [allAudioParams addObject:audioInputParams];
    
    AVMutableAudioMixInputParameters *audioInputParams2 =
    [AVMutableAudioMixInputParameters audioMixInputParameters];
    [audioInputParams2 setTrackID:_comTrack2.trackID];
    _musicVolume = volume;
    [audioInputParams2 setVolume:_musicVolume atTime:kCMTimeZero];
    [allAudioParams addObject:audioInputParams2];
    
    
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    [audioMix setInputParameters:allAudioParams];
    
    [_currentItem setAudioMix:audioMix];
}

- (void)buildCompositionObjectsForPlayback
{
    if (!self.videoAsset) {
        self.composition = nil;
        self.videoComposition = nil;
        return;
    }
    
    AVAssetTrack *videoTrack = [[self.videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    CGSize naturalSize = videoTrack.naturalSize;
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;
    AVMutableAudioMix *audioMix = nil;
    
    composition.naturalSize = naturalSize;
    
    videoComposition = [AVMutableVideoComposition videoComposition];
    audioMix = [AVMutableAudioMix audioMix];
    
    [self buildTransitionComposition:composition andVideoComposition:videoComposition andAudioMix:audioMix];
    
    if (videoComposition) {
        videoComposition.frameDuration = CMTimeMake(1, 30);
        videoComposition.renderSize = naturalSize;
    }
    
    self.composition = composition;
    self.videoComposition = videoComposition;
    self.audioMix = audioMix;
}

- (AVPlayerItem *)playerItem {
    if (!_currentItem) {
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:self.composition];
        playerItem.videoComposition = self.videoComposition;
//        playerItem.audioMix = self.audioMix;
        _currentItem = playerItem;
    }
    return _currentItem;
}

- (void)exportAtPath:(NSString *)outputPath completion:(void (^)(BOOL success))completion {    if (!outputPath) {
        completion(NO);
        return;
    }
    
    NSURL *outputFileUrl = [NSURL fileURLWithPath:outputPath];
    
    AVAssetExportSession *_assetExport =[[AVAssetExportSession alloc]initWithAsset:self.composition presetName:AVAssetExportPreset640x480];
    _assetExport.outputFileType = AVFileTypeMPEG4;
    _assetExport.audioMix = _currentItem.audioMix;
    _assetExport.outputURL = outputFileUrl;
    _assetExport.shouldOptimizeForNetworkUse = YES;
    
    [_assetExport exportAsynchronouslyWithCompletionHandler:^{
        
        NSLog(@"=========================== \n AVAssetExportSession exportAsynchronouslyWithCompletionHandler Status %ld",(long)_assetExport.status);
        switch (_assetExport.status) {
            case AVAssetExportSessionStatusUnknown:
                NSLog(@"exporter Unknow");
                break;
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"exporter Canceled");
                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@"exporter Failed");
                break;
            case AVAssetExportSessionStatusWaiting:
                NSLog(@"exporter Waiting");
                break;
            case AVAssetExportSessionStatusExporting:
                NSLog(@"exporter Exporting");
                break;
            case AVAssetExportSessionStatusCompleted:
                NSLog(@"exporter Completed");
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES);
                });
                break;
        }
    }];
}

- (AVPlayerItem *)playerItemWithMainTrack:(MediaTrack *)mainTrack {
    uint32_t timeScale = TIME_BASE;
    AVMutableComposition *composition = [AVMutableComposition composition];
    self.composition = composition;
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    self.videoComposition = videoComposition;
    videoComposition.renderSize = CGSizeMake(720, 405);
    videoComposition.frameDuration = CMTimeMake(1, 30);
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    NSMutableArray *layerInstructions = [[NSMutableArray alloc] init];
    unsigned int totalDuration = 0;
    for (int i = 0; i < mainTrack.segments.count; i ++) {
        MediaSegment *seg = mainTrack.segments[i];
        AVAsset *videoAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:[seg segmentFindVideo].path]];
        CMTime inPoint = CMTimeMake(seg.target_timerange.start, timeScale);
        CMTime trimIn = CMTimeMake(seg.source_timerange.start, timeScale);
        CMTime trimDuration = CMTimeMake(seg.source_timerange.duration, timeScale);
        AVAssetTrack *assetVideoTrack = [videoAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (assetVideoTrack) {
            AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [videoTrack insertTimeRange:CMTimeRangeMake(trimIn, trimDuration) ofTrack:assetVideoTrack atTime:inPoint error:nil];
            [videoTrack setPreferredTransform:assetVideoTrack.preferredTransform];
            AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
            [layerInstructions addObject:passThroughLayer];
            totalDuration = totalDuration + CMTimeGetSeconds([videoAsset duration]);
        }
    }
    instruction.layerInstructions = layerInstructions;
    CMTime duration = CMTimeMake(totalDuration * 10 * timeScale, timeScale);
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
    videoComposition.instructions = @[instruction];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:[composition copy]];
    return playerItem;
}


@end
