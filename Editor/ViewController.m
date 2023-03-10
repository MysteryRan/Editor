//
//  ViewController.m
//  Editor
//
//  Created by zouran on 2022/5/10.
//

#import "ViewController.h"
#import "RanMediaTimeline.h"
#import "GPUImage.h"
#import <Photos/Photos.h>
#import "FlowerFilter.h"
#import "GPUImagePicture+TextureSubimage.h"

#import "EditorData.h"
#import "MediaInfo.h"
#import "EditorffmpegReader.h"
#import "MediaTimeRange.h"
#import "EditorTransition.h"
#import "FFMpegTool.h"
#import "NSString+RanAdditions.h"
#import "MR0x31FFMpegMovie.h"
#import "EditorSticker.h"

#import "EditorAudioPlayer.h"
#import "FFPlayPlayer.h"
#import "EditorMovieWrite.h"

#import "LCPlayer.h"
#import "MutilpleTrackContentView.h"
#import "MediaBottomActionView.h"
#import "GuidelineView.h"

#import "FFPlayer0x20.h"
#import "FFPlayer0x32.h"
#import "MR0x32AudioRenderer.h"

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 1

#ifndef __weakSelf__
#define __weakSelf__  __weak    typeof(self)weakSelf = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__ __strong typeof(weakSelf)self = weakSelf;
#endif

@interface ViewController ()<EditorffmpegReaderDelegate,MR0x31FFMpegMovieDelegate,MediaBottomActionViewDelegate,FFPlayer0x20Delegate,FFPlayer0x32Delegate> {
    
