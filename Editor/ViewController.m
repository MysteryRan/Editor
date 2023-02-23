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
#import "EditorMainTrackReader.h"
#import "EditorMovieWrite.h"

#import "LCPlayer.h"
#import "MutilpleTrackContentView.h"
#import "MediaBottomActionView.h"

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

@property (nonatomic, strong) EditorMainTrackReader *mainTrack;

@property (nonatomic, strong) FFPlayPlayer *ffplayer;

@property (nonatomic, strong) EditorMainTrackReader *setrack;
@property (nonatomic, strong) EditorMovieWrite *movieWrite;

@property (nonatomic, strong) LCPlayer *llplayer;

@property (nonatomic, strong) EditorffmpegReader *pipReader;
@property (nonatomic, strong) MutilpleTrackContentView *trackContentView;

@property (nonatomic, strong) GPUImageMovieWriter *originMoviewrite;

@end

@implementation ViewController

- (NSString *)createvideo_file_url:(NSString *)file {
    NSString * videoPath =  [file stringByAppendingString:@".mp4"];
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

- (int)muxTest {
    NSString *outpath = [self createvideo_file_url:@"james"];
    AVFormatContext *in_vedio_ctx = NULL, *in_audio_ctx = NULL, *out_ctx = NULL;
//    vector<int> stream_indexs;
    NSMutableArray *stream_indexs = [NSMutableArray arrayWithCapacity:0];
    bool isVedio = true;

    //h264 info
    avformat_open_input(&in_vedio_ctx, [[[NSBundle mainBundle] pathForResource:@"clearencode" ofType:@"h264"] UTF8String], NULL, NULL);
    avformat_find_stream_info(in_vedio_ctx, NULL);

    //mp3 info
    avformat_open_input(&in_audio_ctx, [[[NSBundle mainBundle] pathForResource:@"Kobe" ofType:@"aac"] UTF8String], NULL, NULL);
    avformat_find_stream_info(in_audio_ctx, NULL);

    //mp4 init
    avformat_alloc_output_context2(&out_ctx, NULL, NULL, [outpath UTF8String]);

    //get stream
    int vedio_stream_index = -1, audio_stream_index = -1;
    av_find_best_stream(in_vedio_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    av_find_best_stream(in_audio_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);

    [stream_indexs addObject:[NSNumber numberWithInt:vedio_stream_index]];
//    stream_indexs.push_back(audio_stream_index);
    [stream_indexs addObject:[NSNumber numberWithInt:audio_stream_index]];

    //Œ™ ‰≥ˆ…œœ¬Œƒ¥¥Ω®¡˜
    
    for (int index = 0; index < stream_indexs.count; index ++) {
        AVStream *out_stream = avformat_new_stream(out_ctx, NULL);
//        ptr_check(out_stream);
        avcodec_parameters_from_context(out_stream->codecpar,
            isVedio ? in_vedio_ctx->streams[0]->codec : in_audio_ctx->streams[0]->codec);

        isVedio = false;
        if (out_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
        }
    }

    //¥Úø™ ‰≥ˆŒƒº˛
    if (!(out_ctx->oformat->flags & AVFMT_NOFILE)) {
        avio_open(&out_ctx->pb, [outpath UTF8String], AVIO_FLAG_READ_WRITE);
    }

    //–¥»ÎŒƒº˛Õ∑
    avformat_write_header(out_ctx, NULL);

    //ø™ º–¥Œƒº˛
    AVPacket *packet = av_packet_alloc();
    int64_t ts_a = 0, ts_b = 0;
    int64_t *ts_p = NULL;
    int out_stream_index = -1;
    AVFormatContext *cur_ctx = NULL;
    AVStream *cur_stream = NULL;
    int frame = 0;

    while (1) {

        //÷∏∂®µ±«∞∂¡»° ”∆µªπ «“Ù ”
        if (av_compare_ts(ts_a, in_vedio_ctx->streams[vedio_stream_index]->time_base, ts_b, in_audio_ctx->streams[audio_stream_index]->time_base) <= 0) {
            cur_ctx = in_vedio_ctx;
            ts_p = &ts_a;
            cur_stream = in_vedio_ctx->streams[vedio_stream_index];
            out_stream_index = 0;
        } else {
            cur_ctx = in_audio_ctx;
            ts_p = &ts_b;
            cur_stream = in_audio_ctx->streams[audio_stream_index];
            out_stream_index = 1;
        }

        if (av_read_frame(cur_ctx, packet) < 0) {
            break;
        }

        //º∆À„pts dts, ’‚¿Ô÷ª «º∆À„≥ˆµ±«∞µƒøÃ∂»,∫Û√Ê–Ë“™‘Ÿº∆À„≥…æﬂÃÂµƒ ±º‰
        if (packet->pts == AV_NOPTS_VALUE) {

            //º∆À„≥ˆ ‰»Î(‘≠ º) ”∆µ“ª÷°∂‡≥§ ±º‰,Ω·π˚µ•ŒªŒ™Œ¢√Ó
            int64_t each_frame_time = (double)AV_TIME_BASE / av_q2d(cur_stream->r_frame_rate);

            //“‘‘≠ º“ª÷°µƒ≥÷–¯ ±º‰≥˝“‘ ±º‰ª˘,‘Ú ±º‰øÃ∂»æÕ”–¡À,”…”⁄ ±º‰ª˘µƒµ•ŒªŒ™√Î.∂¯≥÷–¯ ±º‰(each_frame_time)Œ™Œ¢√Ó,π ªπ–Ë“™≥˝“‘AV_TIME_BASE
            packet->pts = (double)(frame++ * each_frame_time) / (double)(av_q2d(cur_stream->time_base) * AV_TIME_BASE);
            packet->dts = packet->pts;

            //“ª÷°µƒ ±º‰Œ™each_frame_timeŒ¢√Ó,≥˝“‘AV_TIME_BASEæÕ «√Î,‘Ÿ≥˝“‘ ±º‰ª˘,‘Ú ±º‰øÃ∂»æÕ≥ˆ¿¥¡À.
            packet->duration = (double)each_frame_time / (double)(av_q2d(cur_stream->time_base) * AV_TIME_BASE);
        }

        *ts_p = packet->pts;

        //º∆À„pts∂‘”¶µƒæﬂÃÂµƒ ±º‰
        av_packet_rescale_ts(packet, cur_stream->time_base, out_ctx->streams[out_stream_index]->time_base);
        packet->stream_index = out_stream_index;
        printf("write file pts = %lld, index = %d\n", packet->pts, packet->stream_index);

        //–¥»ÎŒƒº˛
        av_interleaved_write_frame(out_ctx, packet);

        av_packet_unref(packet);
    }


    //–¥Œƒº˛Œ≤
    av_write_trailer(out_ctx);

    if (!(out_ctx->oformat->flags & AVFMT_NOFILE)) {
        avio_close(out_ctx->pb);
    }
    avformat_close_input(&in_audio_ctx);
    avformat_close_input(&in_vedio_ctx);
    avformat_free_context(out_ctx);
    av_packet_free(&packet);
    return 0;
    
}



- (void)trackPicInPic {
    self.mainTrack = [[EditorMainTrackReader alloc] init];
    
    
    self.currentTrans = [[GPUImageNormalBlendFilter alloc] init];

    [self.mainTrack addTarget:self.currentTrans];

    self.setrack = [[EditorMainTrackReader alloc] init];



    GPUImageTransformFilter *re = [[GPUImageTransformFilter alloc] init];
    re.affineTransform = CGAffineTransformMakeScale(0.5, 0.5);

//    [self.setrack addTarget:re];
//    [re addTarget:self.currentTrans];
    
    [self.setrack addTarget:self.currentTrans];
    
    [self.mainTrack recieveGPUImageView:self.currentTrans];
    [self.setrack recieveGPUImageView:self.currentTrans];

    [self.currentTrans addTarget:self.gpuPreView];

    [self.setrack begin];
    [self.mainTrack begin];
}



- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
//    self.audioPlayer = [[EditorAudioPlayer alloc] init];
//    [self.audioPlayer play];
    
//    [FFMpegTool copytest];
//    [FFMpegTool replaceAudio];
    
//    FFMpegTool *rrtool = [[FFMpegTool alloc] init];
//    [rrtool add_bgm_to_video:[@"" UTF8String]  with:[@"" UTF8String] with:[@"" UTF8String] with:8];
    
//    [FFMpegTool MergeTwo:@"" with:@"" with:@""];
    
    
//    return;
    
//    [self muxTest];
    
    
//    return;
//    [self setupResource];
//    
//    MutilpleTrackContentView *contentView = [[MutilpleTrackContentView alloc] init];
//    [self.view addSubview:contentView];
//    contentView.backgroundColor = [UIColor redColor];
//    [contentView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.right.equalTo(self.view);
//        make.top.equalTo(self.view).offset(100);
//        make.height.mas_equalTo(200);
//    }];
    
    
    
//    return;
//    self.ffplayer = [[FFPlayPlayer alloc] init];
//    [self.ffplayer begin];
//
    [self setupPreView];
    [self setupPlaycontrol];
    [self setupMainTrack];
//
//
//
    [self setupResource];
    [self setupTimer];
    [self setupBottom];
    
//    [self.timelineView reloadDa];
//    [self sticker];
    
    
//    [self mutilAudio];
    
//    FFPlayPlayer *pp = [[FFPlayPlayer alloc] init];
//    [pp begin];
    
//    [self trackPicInPic];
    
//    [self lctest];
}

- (void)setupBottom {
    
}

- (void)lctest {
//    self.llplayer = [[LCPlayer alloc] init];
//    [self.llplayer maintest];
//    [self.llplayer getRefresh];
}

- (void)mutilAudio {
    self.audioPlayer = [[EditorAudioPlayer alloc] init];
    [self.audioPlayer play];
}

- (void)setupTimer {
    return;
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
//        dispatch_async(dispatch_get_main_queue(), ^{
            if (time == 0) {
                
//                self.movieWrite = [[EditorMovieWrite alloc] initWithMovieURL:[NSURL URLWithString:@"11"] size:CGSizeMake(1920, 1080)];
//                NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/originMovie4.mp4"];
//                NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
//                self.originMoviewrite = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(1920, 1080)];
                
                self.ffmpegReader = [[EditorffmpegReader alloc] init];
                self.currentFilter = [self.ffmpegReader startWith:self.firstSegment];
                [self.currentFilter addTarget:self.gpuPreView];
//                [self.currentFilter addTarget:self.originMoviewrite];
//                [self.originMoviewrite startRecording];
                
//                [self.currentFilter addTarget:self.movieWrite];
//                [self.movieWrite startRecording];
            }
            uint64_t current_time = round(time);
        
//        [self pipControlWithTime:time];
            [self trackControlWithTime:current_time];
//            [self StickerControlWithTime:current_time];
            time = time + duration;
        
        if (time > self.secondSegment.target_timerange.start + self.secondSegment.target_timerange.duration) {
            
            dispatch_suspend(self->video_render_timer);
        }
//        });

    });
    dispatch_resume(self->video_render_timer);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    [self.ffmpegReader seek];
    
