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

@interface ViewController ()<EditorffmpegReaderDelegate,MR0x31FFMpegMovieDelegate,MediaBottomActionViewDelegate> {
    
    dispatch_source_t video_render_timer;
    dispatch_queue_t video_render_dispatch_queue;
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

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
//    self.audioPlayer = [[EditorAudioPlayer alloc] init];
//    [self.audioPlayer play];
//    [FFMpegTool copytest];
//    return;
    
    [self setupPreView];
    [self setupPlaycontrol];
    [self setupMainTrack];
    [self setupResource];
    [self setupTimer];
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
        [self.movieWrite finishRecording];
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