    dispatch_source_t video_render_timer;
    dispatch_queue_t video_render_dispatch_queue;
    
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

@property(nonatomic, strong) UIView *preBackgroundView;
@property(nonatomic, strong) UIView *editorControlBar;
@property(nonatomic, strong) GPUImageView *gpuPreView;

@property (nonatomic, strong)EditorffmpegReader *ffmpegReader;

@property (nonatomic, strong) EditorData *editorData;

@property (nonatomic, strong) MediaSegment *firstSegment;
@property (nonatomic, strong) MediaSegment *secondSegment;

@property (nonatomic, strong) EditorffmpegReader *secondReader;

@property (nonatomic, strong) GPUImageFilter *currentFilter;
@property (nonatomic, strong) GPUImageFilter *nextFilter;

@property (nonatomic, strong) GPUImageFilter *pipFilter;

@property (nonatomic, strong) GPUImageTwoInputFilter *transitionFilter;


@property (nonatomic, strong) MR0x31FFMpegMovie *firstMovie;
@property (nonatomic, strong) MR0x31FFMpegMovie *secondMovie;

@property (nonatomic, assign) uint64_t lastDuration;
@property (nonatomic, strong) GPUImageTwoInputFilter *currentTrans;

@property (nonatomic, strong) GPUImagePicture *picsss;

@property (nonatomic, strong) GPUImageTransformFilter *picTrans;


@property (nonatomic, strong) EditorAudioPlayer *audioPlayer;
@property (nonatomic, strong) GPUImageFilterPipeline *pipeLine;

@property (nonatomic, strong) RanMediaTimeline *timelineView;

@property (nonatomic, assign) CGFloat contentOffset;


@property (nonatomic, strong) FFPlayPlayer *ffplayer;

@property (nonatomic, strong) EditorMovieWrite *movieWrite;

@property (nonatomic, strong) LCPlayer *llplayer;

@property (nonatomic, strong) EditorffmpegReader *pipReader;
@property (nonatomic, strong) MutilpleTrackContentView *trackContentView;

@property (nonatomic, strong) GPUImageMovieWriter *originMoviewrite;

@property (nonatomic, assign) uint64_t totalSecond;
@property (nonatomic, strong) UILabel *currentTimeLab;


@property (nonatomic, strong) FFPlayer0x32 *player;

@property (nonatomic, strong) FFPlayer0x20 *erluplayer;

@property (assign, nonatomic) NSInteger ignoreScrollBottom;
@property (weak, nonatomic) NSTimer *timer;
@property (assign) MR_PACKET_SIZE pktSize;


//声音大小
@property (nonatomic,assign) float outputVolume;
//最终音频格式（采样深度）
@property (nonatomic,assign) MRSampleFormat finalSampleFmt;
//音频渲染
@property (nonatomic,assign) AudioUnit audioUnit;
//采样率
@property (nonatomic,assign) int targetSampleRate;

@property (nonatomic, strong) MR0x32AudioRenderer *audioRender;
@property (nonatomic, assign) BOOL started;

@end

@implementation ViewController

- (void)dealloc
{
    if (_audioUnit) {
        AudioOutputUnitStop(_audioUnit);
    }
    
    #if DEBUG_RECORD_PCM_TO_FILE
        fclose(file_pcm_l);
        fclose(file_pcm_r);
    #endif
    
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
}

- (void)prepareTickTimerIfNeed
{
    
}

- (void)reveiveAudioToPlay {
    if (!self.started) {
        [self playAudio];
        self.started = true;
    }
}

- (void)playAudio
{
    [self.audioRender paly];
}

- (void)reveiveFrameToRenderer:(CVPixelBufferRef)img
{
    CVPixelBufferRetain(img);
    dispatch_sync(dispatch_get_main_queue(), ^{
        CVPixelBufferRelease(img);
    });
    
    if (!self.started) {
        [self playAudio];
        self.started = true;
    }
}

- (void)onInitAudioRender:(MRSampleFormat)fmt
{
    dispatch_async(dispatch_get_main_queue(), ^{
//        [self setupAudioRender:fmt];
        [self playAudio];
        [self setupAudioRendernew:fmt];
    });
}

- (void)setupAudioRendernew:(MRSampleFormat)fmt {
    
    __weakSelf__
    [self.audioRender onFetchPacketSample:^UInt32(uint8_t * _Nonnull buffer, UInt32 bufferSize) {
        __strongSelf__
        UInt32 filled = [self.player fetchPacketSample:buffer wantBytes:bufferSize];
        return filled;
    }];

    [self.audioRender onFetchPlanarSample:^UInt32(uint8_t * _Nonnull left, UInt32 leftSize, uint8_t * _Nonnull right, UInt32 rightSize) {
        __strongSelf__
        UInt32 filled = [self.player fetchPlanarSample:left leftSize:leftSize right:right rightSize:rightSize];
        return filled;
    }];
}

- (void)setupAudioRender:(MRSampleFormat)fmt
{
    _outputVolume = [[AVAudioSession sharedInstance]outputVolume];
        
    {
        [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
        //        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        //        [[AVAudioSession sharedInstance]addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];
        
        [[AVAudioSession sharedInstance]setActive:YES error:nil];
    }
    
    {
        // ----- Audio Unit Setup -----
        
#define kOutputBus 0 //Bus 0 is used for the output side
#define kInputBus  1 //Bus 0 is used for the output side
        
        // Describe the output unit.
        
        AudioComponentDescription desc = {0};
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        
        // Get component
        AudioComponent component = AudioComponentFindNext(NULL, &desc);
        OSStatus status = AudioComponentInstanceNew(component, &_audioUnit);
        NSAssert(noErr == status, @"AudioComponentInstanceNew");
        
        AudioStreamBasicDescription outputFormat;
        
        UInt32 size = sizeof(outputFormat);
        // 获取默认的输入信息
        AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &outputFormat, &size);
        //设置采样率
        outputFormat.mSampleRate = _targetSampleRate;
        /**不使用视频的原声道数_audioCodecCtx->channels;
         mChannelsPerFrame 这个值决定了后续AudioUnit索要数据时 ioData->mNumberBuffers 的值！
         如果写成1会影响Planar类型，就不会开两个buffer了！！因此这里写死为2！
         */
        outputFormat.mChannelsPerFrame = 2;
        outputFormat.mFormatID = kAudioFormatLinearPCM;
        outputFormat.mReserved = 0;
        
        bool isFloat  = MR_Sample_Fmt_Is_FloatX(fmt);
        bool isS16    = MR_Sample_Fmt_Is_S16X(fmt);
        bool isPlanar = MR_Sample_Fmt_Is_Planar(fmt);
        
        if (isS16){
            outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger;
            outputFormat.mFramesPerPacket = 1;
            outputFormat.mBitsPerChannel = sizeof(SInt16) * 8;
        } else if (isFloat){
            outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
            outputFormat.mFramesPerPacket = 1;
            outputFormat.mBitsPerChannel = sizeof(float) * 8;
        } else {
            NSAssert(NO, @"不支持的音频采样格式%d",fmt);
        }
        
        if (isPlanar) {
            outputFormat.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
            outputFormat.mBytesPerFrame = outputFormat.mBitsPerChannel / 8;
            outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
        } else {
            outputFormat.mFormatFlags |= kAudioFormatFlagIsPacked;
            outputFormat.mBytesPerFrame = (outputFormat.mBitsPerChannel / 8) * outputFormat.mChannelsPerFrame;
            outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
        }
        
        status = AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             kOutputBus,
                             &outputFormat, size);
        NSAssert(noErr == status, @"AudioUnitSetProperty");
        //get之后刷新这个值；
        //_targetSampleRate  = (int)outputFormat.mSampleRate;
        
        UInt32 flag = 0;
        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, sizeof(flag));
        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kInputBus, &flag, sizeof(flag));
        // Slap a render callback on the unit
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = MRRenderCallback;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        
        status = AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             kOutputBus,
                             &callbackStruct,
                             sizeof(callbackStruct));
        NSAssert(noErr == status, @"AudioUnitSetProperty");
        status = AudioUnitInitialize(_audioUnit);
        NSAssert(noErr == status, @"AudioUnitInitialize");
