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
#import "NSString+RanAdditions.h"
#import "MR0x31FFMpegMovie.h"
#import "EditorSticker.h"

#import "EditorAudioPlayer.h"
#import "EditorMovieWrite.h"

#import "MutilpleTrackContentView.h"
#import "MediaBottomActionView.h"
#import "GuidelineView.h"
#import "Model/EditorTimeline.h"
#import "VITimelineView+Creator.h"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/pixdesc.h>
#import "EditorFFmpegDecode.h"
#import "Model/GPUImageTwoInputTransitonFilter.h"


@interface ViewController ()<EditorffmpegReaderDelegate,MR0x31FFMpegMovieDelegate,MediaBottomActionViewDelegate,VIRangeViewDelegate, VITimelineViewDelegate,EditorFFmpegDecodeDelegate>

@property(nonatomic, strong) UIView *preBackgroundView;
@property(nonatomic, strong) UIView *editorControlBar;
@property(nonatomic, strong) GPUImageView *gpuPreView;
@property(nonatomic, strong) UILabel *currentTimeLab;
@property (nonatomic, strong) EditorData *editorData;
@property (nonatomic, strong) NSMutableArray *decodes;
@property (nonatomic, strong) GPUImageTwoInputTransitonFilter *transitionFilter;
@property (nonatomic, strong) GPUImageNormalBlendFilter *normalBlendFilter;

@property (nonatomic, strong) NSMutableArray *transformFilters;
@property (nonatomic, strong) VITimelineView *timelineView;

@property (nonatomic, assign) int64_t totalDuration;
@property (nonatomic, strong) GPUImagePicture *pictureInput;


@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.decodes = [NSMutableArray arrayWithCapacity:0];
    self.transformFilters = [NSMutableArray arrayWithCapacity:0];
    
    [self setupPreView];
    [self setupPlaycontrol];
    [self setupResource];
    
    VideoTrack *track = [[VideoTrack alloc] init];
    track.decodeDelegate = self;
    [self.editorData.tracks addObject:track];
    
    NSString *firstFilePath = [[NSBundle mainBundle] pathForResource:@"flower" ofType:@"MP4"];
    NSString *secondFilePath = [[NSBundle mainBundle] pathForResource:@"samplevv" ofType:@"mp4"];

    EditorFFmpegDecode *firstDecode = [track appendClip:firstFilePath trimIn:0 trimOut:3000000];
    EditorFFmpegDecode *secondDecode = [track appendClip:secondFilePath trimIn:0 trimOut:5000000];
    
    //有一个混合转场 减去转场的时间
//    self.totalDuration = (firstDecode.trimOut - firstDecode.trimIn) + (secondDecode.trimOut - secondDecode.trimIn) - 1000000;
    
    //没有转场 直接相加
    self.totalDuration = (firstDecode.trimOut - firstDecode.trimIn) + (secondDecode.trimOut - secondDecode.trimIn);
    
    
    GPUImageTransformFilter *firstAspectFilter = [[GPUImageTransformFilter alloc] init];
    firstAspectFilter.affineTransform = [self aspectTransformForInput:[NSURL fileURLWithPath:firstFilePath] outputSize:CGSizeMake(720, 720)];
    
    GPUImageTransformFilter *secondAspectFilter = [[GPUImageTransformFilter alloc] init];
    secondAspectFilter.affineTransform = [self aspectTransformForInput:[NSURL fileURLWithPath:secondFilePath] outputSize:CGSizeMake(720, 720)];
    

    [self.decodes addObject:firstDecode];
    [self.decodes addObject:secondDecode];
    
    [self.transformFilters addObject:firstAspectFilter];
    [self.transformFilters addObject:secondAspectFilter];
    
    //转场原理
    /*
     切换fliter 单个 多个之间切换
     */
    self.transitionFilter = [[GPUImageTwoInputTransitonFilter alloc] initWithFragmentShaderFromFile:@"Heart"];
    self.normalBlendFilter = [[GPUImageNormalBlendFilter alloc] init];
    [self.transitionFilter setFloat:0 forUniformName:@"maintime"];
    [firstDecode addTarget:firstAspectFilter];
    [secondDecode addTarget:secondAspectFilter];
    
    [firstAspectFilter addTarget:self.gpuPreView];
    [firstDecode beginDecode];
    