//    dispatch_resume(self->video_render_timer);
    
//    dispatch_suspend(self->video_render_timer);
//    [self.ffmpegReader stop];
    
}

- (void)StickerControlWithTime:(uint64_t)time {
    double fps = 30.0;
    uint64_t av_time_base = 1000000;
    float perFrame = 1.0 / fps * av_time_base;
    
    uint64_t distance = time - (1000000);
    
    // 刚转场
    if (distance <= perFrame && distance > 0) {
//        [self.ffmpegReader removeAllTargets];
//        [self sticker];
    }
}

- (void)sticker {
//    1000000    3000000
    
    
//    NSMutableArray *_ss = [NSMutableArray arrayWithCapacity:0];
//    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ani_info" withExtension:@"json"]];
//    NSDictionary *dataDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
//    NSLog(@"%@",dataDic);
//    NSArray *arr = dataDic[@"frames"];
//    for (int i = 0; i < arr.count; i ++) {
//        NSDictionary *di = arr[i];
//        EditorSticker *model = [[EditorSticker alloc] initWithDictionaty:di];
//        [_ss addObject:model];
//    }
//    CIImage *allImage = [[CIImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"SequenceMap" withExtension:@"png"]];
//    CIImage *stickerImage2;
//    EditorSticker *sticker;
//    for (int i = 0; i < arr.count; i ++) {
//        sticker = _ss[15];
//    }
//    if (sticker) {
//        //                    h":146,"w":280,"x":840,"y":146
//        //                    h":146,"w":280,"x":0,"y":146
//        stickerImage2 = [allImage imageByCroppingToRect:CGRectMake(sticker.frame.origin.x, 1168 - sticker.frame.origin.y - sticker.frame.size.height, sticker.frame.size.width, sticker.frame.size.height)];
////        CGAffineTransform affineTransform = CGAffineTransformMakeTranslation(-sticker.frame.origin.x,-(1168 - sticker.frame.origin.y - sticker.frame.size.height));
////        stickerImage2 = [stickerImage2 imageByApplyingTransform:affineTransform];
////        UIImage *eee = [UIImage imageWithCIImage:stickerImage2];
//        UIImage *eee = [UIImage imageNamed:@"640k.jpg"];
        
        
    self.picsss = [[GPUImagePicture alloc] initWithImage:[self tailoringImage:[UIImage imageNamed:@"SequenceMap.png"] Area:CGRectMake(840, 1168 - 146 - 146, 280, 146)]];
    
    
    self.picTrans = [[GPUImageTransformFilter alloc] init];
    self.picTrans.affineTransform = CGAffineTransformMakeScale(0.3, 0.3);
    GPUImageAlphaBlendFilter *gpu = [[GPUImageAlphaBlendFilter alloc] init];
//
//
    [self.picsss addTarget:self.picTrans];
    [self.picsss processImage];
////    [trans setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
////        [output useNextFrameForImageCapture];
////    }];
////
////    [gpu setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
////        [output useNextFrameForImageCapture];
////    }];
    [self.currentFilter addTarget:gpu];
    [self.picTrans addTarget:gpu];
    
    
    [gpu addTarget:self.gpuPreView];
    
    
    
    
    
    
//    }
}