#undef kOutputBus
#undef kInputBus
        
        self.finalSampleFmt = fmt;
    }
}

#pragma mark - 音频

//音频渲染回调；
static inline OSStatus MRRenderCallback(void *inRefCon,
                                        AudioUnitRenderActionFlags    * ioActionFlags,
                                        const AudioTimeStamp          * inTimeStamp,
                                        UInt32                        inOutputBusNumber,
                                        UInt32                        inNumberFrames,
                                        AudioBufferList                * ioData)
{
    ViewController *am = (__bridge ViewController *)inRefCon;
    
    return NO;
    return [am renderFrames:inNumberFrames ioData:ioData];
}

- (bool)renderFrames:(UInt32) wantFrames
              ioData:(AudioBufferList *) ioData
{
    // 1. 将buffer数组全部置为0；
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        AudioBuffer audioBuffer = ioData->mBuffers[iBuffer];
        bzero(audioBuffer.mData, audioBuffer.mDataByteSize);
    }
    
    //目标是Packet类型
    if(MR_Sample_Fmt_Is_Packet(self.finalSampleFmt)){
    
        //    numFrames = 1115
        //    SInt16 = 2;
        //    mNumberChannels = 2;
        //    ioData->mBuffers[iBuffer].mDataByteSize = 4460
        // 4460 = numFrames x SInt16 * mNumberChannels = 1115 x 2 x 2;
        
        // 2. 获取 AudioUnit 的 Buffer
        int numberBuffers = ioData->mNumberBuffers;
        
        // AudioUnit 对于 packet 形式的PCM，只会提供一个 AudioBuffer
        if (numberBuffers >= 1) {
            
            AudioBuffer audioBuffer = ioData->mBuffers[0];
            //这个是 AudioUnit 给我们提供的用于存放采样点的buffer
            uint8_t *buffer = audioBuffer.mData;
            // 长度可以这么计算，也可以使用 audioBuffer.mDataByteSize 获取
            //                //每个采样点占用的字节数:
            //                UInt32 bytesPrePack = self.outputFormat.mBitsPerChannel / 8;
            //                //Audio的Frame是包括所有声道的，所以要乘以声道数；
            //                const NSUInteger frameSizeOf = 2 * bytesPrePack;
            //                //向缓存的音频帧索要wantBytes个音频采样点: wantFrames x frameSizeOf
            //                NSUInteger bufferSize = wantFrames * frameSizeOf;
            const UInt32 bufferSize = audioBuffer.mDataByteSize;
            /* 对于 AV_SAMPLE_FMT_S16 而言，采样点是这么分布的:
             S16_L,S16_R,S16_L,S16_R,……
             AudioBuffer 也需要这样的排列格式，因此直接copy即可；
             同理，对于 FLOAT 也是如此左右交替！
             */
            
            //3. 获取 bufferSize 个字节，并塞到 buffer 里；
            [self fetchPacketSample:buffer wantBytes:bufferSize];
        } else {
            NSLog(@"what's wrong?");
        }
    }
    
    //目标是Planar类型，Mac平台支持整形和浮点型，交错和二维平面
    
    else if (MR_Sample_Fmt_Is_Planar(self.finalSampleFmt)){
        
        //    numFrames = 558
        //    float = 4;
        //    ioData->mBuffers[iBuffer].mDataByteSize = 2232
        // 2232 = numFrames x float = 558 x 4;
        // FLTP = FLOAT + Planar;
        // FLOAT: 具体含义是使用 float 类型存储量化的采样点，比 SInt16 精度要高出很多！当然空间也大些！
        // Planar: 二维的，所以会把左右声道使用两个数组分开存储，每个数组里的元素是同一个声道的！
        
        //when outputFormat.mChannelsPerFrame == 2
        if (ioData->mNumberBuffers == 2) {
            // 2. 向缓存的音频帧索要 ioData->mBuffers[0].mDataByteSize 个字节的数据
            /*
             Float_L,Float_L,Float_L,Float_L,……  -> mBuffers[0].mData
             Float_R,Float_R,Float_R,Float_R,……  -> mBuffers[1].mData
             左对左，右对右
             
             同理，对于 S16P 也是如此！一一对应！
             */
            //3. 获取左右声道数据
            [self fetchPlanarSample:ioData->mBuffers[0].mData leftSize:ioData->mBuffers[0].mDataByteSize right:ioData->mBuffers[1].mData rightSize:ioData->mBuffers[1].mDataByteSize];
        }
        //when outputFormat.mChannelsPerFrame == 1;不会左右分开
        else {
            [self fetchPlanarSample:ioData->mBuffers[0].mData leftSize:ioData->mBuffers[0].mDataByteSize right:NULL rightSize:0];
        }
    }
    return noErr;
}