//    [secondAspectFilter addTarget:self.gpuPreView];
//    [secondDecode beginDecode];
    
    [self setupMainTrack];
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
    CanvasConfig *config = [CanvasConfig new];
    config.width = 720;
    config.height = 720;
    float width = config.width;
    float height = config.height;
    self.gpuPreView = [[GPUImageView alloc] init];
    self.gpuPreView.fillMode = kGPUImageFillModeStretch;
    [self.preBackgroundView addSubview:self.gpuPreView];
    [self.gpuPreView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.bottom.right.lessThanOrEqualTo(self.preBackgroundView).priorityLow();
        make.center.equalTo(self.preBackgroundView);
        make.height.lessThanOrEqualTo(self.preBackgroundView);
        make.width.equalTo(self.gpuPreView.mas_height).multipliedBy(width/height);
    }];
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
    
//    self.editorData = [EditorData sharedInstance];
//    MediaTrack *mainTrack = self.editorData.tracks[0];
//    MediaSegment *lastSeg = mainTrack.segments.lastObject;
//    uint64_t timeNum = lastSeg.target_timerange.start + lastSeg.target_timerange.duration;
//    totalTimeLab.text = [self convertSecondsTimecode:timeNum];
//    self.totalSecond = timeNum;
//    
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
}

// 计算保持宽高比的变换矩阵
- (CGAffineTransform)aspectTransformForInput:(NSURL *)inputURL outputSize:(CGSize)outputSize {
    // 获取原始视频尺寸
    AVAsset *asset = [AVAsset assetWithURL:inputURL];
    CGSize naturalSize = CGSizeZero;
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (tracks.count > 0) {
        AVAssetTrack *videoTrack = tracks[0];
        naturalSize = videoTrack.naturalSize;
    }
    
    if (CGSizeEqualToSize(naturalSize, CGSizeZero)) {
        return CGAffineTransformIdentity;
    }
    
    // 计算宽高比
    CGFloat videoAspect = naturalSize.width / naturalSize.height;
    CGFloat viewAspect = outputSize.width / outputSize.height;
    
    // 初始化缩放值
    CGFloat xScale = 1.0f;
    CGFloat yScale = 1.0f;
    
    // 计算合适的缩放比例
    if (videoAspect > viewAspect) {
        // 视频比视图宽（横向视频）：缩放高度，上下加黑边
        yScale = viewAspect / videoAspect;
    } else {
        // 视频比视图高（竖向视频）：缩放宽度，左右加黑边
        xScale = videoAspect / viewAspect;
    }
    
    // 创建缩放变换
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformMakeScale(xScale, yScale);
    return transform;
}

/* 有双视频混合转场
- (void)clipCurrentTime:(int64_t)current withDecode:(EditorFFmpegDecode *)deocde {
    //转场默认3s 开始转场时间为1000000
    CMTime time = CMTimeMake(current, AV_TIME_BASE);
    CGFloat offsetX = [self.timelineView calculateOffsetXAtTime:time];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timelineView scrollToContentOffset:CGPointMake(offsetX, 0) animated:YES completion:^{
            
        }];
    });
    if (0 <= current - 2000000 && current - 2000000 < 33333) {
        NSLog(@"transition begin  %lld",current);
        
        GPUImageTransformFilter *filter = self.transformFilters[0];
        GPUImageTransformFilter *filter1 = self.transformFilters[1];
        
        [filter removeTarget:self.gpuPreView];
        
        [filter addTarget:self.transitionFilter];
        [filter1 addTarget:self.transitionFilter];
        
        [self.transitionFilter addTarget:self.gpuPreView];
        EditorFFmpegDecode *secondDecode = [self.decodes lastObject];
        [secondDecode beginDecode];
    }
    
    if (2000000 < current && current <= 3000000) {
        float maintime = (current - 2000000)/(1000000*1.0);
        NSLog(@"transition doing  %lld maintime %f",current,maintime);
        [self.transitionFilter setFloat:maintime forUniformName:@"maintime"];
    }
    
    if (current - 3000000 >= 0 && current - 3000000 < 33333) {
        NSLog(@"transition after  %lld--%@",current,deocde.filePath);
        
        [self.transitionFilter removeTarget:self.gpuPreView];
        GPUImageTransformFilter *filter1 = self.transformFilters[1];
        [filter1 removeTarget:self.transitionFilter];
        [filter1 addTarget:self.gpuPreView];
    }
}
*/