-(UIImage*)tailoringImage:(UIImage*)img Area:(CGRect)area{
    CGImageRef sourceImageRef = [img CGImage];//将UIImage转换成CGImageRef
    CGRect rect = CGRectMake(area.origin.x, area.origin.y, area.size.width, area.size.height);
    CGImageRef newImageRef = CGImageCreateWithImageInRect(sourceImageRef, rect);//按照给定的矩形区域进行剪裁
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    return newImage;
}

- (void)pipControlWithTime:(uint64_t)time {
    double fps = 30.0;
    uint64_t av_time_base = 1000000;
    float perFrame = 1.0 / fps * av_time_base;
    
    
    uint64_t distance22 = time - (1000000);
    
    // 刚转场
//    NSLog(@"distance %lld",distance22);
    if (distance22 <= 2 * perFrame && distance22 >= perFrame) {
        // 无转场
        /*
        [self.currentFilter removeAllTargets];
        
        self.pipReader = [[EditorffmpegReader alloc] init];
        
        GPUImageNormalBlendFilter *normal = [[GPUImageNormalBlendFilter alloc] init];
        
        self.pipFilter = [self.pipReader startWith:self.firstSegment];
        
        GPUImageTransformFilter *tra = [[GPUImageTransformFilter alloc] init];
        tra.affineTransform = CGAffineTransformMakeScale(0.5, 0.5);
        
        [self.pipFilter addTarget:tra];
        
        [self.currentFilter addTarget:normal];
        [tra addTarget:normal];
        
        [normal addTarget:self.gpuPreView];
         */
        
    }
    
    
    
    
}