- (UInt32)fetchPacketSample:(uint8_t*)buffer
                  wantBytes:(UInt32)bufferSize
{
    UInt32 filled = [self.player fetchPacketSample:buffer wantBytes:bufferSize];
    
    #if DEBUG_RECORD_PCM_TO_FILE
    fwrite(buffer, 1, filled, self->file_pcm_l);
    #endif
    return filled;
}

- (UInt32)fetchPlanarSample:(uint8_t*)left
                  leftSize:(UInt32)leftSize
                     right:(uint8_t*)right
                 rightSize:(UInt32)rightSize
{
    UInt32 filled = [self.player fetchPlanarSample:left leftSize:leftSize right:right rightSize:rightSize];
    #if DEBUG_RECORD_PCM_TO_FILE
    fwrite(left, 1, leftSize, self->file_pcm_l);
    fwrite(right, 1, rightSize, self->file_pcm_r);
    
    fflush(self->file_pcm_l);
    fflush(self->file_pcm_r);
    #endif
    return filled;
}


- (void)play_one {
    //设置采样率
    [[AVAudioSession sharedInstance] setPreferredSampleRate:44100 error:nil];
    self.targetSampleRate = (int)[[AVAudioSession sharedInstance] sampleRate];
    
#if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm_l == NULL) {
        const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"L.pcm"]UTF8String];
        NSLog(@"%s",l);
        file_pcm_l = fopen(l, "wb+");
    }
    
    if (file_pcm_r == NULL) {
        const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"R.pcm"]UTF8String];
        file_pcm_r = fopen(r, "wb+");
    }
#endif
    
    FFPlayer0x20 *player = [[FFPlayer0x20 alloc] init];
    player.contentPath = [[NSBundle mainBundle] pathForResource:@"longtest" ofType:@"mp3"];
//    player.contentPath = [[NSBundle mainBundle] pathForResource:@"640k" ofType:@"jpg"];
    
    __weakSelf__
    [player onError:^{
        __strongSelf__
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    player.supportedPixelFormats  = MR_PIX_FMT_MASK_NV12;
    
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16P;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_FLT;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_FLTP;
    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_AUTO;
    
    player.supportedSampleRate    = self.targetSampleRate;
    
    player.delegate = self;
    [player prepareToPlay];
    [player play];
    self.player = player;
    
    FFPlayer0x20 *eeplayer = [[FFPlayer0x20 alloc] init];
    eeplayer.contentPath = [[NSBundle mainBundle] pathForResource:@"erlutest" ofType:@"mp3"];
//    player.contentPath = [[NSBundle mainBundle] pathForResource:@"640k" ofType:@"jpg"];
    
    [eeplayer onError:^{

    }];
    eeplayer.supportedPixelFormats  = MR_PIX_FMT_MASK_NV12;
    
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16P;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_FLT;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_FLTP;
    eeplayer.supportedSampleFormats = MR_SAMPLE_FMT_MASK_AUTO;
    
    eeplayer.supportedSampleRate    = self.targetSampleRate;
    
    eeplayer.delegate = self;
    [eeplayer prepareToPlay];
    [eeplayer play];
    self.erluplayer = eeplayer;
    
    [self prepareTickTimerIfNeed];
}



- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
//    self.audioPlayer = [[EditorAudioPlayer alloc] init];
//    [self.audioPlayer play];
//    [FFMpegTool openStreamFunc:@""];
//    return;
    
    self.audioRender = [MR0x32AudioRenderer new];
    [self.audioRender setPreferredAudioQueue:NO];
    [self.audioRender active];
    //播放器使用的采样率
    [self.audioRender setupWithFmt:MR_SAMPLE_FMT_FLTP sampleRate:44100];
    
    [self player_eee];
    
//    [self setupAudioRender:MR_SAMPLE_FMT_FLTP];
//    OSStatus status = AudioOutputUnitStart(_audioUnit);
//    NSAssert(noErr == status, @"AudioOutputUnitStart");
    return;
    [self setupPreView];
    [self setupPlaycontrol];
    [self setupMainTrack];
    [self setupResource];
    [self setupTimer];
}