//无转场
/*
- (void)clipCurrentTime:(int64_t)current withDecode:(EditorFFmpegDecode *)deocde {
    CMTime time = CMTimeMake(current, AV_TIME_BASE);
    CGFloat offsetX = [self.timelineView calculateOffsetXAtTime:time];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timelineView scrollToContentOffset:CGPointMake(offsetX, 0) animated:YES completion:^{
            
        }];
    });    
    if (current - 3000000 >= 0 && current - 3000000 < 33333) {
        GPUImageTransformFilter *filter = self.transformFilters[0];
        GPUImageTransformFilter *filter1 = self.transformFilters[1];
        [filter removeTarget:self.gpuPreView];
        [filter1 addTarget:self.gpuPreView];
        EditorFFmpegDecode *secondDecode = [self.decodes lastObject];
        [secondDecode beginDecode];
    }
}
 */

//单视频转场
- (void)clipCurrentTime:(int64_t)current withDecode:(EditorFFmpegDecode *)deocde {
    //转场默认3s 开始转场时间为3000000
    CMTime time = CMTimeMake(current, AV_TIME_BASE);
    CGFloat offsetX = [self.timelineView calculateOffsetXAtTime:time];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timelineView scrollToContentOffset:CGPointMake(offsetX, 0) animated:YES completion:^{
            
        }];
    });
    if (0 <= current - 1000000 && current - 1000000 < 33333) {
        NSLog(@"transition begin  %lld",current);
        
        GPUImageTransformFilter *filter = self.transformFilters[0];
               
        self.pictureInput = [[GPUImagePicture alloc] initWithImage:[UIImage imageNamed:@"clipname_000.png"]];
        
        [filter removeTarget:self.gpuPreView];
        
        [filter addTarget:self.normalBlendFilter];
        [self.pictureInput addTarget:self.normalBlendFilter];
        
        [self.normalBlendFilter addTarget:self.gpuPreView];
        [self.pictureInput processImage];
    }
    
    //000-051
    if (1000000 < current && current <= 3000000) {
        int maintime = (current - 1000000)/(2000000*1.0) * 51;
        NSString *imageName = [NSString stringWithFormat:@"clipname_0%.02d.png",maintime];
        UIImage *transitionImage = [UIImage imageNamed:imageName];
        if (transitionImage) {
            [self.pictureInput replaceTextureWithSubimage:transitionImage];
        }
    }
    
    if (current - 3000000 >= 0 && current - 3000000 < 33333) {
        NSLog(@"transition after  %lld--%@",current,deocde.filePath);
        
        [self.normalBlendFilter removeTarget:self.gpuPreView];
        GPUImageTransformFilter *filter1 = self.transformFilters[1];
        [filter1 addTarget:self.gpuPreView];
        EditorFFmpegDecode *secondDecode = [self.decodes lastObject];
        [secondDecode beginDecode];
    }
}