- (void)trackControlWithTime:(uint64_t)time {
//    NSLog(@"timer pts %lld",time);
    double fps = 30.0;
    uint64_t av_time_base = 1000000;
    float perFrame = 1.0 / fps * av_time_base;
    
    // 每秒长度 / 总长度 = 每秒时间 / 总时间
    dispatch_async(dispatch_get_main_queue(), ^{
        double aa = av_time_base / fps / (self.secondSegment.target_timerange.start + self.secondSegment.target_timerange.duration) * (self.timelineView.contentSize.width - self.view.frame.size.width);
        self.contentOffset = self.contentOffset + aa;
//        [self.timelineView setContentOffset:CGPointMake(self.contentOffset, 0)];
    });
    
//    return;
    
    uint64_t distance22 = time - (5000000);
    
    // 刚转场
//    NSLog(@"distance %lld",distance22);
    if (distance22 <= 2 * perFrame && distance22 >= perFrame) {
        [self.ffmpegReader addselectedFilter];
    }
    
    uint64_t distance33 = time - (8000000);
    
    // 刚转场
//    NSLog(@"distance %lld",distance22);
    if (distance33 <= 2 * perFrame && distance33 >= perFrame) {
        [self.ffmpegReader deleteSelectedFilter];
    }
    
    NSUInteger index = [self.editorData.tracks[0].segments indexOfObject:self.firstSegment];
    NSMutableArray *transtions = self.editorData.materials.transitions;
    int64_t tran_duration = 0;
    EditorTransition *transi;
    if (index >= 0 && index < transtions.count) {
        transi = self.editorData.materials.transitions[index];
        tran_duration = transi.duration;
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
//            [self.transitionFilter addTarget:self.movieWrite];
        } else {
            [self.nextFilter addTarget:self.gpuPreView];
//            [self.nextFilter addTarget:self.movieWrite];
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
//            [self.nextFilter addTarget:self.movieWrite];
        }
    }
}