- (void)player_eee {
    FFPlayer0x32 *player = [[FFPlayer0x32 alloc] init];
//    player.contentPath = [[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"];
    player.contentPath = [[NSBundle mainBundle] pathForResource:@"Movie2" ofType:@"m4v"];
    //player.contentPath = @"http://localhost:8080/ffmpeg-test/xp5.mp4";
    
    __weakSelf__
    [player onError:^{
        __strongSelf__
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    
    [player onVideoEnds:^{
        __strongSelf__
        [self.player asyncStop];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    player.supportedPixelFormats  = MR_PIX_FMT_MASK_NV21;
    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_AUTO;
//    for test fmt.
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16 | MR_SAMPLE_FMT_MASK_FLT;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16P;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_FLTP;
    
    //设置采样率，如果播放之前知道音频的采样率，可以设置成实际的值，可避免播放器内部转换！
    int sampleRate = [MR0x32AudioRenderer setPreferredSampleRate:44100];
    player.supportedSampleRate = sampleRate;
    
    player.delegate = self;
    [player prepareToPlay];
    self.player = player;
}

- (void)mutilAudio {
    self.audioPlayer = [[EditorAudioPlayer alloc] init];
    [self.audioPlayer play];
}

- (void)setupTimer {
    double fps = 30.0;
    uint64_t av_time_base = 1000000;
    __block float time = 0;
    if(self->video_render_timer) {
        dispatch_source_cancel(self->video_render_timer);
    }
    self->video_render_dispatch_queue = dispatch_queue_create("render queue", DISPATCH_QUEUE_CONCURRENT);
    self->video_render_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, video_render_dispatch_queue);
    float duration = 1.0 / fps * av_time_base;
    dispatch_source_set_timer(self->video_render_timer, DISPATCH_TIME_NOW, (1.0 / fps) * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(self->video_render_timer, ^{
        if (time == 0) {
            self.ffmpegReader = [[EditorffmpegReader alloc] init];
            self.ffmpegReader.resourceTimeRange = [self.firstSegment getAVFoundationTargetTimeRange];
            self.currentFilter = [self.ffmpegReader startWith:self.firstSegment];
            [self.currentFilter addTarget:self.gpuPreView];
            self.movieWrite = [[EditorMovieWrite alloc] initWithMovieURL:[NSURL URLWithString:@""] size:CGSizeMake(1920, 1080)];
                [self.currentFilter addTarget:self.movieWrite];
                [self.movieWrite startRecording];
        }
        uint64_t current_time = round(time);
        [self trackControlWithTime:current_time];
        [self effectsControlWithTime:current_time];
        time = time + duration;
    });
}

- (void)effectsControlWithTime:(uint64_t)time {
    double fps = 30.0;
    uint64_t av_time_base = 1000000;
    float perFrame = 1.0 / fps * av_time_base;
    
    for (int i = 0; i < self.editorData.tracks.count; i ++) {
        MediaTrack *track = self.editorData.tracks[i];
        if (track.type == MediaTrackTypeEffect) {
            for (int j = 0; j < track.segments.count; j ++) {
                MediaSegment *effectSeg = track.segments[j];
                uint64_t distance = time - effectSeg.target_timerange.start;
                if (distance < perFrame && distance > 0) {
                    if (CMTimeRangeContainsTime(self.ffmpegReader.resourceTimeRange, [effectSeg getAVFoundationTargetTimeStart])) {
                        [self.ffmpegReader addFilterBySegment:effectSeg];
                    }
                    
                    
//                    if (track.type == MediaTrackTypeVideo) {
//                        for (int k = 0; k < track.segments.count; k ++) {
//                            MediaSegment *videoSeg = track.segments[k];
//                            CMTimeRange videoRange = [videoSeg getAVFoundationTargetTimeRange];
//                            if (CMTimeRangeContainsTime(videoRange, [effectSeg getAVFoundationTargetTimeStart])) {
//
//
//                            }
//                        }
//                    }
                }
                
                uint64_t removedistance = time - (effectSeg.target_timerange.start + effectSeg.target_timerange.duration);
                if (removedistance < perFrame && distance > 0) {
                    if (CMTimeRangeContainsTime(self.ffmpegReader.resourceTimeRange, [effectSeg getAVFoundationTargetTimeStart])) {
                        [self.ffmpegReader removeFilterBySegment:effectSeg];
                    }
                }
            }
        }
    }
}

- (void)trackControlWithTime:(uint64_t)time {
//    NSLog(@"timer pts %lld",time);
    double fps = 30.0;
    uint64_t av_time_base = 1000000;
    float perFrame = 1.0 / fps * av_time_base;
    
    if (time > self.totalSecond) {
        dispatch_suspend(self->video_render_timer);
//        [self.movieWrite finishRecording];
        return;
    }
    
    // 每秒长度 / 总长度 = 每秒时间 / 总时间
    dispatch_async(dispatch_get_main_queue(), ^{
        double offsetX = 0;
        CGFloat f_time = (CGFloat)time;
        CGFloat f_totalSecond = (CGFloat)self.totalSecond;
        CGFloat progress = (CGFloat)(f_time / f_totalSecond);
        offsetX = progress * (self.timelineView.contentSize.width - self.view.frame.size.width);
        [self.timelineView setContentOffset:CGPointMake(offsetX, 0)];
        self.currentTimeLab.text = [self convertSecondsTimecode:time];
    });
    
    NSUInteger index = [self.editorData.tracks[0].segments indexOfObject:self.firstSegment];
    NSMutableArray *transtions = self.editorData.materials.transitions;
    int64_t tran_duration = 0;
    EditorTransition *transi;
    if (index >= 0 && index < transtions.count) {
        transi = self.editorData.materials.transitions[index];
        tran_duration = transi.duration;
    }
    
    if (!self.secondSegment) {
        return;
    }
    
    uint64_t distance = time - (self.secondSegment.target_timerange.start);
    
    // 刚转场
    if (distance <= perFrame && distance > 0) {
        // 前一个
        [self.currentFilter removeAllTargets];
        // 开始解码下一个了
        // 后一个
        self.secondReader = [[EditorffmpegReader alloc] init];
        self.nextFilter = [self.secondReader startWith:self.secondSegment];
        // 有转场
        if (tran_duration > 0) {
            //初始化转场
            self.transitionFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromFilePath:transi.path];
            [self.currentFilter addTarget:self.transitionFilter];
            [self.nextFilter addTarget:self.transitionFilter];
            
            [self.transitionFilter addTarget:self.gpuPreView];
            [self.transitionFilter addTarget:self.movieWrite];
        } else {
            [self.nextFilter addTarget:self.gpuPreView];
            [self.nextFilter addTarget:self.movieWrite];
        }
    }
    // 转场中
    if (tran_duration > 0) {
        if (time >= self.secondSegment.target_timerange.start && time <= self.secondSegment.target_timerange.start + tran_duration) {
            uint64_t dur_time = (time - self.secondSegment.target_timerange.start);
            double percent = dur_time / (tran_duration * 1.0);
            [self.transitionFilter setFloat:percent forUniformName:@"maintime"];
        }
        
        // 转场后
        distance = time - (self.secondSegment.target_timerange.start + tran_duration);
        if (distance <= perFrame && distance > 0) {
            [self.currentFilter removeAllTargets];
            [self.nextFilter removeAllTargets];
            [self.transitionFilter removeAllTargets];
            [self.nextFilter addTarget:self.gpuPreView];
            [self.nextFilter addTarget:self.movieWrite];
        }
    }
}

- (void)setupPreView {
    self.preBackgroundView = [UIView new];
    self.preBackgroundView.backgroundColor = [UIColor colorWithRed:24/255.0 green:24/255.0 blue:24/255.0 alpha:1];
    [self.view addSubview:self.preBackgroundView];
    CGFloat topOffset = [UIApplication sharedApplication].windows.firstObject.safeAreaInsets.top;
    [self.preBackgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(topOffset);
        make.left.right.equalTo(self.view);
        make.height.equalTo(self.preBackgroundView.mas_width);
    }];
    
    self.editorData = [EditorData sharedInstance];
    CanvasConfig *config = self.editorData.canvas_config;
    float width = config.width;
    float height = config.height;
    self.gpuPreView = [[GPUImageView alloc] init];
//    [self.gpuPreView setBackgroundColorRed:1 green:0 blue:0 alpha:1];
    self.gpuPreView.fillMode = kGPUImageFillModeStretch;
    [self.preBackgroundView addSubview:self.gpuPreView];
    [self.gpuPreView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.bottom.right.lessThanOrEqualTo(self.preBackgroundView).priorityLow();
        make.center.equalTo(self.preBackgroundView);
        make.height.lessThanOrEqualTo(self.preBackgroundView);
        make.width.equalTo(self.gpuPreView.mas_height).multipliedBy(width/height);
//        make.width.equalTo(self.gpuPreView.mas_height).multipliedBy(1080.0/1620.0);
    }];
    
//    GuidelineView *guideline = [[GuidelineView alloc] init];
//    guideline.backgroundColor = [UIColor redColor];
//    [self.preBackgroundView addSubview:guideline];
//    [guideline mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.edges.equalTo(self.preBackgroundView);
//    }];
    
//    UIView *v = [UIView new];
//    v.layer.borderWidth = 2;
//    v.layer.borderColor = [UIColor redColor].CGColor;
//    [self.gpuPreView addSubview:v];
//    [v mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.center.equalTo(self.gpuPreView);
//        make.width.equalTo(self.gpuPreView).multipliedBy(1);
//        make.height.equalTo(self.gpuPreView).multipliedBy(1);
//    }];
}

- (void)setupPlaycontrol {
    self.editorControlBar = [UIView new];
    [self.view addSubview:self.editorControlBar];
    [self.editorControlBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.top.equalTo(self.preBackgroundView.mas_bottom);
        make.height.mas_equalTo(40);
    }];
    
    self.currentTimeLab = [UILabel new];
    [self.editorControlBar addSubview:self.currentTimeLab];
    self.currentTimeLab.text = @"00:00";
    self.currentTimeLab.font = [UIFont fontWithName:@"PingFangSC-Regular" size:12];
    [self.currentTimeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.editorControlBar).offset(12);
        make.centerY.equalTo(self.editorControlBar);
    }];
    
    UILabel *centerLab = [UILabel new];
    [self.editorControlBar addSubview:centerLab];
    centerLab.text = @"/";
    centerLab.font = [UIFont fontWithName:@"PingFangSC-Regular" size:12];
    [centerLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.currentTimeLab.mas_right).offset(2);
        make.centerY.equalTo(self.editorControlBar);
    }];
    
    UILabel *totalTimeLab = [UILabel new];
    [self.editorControlBar addSubview:totalTimeLab];
    totalTimeLab.font = [UIFont fontWithName:@"PingFangSC-Regular" size:12];
    [totalTimeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(centerLab.mas_right).offset(2);
        make.centerY.equalTo(self.editorControlBar);
    }];
    
    self.editorData = [EditorData sharedInstance];
    MediaTrack *mainTrack = self.editorData.tracks[0];
    MediaSegment *lastSeg = mainTrack.segments.lastObject;
    uint64_t timeNum = lastSeg.target_timerange.start + lastSeg.target_timerange.duration;
    totalTimeLab.text = [self convertSecondsTimecode:timeNum];
    self.totalSecond = timeNum;
    
    UIButton *playButton = [UIButton new];
    [playButton setImage:[UIImage imageNamed:@"ms_play_icon"] forState:UIControlStateNormal];
    [playButton setImage:[UIImage imageNamed:@"ms_pause_icon"] forState:UIControlStateSelected];
    [playButton addTarget:self action:@selector(playButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.editorControlBar addSubview:playButton];
    [playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.editorControlBar);
        make.top.bottom.equalTo(self.editorControlBar);
        make.width.mas_equalTo(30);
    }];
    
    UIButton *keyFrameButton = [UIButton new];
    
    UIButton *undoButton = [UIButton new];
    
    UIButton *redoButton = [UIButton new];
    
    UIButton *fullScreenButton = [UIButton new];
    
    UIStackView *rightControl = [UIStackView new];
    rightControl.spacing = 10;
    rightControl.distribution = UIStackViewDistributionFillEqually;
    [rightControl addArrangedSubview:keyFrameButton];
    [rightControl addArrangedSubview:undoButton];
    [rightControl addArrangedSubview:redoButton];
    [rightControl addArrangedSubview:fullScreenButton];
    [self.editorControlBar addSubview:rightControl];
    [rightControl mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.right.equalTo(self.editorControlBar);
        make.width.mas_equalTo(130);
    }];
}