- (void)setupMainTrack {
    NSURL *url1 = [[NSBundle mainBundle] URLForResource:@"flower" withExtension:@"MP4"];
    AVAsset *asset1 = [AVAsset assetWithURL:url1];
    
    NSURL *url2 = [[NSBundle mainBundle] URLForResource:@"samplevv" withExtension:@"mp4"];
    AVAsset *asset2 = [AVAsset assetWithURL:url2];
    
    CGFloat widthPerSecond = 40;
    CGSize imageSize = CGSizeMake(30, 45);
    
    VITimelineView *timelineView =
    [VITimelineView timelineViewWithAssets:@[asset1, asset2]
                                 imageSize:imageSize
                            widthPerSecond:widthPerSecond];
    timelineView.delegate = self;
    timelineView.rangeViewDelegate = self;
    timelineView.backgroundColor = [UIColor colorWithRed:0.11 green:0.15 blue:0.34 alpha:1.00];
    timelineView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:timelineView];
    [timelineView.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
    [timelineView.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;
    [timelineView.heightAnchor constraintEqualToConstant:400].active = YES;
    [timelineView.topAnchor constraintEqualToAnchor:self.editorControlBar.bottomAnchor constant:20].active = YES;
    
    CIImage *ciimage = [CIImage imageWithColor:[CIColor colorWithRed:0.30 green:0.59 blue:0.70 alpha:1]];
    CGImageRef cgimage = [[CIContext context] createCGImage:ciimage fromRect:CGRectMake(0, 0, 1, 60)];
    UIImage *image = [UIImage imageWithCGImage:cgimage];
    timelineView.centerLineView.image = image;
    [timelineView.rangeViews enumerateObjectsUsingBlock:^(VIRangeView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.clipsToBounds = YES;
        obj.layer.cornerRadius = 4;
        obj.leftEarView.backgroundColor = [UIColor colorWithRed:0.72 green:0.73 blue:0.77 alpha:1.00];
        obj.rightEarView.backgroundColor = [UIColor colorWithRed:0.72 green:0.73 blue:0.77 alpha:1.00];
        obj.backgroundView.backgroundColor = [UIColor colorWithRed:0.72 green:0.73 blue:0.77 alpha:1.00];
        EditorFFmpegDecode *decode = self.decodes[idx];
        if (idx == 1) {
            obj.leftInsetDuration = CMTimeMake(10000000, AV_TIME_BASE);
        }
        obj.startTime = CMTimeMake(decode.trimIn, AV_TIME_BASE);
        obj.endTime = CMTimeMake(decode.trimOut, AV_TIME_BASE);
    }];
    self.timelineView = timelineView;
    
//    UIView *playHead = [UIView new];
//    playHead.backgroundColor = [UIColor whiteColor];
//    [self.view addSubview:playHead];
//    [playHead mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.top.bottom.equalTo(self.timelineView);
//        make.width.mas_equalTo(2);
//        make.centerX.equalTo(self.view);
//    }];
    
//    UIEdgeInsets bottomEdge;
//    if (@available(iOS 11.0, *)) {
//        bottomEdge = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
//    }
//    bottomEdge = UIEdgeInsetsZero;
//    
//    MediaBottomActionView *bottomView = [MediaBottomActionView new];
//    bottomView.delegate = self;
//    [self.view addSubview:bottomView];
//    [bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.right.equalTo(self.view);
//        make.bottom.equalTo(self.view).offset(-bottomEdge.bottom);
//        make.height.mas_equalTo(90);
//    }];
//    [bottomView reloadDataByType:kBottomHomeType];
}

- (void)setupResource {
    self.editorData = [EditorData sharedInstance];
    
    MediaTrack *videoTrack = [[MediaTrack alloc] init];
    videoTrack.type = MediaTrackTypeVideo;
    [self.editorData.tracks addObject:videoTrack];
    
    MediaSegment *effectSegment1 = [[MediaSegment alloc] init];
    effectSegment1.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:0 timeRangeDuration:3000000];
    [videoTrack.segments addObject:effectSegment1];
    
    MediaTrack *mainTrack = self.editorData.tracks[0];
   
//    [self.timelineView initSubviewsWithSegments:mainTrack.segments];
    
//    [self addTrackSegment:nil];
    
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
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSLog(@"scrollView.contentSize.x %f",scrollView.contentSize.width);
    NSLog(@"scrollView.contentOffset.x %f",scrollView.contentOffset.x);
}