- (void)setupPreView {
    self.preBackgroundView = [UIView new];
//    self.preBackgroundView.backgroundColor = [UIColor colorWithRed:245/255.0 green:0/255.0 blue:0/255.0 alpha:1];
    [self.view addSubview:self.preBackgroundView];
    CGFloat topOffset = [UIApplication sharedApplication].windows.firstObject.safeAreaInsets.top;
    [self.preBackgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(topOffset);
        make.left.right.equalTo(self.view);
        make.height.equalTo(self.preBackgroundView.mas_width);
    }];
    
    self.gpuPreView = [[GPUImageView alloc] init];
//    [self.gpuPreView setBackgroundColorRed:1 green:0 blue:0 alpha:1];
    self.gpuPreView.fillMode = kGPUImageFillModeStretch;
    [self.preBackgroundView addSubview:self.gpuPreView];
    [self.gpuPreView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.bottom.right.lessThanOrEqualTo(self.preBackgroundView).priorityLow();
        make.center.equalTo(self.preBackgroundView);
        make.height.lessThanOrEqualTo(self.preBackgroundView);
        make.width.equalTo(self.gpuPreView.mas_height).multipliedBy(1920.0/1080.0);
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
    
    UILabel *currentTimeLab = [UILabel new];
    [self.editorControlBar addSubview:currentTimeLab];
    currentTimeLab.text = @"123";
    [currentTimeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.editorControlBar).offset(12);
        make.centerY.equalTo(self.editorControlBar);
    }];
    
    UILabel *totalTimeLab = [UILabel new];
    [self.editorControlBar addSubview:totalTimeLab];
    totalTimeLab.text = @"456";
    [totalTimeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(currentTimeLab.mas_right);
        make.centerY.equalTo(self.editorControlBar);
    }];
    
    UIButton *playButton = [UIButton new];
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
                    
                    [track.segments addObject:segment];
                    
                    return;
                }
            }
        } else {
            createNewTrack = YES;
        }
    }
    
    
    if (createNewTrack) {
        MediaTrack *track = [[MediaTrack alloc] init];
        track.type = type;
        [self.editorData.tracks addObject:track];
        [track.segments addObject:segment];
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