- (NSString *_Nullable)convertSecondsTimecode:(int64_t)seconds {
    seconds = seconds / 1000000;
    int min = (int)seconds / 60;
    int sec = (int)seconds % 60;
    if (min >= 10 && sec >= 10)
        return [NSString stringWithFormat:@"%d:%d", min, sec];
    else if (min >= 10)
        return [NSString stringWithFormat:@"%d:0%d", min, sec];
    else if (sec >= 10)
        return [NSString stringWithFormat:@"0%d:%d", min, sec];
    else
        return [NSString stringWithFormat:@"0%d:0%d", min, sec];
}

- (void)playButtonClick:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.isSelected) {
        [self.audioPlayer play];
        dispatch_resume(self->video_render_timer);
        sender.enabled = FALSE;
    }
    
}

- (void)setupMainTrack {
    self.timelineView = [[RanMediaTimeline alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.timelineView];
    [self.timelineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.editorControlBar.mas_bottom);
        make.left.right.bottom.equalTo(self.view);
    }];
    
    UIView *playHead = [UIView new];
    playHead.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:playHead];
    [playHead mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(self.timelineView);
        make.width.mas_equalTo(2);
        make.centerX.equalTo(self.view);
    }];
    
    UIEdgeInsets bottomEdge;
    if (@available(iOS 11.0, *)) {
        bottomEdge = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
    }
    bottomEdge = UIEdgeInsetsZero;
    
    MediaBottomActionView *bottomView = [MediaBottomActionView new];
    bottomView.delegate = self;
    [self.view addSubview:bottomView];
    [bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view).offset(-bottomEdge.bottom);
        make.height.mas_equalTo(90);
    }];
    [bottomView reloadDataByType:kBottomHomeType];
}