- (MediaClip *)videoInfoWithPath:(NSString *)path {
    AVFormatContext *fmt_ctx = NULL;
    const char *url = [[[NSBundle mainBundle] pathForResource:@"samplevv" ofType:@"mp4"] cStringUsingEncoding:NSUTF8StringEncoding];
    MediaClip *clip = [MediaClip new];
    clip.filePath = path;
   // 打开媒体文件
   if (avformat_open_input(&fmt_ctx, url, NULL, NULL) < 0) {
       fprintf(stderr, "Could not open file\n");
   }
   
   // 获取流信息
   if (avformat_find_stream_info(fmt_ctx, NULL) < 0) {
       fprintf(stderr, "Could not find stream info\n");
   }
   
   // 打印文件基础信息
   av_dump_format(fmt_ctx, 0, url, 0);
   
   // 遍历所有流
   for (int i = 0; i < fmt_ctx->nb_streams; i++) {
       AVStream *stream = fmt_ctx->streams[i];
       AVCodecParameters *codec_par = stream->codecpar;
       
       printf("\nStream #%d:\n", i);
       
       // 判断流类型
       if (codec_par->codec_type == AVMEDIA_TYPE_VIDEO) {
           printf("  Type: Video\n");
           printf("  Codec: %s\n", avcodec_get_name(codec_par->codec_id));
           printf("  Resolution: %dx%d\n", codec_par->width, codec_par->height);
           printf("  Pixel Format: %s\n", av_get_pix_fmt_name(codec_par->format));
           printf("  Frame Rate: %f fps\n", round(av_q2d(stream->avg_frame_rate)));
       } else if (codec_par->codec_type == AVMEDIA_TYPE_AUDIO) {
           printf("  Type: Audio\n");
           printf("  Codec: %s\n", avcodec_get_name(codec_par->codec_id));
           printf("  Sample Rate: %d Hz\n", codec_par->sample_rate);
           printf("  Channels: %d\n", codec_par->channels);
           printf("  Channel Layout: %"PRIu64"\n", codec_par->channel_layout);
           printf("  Sample Format: %s\n", av_get_sample_fmt_name(codec_par->format));
       }
       
       // 公共信息
       printf("  Bitrate: %lld bps\n", codec_par->bit_rate);
       printf("  Duration: %.2f seconds\n",
              stream->duration * av_q2d(stream->time_base));
       printf("  Duration: %lld total seconds\n",
              fmt_ctx->duration);
   }
   
   // 获取元数据
   AVDictionaryEntry *tag = NULL;
   printf("\nMetadata:\n");
   while ((tag = av_dict_get(fmt_ctx->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
       printf("  %s: %s\n", tag->key, tag->value);
   }
   
   // 清理资源
   avformat_close_input(&fmt_ctx);
    return clip;
}

//是否跨多轨
- (BOOL)videoSegmentContainOtherSegment:(MediaSegment *)segment {
    return YES;
}

- (void)rangeView:(VIRangeView *)rangeView didChangeActive:(BOOL)isActive {
    NSLog(@"rangeView:%@ didchangeActive: %@", rangeView, @(isActive));
}

- (void)rangeView:(VIRangeView *)rangeView updateLeftOffset:(CGFloat)offset isAuto:(BOOL)isAuto {
    NSLog(@"2.updateLeftOffset rangeView offset: %@ width: %@", @(offset), @(rangeView.contentWidth));
}

- (void)rangeView:(VIRangeView *)rangeView updateRightOffset:(CGFloat)offset isAuto:(BOOL)isAuto {
    NSLog(@"2.updateRightOffset rangeView offset: %@ width: %@", @(offset), @(rangeView.contentWidth));
}

- (void)rangeViewBeginUpdateLeft:(VIRangeView *)rangeView {
    NSLog(@"1.rangeViewBeginUpdateLeft rangeView width: %@", @(rangeView.contentWidth));
}

- (void)rangeViewBeginUpdateRight:(VIRangeView *)rangeView {
    NSLog(@"1.rangeViewBeginUpdateRight rangeView width: %@", @(rangeView.contentWidth));
}

- (void)rangeViewEndUpdateLeftOffset:(VIRangeView *)rangeView {
    NSLog(@"3.rangeViewEndUpdateLeftOffset rangeView width: %@", @(rangeView.contentWidth));
}

- (void)rangeViewEndUpdateRightOffset:(VIRangeView *)rangeView {
    NSLog(@"3.rangeViewEndUpdateRightOffset rangeView width: %@", @(rangeView.contentWidth));
}

- (void)timelineView:(nonnull VITimelineView *)view didChangeActive:(BOOL)isActive {
    NSLog(@"timelineview didchangeActive: %@", @(isActive));
}

- (int)trans {
//#define OUTPUT_TIME_BASE (AVRational){1, 600} // 设置为毫秒精度 (1/1000)
#define OUTPUT_FILENAME [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"] cStringUsingEncoding:NSUTF8StringEncoding]
    
    NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:pathToMovie]) {
        [[NSFileManager defaultManager] removeItemAtPath:pathToMovie error:nil];
    }
    
    
    const char *input_filename = [[[NSBundle mainBundle] pathForResource:@"samplevv" ofType:@"mp4"] cStringUsingEncoding:NSUTF8StringEncoding];

        AVFormatContext *input_ctx = NULL, *output_ctx = NULL;
        int ret = 0;
        int video_stream_index = -1;

        // 1. 打开输入文件
        if ((ret = avformat_open_input(&input_ctx, input_filename, NULL, NULL)) < 0) {
            fprintf(stderr, "Could not open input file '%s': %s\n",
                    input_filename, av_err2str(ret));
        }

        if ((ret = avformat_find_stream_info(input_ctx, NULL)) < 0) {
            fprintf(stderr, "Failed to retrieve input stream information: %s\n",
                    av_err2str(ret));
        }

        // 打印输入文件信息
        av_dump_format(input_ctx, 0, input_filename, 0);

        // 2. 创建输出上下文
        if ((ret = avformat_alloc_output_context2(&output_ctx, NULL, NULL, OUTPUT_FILENAME)) < 0) {
            fprintf(stderr, "Could not create output context: %s\n", av_err2str(ret));
        }

        // 3. 复制流并设置新的 time_base
        for (int i = 0; i < input_ctx->nb_streams; i++) {
            AVStream *in_stream = input_ctx->streams[i];
            AVStream *out_stream = avformat_new_stream(output_ctx, NULL);
            if (!out_stream) {
                fprintf(stderr, "Failed allocating output stream\n");
                ret = AVERROR_UNKNOWN;
            }

            // 复制编解码器参数
            if ((ret = avcodec_parameters_copy(out_stream->codecpar, in_stream->codecpar)) < 0) {
                fprintf(stderr, "Failed to copy codec parameters: %s\n", av_err2str(ret));
            }

            // 设置新的 time_base
            out_stream->time_base = (AVRational){1,600};
            
            // 记录视频和音频流索引
            if (in_stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
                video_stream_index = i;
                // 对于视频流，设置帧率
                out_stream->r_frame_rate = in_stream->r_frame_rate;
                out_stream->avg_frame_rate = in_stream->avg_frame_rate;
            }
        }

        // 4. 打开输出文件
        if (!(output_ctx->oformat->flags & AVFMT_NOFILE)) {
            if ((ret = avio_open(&output_ctx->pb, OUTPUT_FILENAME, AVIO_FLAG_WRITE)) < 0) {
                fprintf(stderr, "Could not open output file '%s': %s\n",
                        OUTPUT_FILENAME, av_err2str(ret));
            }
        }

        // 5. 写入文件头
        if ((ret = avformat_write_header(output_ctx, NULL)) < 0) {
            fprintf(stderr, "Error occurred when writing header: %s\n", av_err2str(ret));
        }

        // 6. 处理数据包
        AVPacket pkt;
        av_init_packet(&pkt);
        pkt.data = NULL;
        pkt.size = 0;
        
        int64_t last_video_pts = AV_NOPTS_VALUE;
        
        // 用于记录每个流的起始PTS
        int64_t start_pts[input_ctx->nb_streams];
        for (int i = 0; i < input_ctx->nb_streams; i++) {
            start_pts[i] = AV_NOPTS_VALUE;
        }

        while (1) {
            if ((ret = av_read_frame(input_ctx, &pkt)) < 0) {
                // 检查是否是文件结束错误
                if (ret == AVERROR_EOF) {
                    fprintf(stderr, "End of input file reached\n");
                    ret = 0; // 正常结束
                } else {
                    fprintf(stderr, "Error reading packet: %s\n", av_err2str(ret));
                }
                break;
            }

            AVStream *in_stream = input_ctx->streams[pkt.stream_index];
            AVStream *out_stream = output_ctx->streams[pkt.stream_index];
            
            // 记录流的起始PTS
            if (start_pts[pkt.stream_index] == AV_NOPTS_VALUE) {
                start_pts[pkt.stream_index] = pkt.pts;
            }
            
            // 7. 时间戳转换 (关键步骤)
            // 计算相对于流开始的PTS
            int64_t rel_pts = pkt.pts - start_pts[pkt.stream_index];
            
            // 转换PTS
            pkt.pts = av_rescale_q(rel_pts, in_stream->time_base, out_stream->time_base);
            
            // 转换DTS
            if (pkt.dts != AV_NOPTS_VALUE) {
                int64_t rel_dts = pkt.dts - start_pts[pkt.stream_index];
                pkt.dts = av_rescale_q(rel_dts, in_stream->time_base, out_stream->time_base);
            } else {
                // 如果DTS不可用，使用PTS
                pkt.dts = pkt.pts;
            }
            
            // 转换duration
            if (pkt.duration > 0) {
                pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
            } else {
                // 估算duration
                if (in_stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
                    pkt.duration = av_rescale_q(1, av_inv_q(in_stream->avg_frame_rate), out_stream->time_base);
                }
            }
            
            // 8. 检查时间戳连续性 (可选但推荐)
            if (in_stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
                if (last_video_pts != AV_NOPTS_VALUE && pkt.pts <= last_video_pts) {
                    fprintf(stderr, "Non-monotonic video PTS detected: %"PRId64" <= %"PRId64"\n",
                            pkt.pts, last_video_pts);
                    // 修复非单调PTS
                    pkt.pts = last_video_pts + 1;
                }
                last_video_pts = pkt.pts;
            }
            
            // 9. 设置输出包参数
            pkt.stream_index = out_stream->index;
            pkt.pos = -1; // 重置位置信息
            
            double frame_time = pkt.pts * av_q2d(out_stream->time_base);
            
            NSLog(@"hhhhh frame pts %lld ----%f-----%d",pkt.pts,frame_time,out_stream->time_base.den);

            
            // 10. 写入数据包
            if ((ret = av_interleaved_write_frame(output_ctx, &pkt)) < 0) {
                fprintf(stderr, "Error writing packet: %s\n", av_err2str(ret));
                av_packet_unref(&pkt);
                break;
            }
            
            av_packet_unref(&pkt);
        }

        // 11. 写入文件尾
        if (ret == 0) {
            if ((ret = av_write_trailer(output_ctx)) < 0) {
                fprintf(stderr, "Error writing trailer: %s\n", av_err2str(ret));
            }
        }

  
        // 12. 清理资源
        if (input_ctx) avformat_close_input(&input_ctx);
        if (output_ctx && !(output_ctx->oformat->flags & AVFMT_NOFILE)) {
            avio_closep(&output_ctx->pb);
        }
        if (output_ctx) avformat_free_context(output_ctx);

        if (ret < 0 && ret != AVERROR_EOF) {
            fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
            return 1;
        }

    printf("Successfully converted file to new time_base: %d/%d\n");
    
    return 1;
           
}

@end