- (void)setupResource {
    self.editorData = [EditorData sharedInstance];
    MediaTrack *mainTrack = self.editorData.tracks[0];
    
    self.audioPlayer = [[EditorAudioPlayer alloc] initWithMediaTrack:mainTrack];
   
    for (int i = 0; i < mainTrack.segments.count; i ++) {
        MediaSegment *segment = mainTrack.segments[i];
        if (i == 0) {
            self.firstSegment = segment;
        }
        if (i == 1) {
            self.secondSegment = segment;
        }
    }
    
    [self.timelineView initSubviewsWithSegments:mainTrack.segments];
    
    [self addTrackSegment:nil];
    
//    self.timelineView.delegate = self;
    
    
//    MediaTrack *effectTrack = [[MediaTrack alloc] init];
//    effectTrack.type = MediaTrackTypeEffect;
//
//    MediaTrack *effectTrack1 = [[MediaTrack alloc] init];
//    effectTrack1.type = MediaTrackTypeEffect;
//
//    MediaSegment *effectSegment = [[MediaSegment alloc] init];
//    effectSegment.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:1000000 timeRangeDuration:3000000];
//
//    MediaSegment *effectSegment1 = [[MediaSegment alloc] init];
//    effectSegment1.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:9000000 timeRangeDuration:3000000];
//    MediaSegment *effectSegment2 = [[MediaSegment alloc] init];
//    effectSegment2.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:14000000 timeRangeDuration:3000000];
//    MediaSegment *effectSegment3 = [[MediaSegment alloc] init];
//    effectSegment3.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:190000000 timeRangeDuration:3000000];
//    MediaSegment *effectSegment4 = [[MediaSegment alloc] init];
//    effectSegment4.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:25000000 timeRangeDuration:3000000];
//    MediaSegment *effectSegment5 = [[MediaSegment alloc] init];
//    effectSegment5.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:30000000 timeRangeDuration:3000000];
//
//    [effectTrack.segments addObject:effectSegment];
//    [effectTrack.segments addObject:effectSegment1];
//    [effectTrack.segments addObject:effectSegment2];
//    [effectTrack.segments addObject:effectSegment3];
//    [effectTrack.segments addObject:effectSegment4];
//    [effectTrack.segments addObject:effectSegment5];
//
//    [effectTrack1.segments addObject:effectSegment1];
//    [effectTrack1.segments addObject:effectSegment2];
//    [effectTrack1.segments addObject:effectSegment3];
    
//    [self.editorData.tracks addObject:effectTrack];
//    [self.editorData.tracks addObject:effectTrack1];
}

// 判断是加在自己的track上 还是开启新的track
- (void)addTrackSegment:(MediaSegment *)segment {
    // 是否相交
    MediaTrackType type = MediaTrackTypeEffect;
    BOOL createNewTrack = FALSE;
    for (int i = 0; i < self.editorData.tracks.count; i ++) {
        MediaTrack *track = self.editorData.tracks[i];
        if (track.type == type) {
            for (int j = 0; j < track.segments.count; j ++) {
                MediaSegment *insideSegment = track.segments[j];
                CMTimeRange Intersection = CMTimeRangeGetIntersection([segment getAVFoundationTargetTimeRange],[insideSegment getAVFoundationTargetTimeRange]);
                if (!CMTimeRangeEqual(Intersection, CMTimeRangeMake(kCMTimeZero, kCMTimeZero))) {
                    NSLog(@"有交集");
                    createNewTrack = YES;
                } else {
                    NSLog(@"无交集");
                    
//                    [track.segments addObject:segment];
                    [self.timelineView reloadDa];
                    return;
                }
            }
        } else {
            createNewTrack = YES;
        }
    }
    
    
    if (createNewTrack) {
//        MediaTrack *track = [[MediaTrack alloc] init];
//        track.type = type;
//        [self.editorData.tracks addObject:track];
//        [track.segments addObject:segment];
    }
    [self.timelineView reloadDa];
    
}

- (void)mediaBottomActionViewClick:(MediaBottomHomeAction)type {
    if (type == kHomeTypeEffect) {
        MediaSegment *effectSegment1 = [[MediaSegment alloc] init];
        effectSegment1.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:0 timeRangeDuration:3000000];
//        MediaSegment *effectSegment2 = [[MediaSegment alloc] init];
//        effectSegment2.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:14000000 timeRangeDuration:3000000];
        
        [self addTrackSegment:effectSegment1];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSLog(@"scrollView.contentSize.x %f",scrollView.contentSize.width);
    NSLog(@"scrollView.contentOffset.x %f",scrollView.contentOffset.x);
}

//是否跨多轨
- (BOOL)videoSegmentContainOtherSegment:(MediaSegment *)segment {
    return YES;
}


@end
