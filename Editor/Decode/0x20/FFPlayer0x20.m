//
//  FFPlayer0x20.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/7/10.
//

#import "FFPlayer0x20.h"
#import "MRThread.h"
#import "FFPlayerInternalHeader.h"
#import "FFPlayerPacketHeader.h"
#import "FFPlayerFrameHeader.h"
#import "FFDecoder0x20.h"
#import "FFVideoScale.h"
#import "FFAudioResample0x20.h"
#import "MRConvertUtil.h"
#import <CoreVideo/CVPixelBufferPool.h>
#include "avutil.h"

//是否使用POOL
#define USE_PIXEL_BUFFER_POOL 1

@interface FFPlayer0x20 ()<FFDecoderDelegate0x20>
{
    //解码前的音频包缓存队列
    PacketQueue _audioq;
    
    //解码前的音频包缓存队列
    PacketQueue _erluaudioq;
    
    //解码前的视频包缓存队列
    PacketQueue _videoq;
    
    //解码后的音频帧缓存队列
    FrameQueue _sampq;
    
    //解码后的音频帧缓存队列
    FrameQueue _erlusampq;
    //解码后的视频帧缓存队列
    FrameQueue _pictq;
    
    FrameQueue _finalSampq;
    
    //读包完毕？
    int _eof;
    
    
    //输出槽
        AVFilterContext *buffersink_ctx ;
        //输入缓存1
        AVFilterContext *buffersrc1_ctx ;
        //输入缓存2
        AVFilterContext *buffersrc2_ctx ;
        //滤镜图
        AVFilterGraph *filter_graph;
    
    AVFrame *finalFrame;
}

//读包线程
@property (nonatomic, strong) MRThread *readThread;
//渲染线程
@property (nonatomic, strong) MRThread *rendererThread;

//音频解码器
@property (nonatomic, strong) FFDecoder0x20 *audioDecoder;
//二路音频解码器
@property (nonatomic, strong) FFDecoder0x20 *erluaudioDecoder;
//视频解码器
@property (nonatomic, strong) FFDecoder0x20 *videoDecoder;
//图像格式转换/缩放器
@property (nonatomic, strong) FFVideoScale *videoScale;
//音频格式转换器
@property (nonatomic, strong) FFAudioResample0x20 *audioResample;

//PixelBuffer池可提升效率
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (atomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferFullBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferEmptyBlock;
@property (atomic, assign) BOOL packetBufferIsFull;
@property (atomic, assign) BOOL packetBufferIsEmpty;
@property (atomic, assign, readwrite) int videoFrameCount;
@property (atomic, assign, readwrite) int audioFrameCount;

@end

@implementation  FFPlayer0x20

static int decode_interrupt_cb(void *ctx)
{
    FFPlayer0x20 *player = (__bridge FFPlayer0x20 *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    //避免重复stop做无用功
    if (self.readThread) {
        self.abort_request = 1;
        _audioq.abort_request = 1;
        _videoq.abort_request = 1;
        _sampq.abort_request = 1;
        _pictq.abort_request = 1;
        
        [self.readThread cancel];
        [self.audioDecoder cancel];
        [self.videoDecoder cancel];
        [self.rendererThread cancel];
        
        [self.readThread join];
        [self.audioDecoder join];
        [self.videoDecoder join];
        [self.rendererThread join];
    }
    [self performSelectorOnMainThread:@selector(didStop:) withObject:self waitUntilDone:YES];
}

- (void)didStop:(id)sender
{
    self.readThread = nil;
    self.audioDecoder = nil;
    self.videoDecoder = nil;
    self.rendererThread = nil;
    
    if (self.pixelBufferPool){
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
    
    packet_queue_destroy(&_audioq);
    packet_queue_destroy(&_videoq);
    packet_queue_destroy(&_erluaudioq);
    
    frame_queue_destory(&_pictq);
    frame_queue_destory(&_sampq);
    frame_queue_destory(&_erlusampq);
    
    
}

- (void)dealloc
{
    PRINT_DEALLOC;
}

//准备
- (void)prepareToPlay
{
    if (self.readThread) {
        NSAssert(NO, @"不允许重复创建");
    }
    
    //初始化视频包队列
    packet_queue_init(&_videoq);
    //初始化音频包队列
    packet_queue_init(&_audioq);
    
    packet_queue_init(&_erluaudioq);
        
    //初始化ffmpeg相关函数
    init_ffmpeg_once();
    
    //初始化视频帧队列
    frame_queue_init(&_pictq, VIDEO_PICTURE_QUEUE_SIZE, "pictq", 0);
    //初始化音频帧队列
    frame_queue_init(&_sampq, SAMPLE_QUEUE_SIZE, "sampq", 0);
    
    frame_queue_init(&_erlusampq, SAMPLE_QUEUE_SIZE, "erlusampq", 0);
    
    frame_queue_init(&_finalSampq, SAMPLE_QUEUE_SIZE, "finalSampq", 0);
    
    self.readThread = [[MRThread alloc] initWithTarget:self selector:@selector(readPacketsFunc) object:nil];
    self.readThread.name = @"mr-read";
}

#pragma mark - 打开解码器创建解码线程

- (FFDecoder0x20 *)openStreamComponent:(AVFormatContext *)ic streamIdx:(int)idx
{
    FFDecoder0x20 *decoder = [FFDecoder0x20 new];
    decoder.ic = ic;
    decoder.streamIdx = idx;
    if ([decoder open] == 0) {
        return decoder;
    } else {
        return nil;
    }
}

#pragma -mark 读包线程

- (void)readerluPacketLoop:(AVFormatContext *)formatCtx
{
    if (formatCtx == nil) {
        return;
    }
    AVPacket pkt1, *pkt = &pkt1;
    //循环读包
    for (;;) {
        //调用了stop方法，则不再读包
        if (self.abort_request) {
            break;
        }

        /* 队列不满继续读，满了则休眠10 ms */
        if (_erluaudioq.size + _videoq.size > MAX_QUEUE_SIZE
            || (stream_has_enough_packets(self.erluaudioDecoder.stream, self.erluaudioDecoder.streamIdx, &_audioq) &&
                stream_has_enough_packets(self.videoDecoder.stream, self.videoDecoder.streamIdx, &_videoq))) {

            if (!self.packetBufferIsFull) {
                self.packetBufferIsFull = YES;
                if (self.onPacketBufferFullBlock) {
                    self.onPacketBufferFullBlock();
                }
            }
            /* wait 10 ms */
            mr_msleep(10);
            continue;
        }

        self.packetBufferIsFull = NO;
        //读包
        int ret = av_read_frame(formatCtx, pkt);
        //读包出错
        if (ret < 0) {
            //读到最后结束了
            if ((ret == AVERROR_EOF || avio_feof(formatCtx->pb)) && !_eof) {
                //最后放一个空包进去
                if (self.erluaudioDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&_erluaudioq, self.erluaudioDecoder.streamIdx);
                }

                if (self.videoDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&_videoq, self.videoDecoder.streamIdx);
                }
                //标志为读包结束
                _eof = 1;
            }

            if (formatCtx->pb && formatCtx->pb->error) {
                break;
            }
            /* wait 10 ms */
            mr_msleep(10);
            continue;
        } else {
            //音频包入音频队列
            if (pkt->stream_index == self.erluaudioDecoder.streamIdx) {
                packet_queue_put(&_erluaudioq, pkt);
            }
            //视频包入视频队列
            else if (pkt->stream_index == self.videoDecoder.streamIdx) {
                packet_queue_put(&_videoq, pkt);
            }
            //其他包释放内存忽略掉
            else {
                av_packet_unref(pkt);
            }
        }
    }
}

//读包循环
- (void)readPacketLoop:(AVFormatContext *)formatCtx
{
    if (formatCtx == nil) {
        return;
    }
    AVPacket pkt1, *pkt = &pkt1;
    //循环读包
    for (;;) {
        //调用了stop方法，则不再读包
        if (self.abort_request) {
            break;
        }

        /* 队列不满继续读，满了则休眠10 ms */
        if (_audioq.size + _videoq.size > MAX_QUEUE_SIZE
            || (stream_has_enough_packets(self.audioDecoder.stream, self.audioDecoder.streamIdx, &_audioq) &&
                stream_has_enough_packets(self.videoDecoder.stream, self.videoDecoder.streamIdx, &_videoq))) {

            if (!self.packetBufferIsFull) {
                self.packetBufferIsFull = YES;
                if (self.onPacketBufferFullBlock) {
                    self.onPacketBufferFullBlock();
                }
            }
            /* wait 10 ms */
            mr_msleep(10);
            continue;
        }

        self.packetBufferIsFull = NO;
        //读包
        int ret = av_read_frame(formatCtx, pkt);
        //读包出错
        if (ret < 0) {
            //读到最后结束了
            if ((ret == AVERROR_EOF || avio_feof(formatCtx->pb)) && !_eof) {
                //最后放一个空包进去
                if (self.audioDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&_audioq, self.audioDecoder.streamIdx);
                }

                if (self.videoDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&_videoq, self.videoDecoder.streamIdx);
                }
                //标志为读包结束
                _eof = 1;
            }

            if (formatCtx->pb && formatCtx->pb->error) {
                break;
            }
            /* wait 10 ms */
            mr_msleep(10);
            continue;
        } else {
            //音频包入音频队列
            if (pkt->stream_index == self.audioDecoder.streamIdx) {
                packet_queue_put(&_audioq, pkt);
            }
            //视频包入视频队列
            else if (pkt->stream_index == self.videoDecoder.streamIdx) {
                packet_queue_put(&_videoq, pkt);
            }
            //其他包释放内存忽略掉
            else {
                av_packet_unref(pkt);
            }
        }
    }
}

#pragma mark - 查找最优的音视频流
- (void)findBestStreams:(AVFormatContext *)formatCtx result:(int (*) [AVMEDIA_TYPE_NB])st_index {

    int first_video_stream = -1;
    int first_h264_stream = -1;
    //查找H264格式的视频流
    for (int i = 0; i < formatCtx->nb_streams; i++) {
        AVStream *st = formatCtx->streams[i];
        enum FFMAVMediaType type = st->codecpar->codec_type;
        st->discard = AVDISCARD_ALL;

        if (type == AVMEDIA_TYPE_VIDEO) {
            enum AVCodecID codec_id = st->codecpar->codec_id;
            if (codec_id == AV_CODEC_ID_H264) {
                if (first_h264_stream < 0) {
                    first_h264_stream = i;
                    break;
                }
                if (first_video_stream < 0) {
                    first_video_stream = i;
                }
            }
        }
    }
    //h264优先
    (*st_index)[AVMEDIA_TYPE_VIDEO] = first_h264_stream != -1 ? first_h264_stream : first_video_stream;
    //根据上一步确定的视频流查找最优的视频流
    (*st_index)[AVMEDIA_TYPE_VIDEO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, (*st_index)[AVMEDIA_TYPE_VIDEO], -1, NULL, 0);
    //参照视频流查找最优的音频流
    (*st_index)[AVMEDIA_TYPE_AUDIO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, (*st_index)[AVMEDIA_TYPE_AUDIO], (*st_index)[AVMEDIA_TYPE_VIDEO], NULL, 0);
}

#pragma mark - 视频像素格式转换

- (FFVideoScale *)createVideoScaleIfNeed
{
    //未指定期望像素格式
    if (self.supportedPixelFormats == MR_PIX_FMT_MASK_NONE) {
        NSAssert(NO, @"supportedPixelFormats can't be none!");
        return nil;
    }
    
    //当前视频的像素格式
    const enum AVPixelFormat format = self.videoDecoder.format;
    
    bool matched = false;
    MRPixelFormat firstSupportedFmt = MR_PIX_FMT_NONE;
    for (int i = MR_PIX_FMT_BEGIN; i <= MR_PIX_FMT_END; i ++) {
        const MRPixelFormat fmt = i;
        const MRPixelFormatMask mask = 1 << fmt;
        if (self.supportedPixelFormats & mask) {
            if (firstSupportedFmt == MR_PIX_FMT_NONE) {
                firstSupportedFmt = fmt;
            }
            
            if (format == MRPixelFormat2AV(fmt)) {
                matched = true;
                break;
            }
        }
    }
    
    if (matched) {
        //期望像素格式包含了当前视频像素格式，则直接使用当前格式，不再转换。
        av_log(NULL, AV_LOG_INFO, "video not need rescale!\n");
        return nil;
    }
    
    if (firstSupportedFmt == MR_PIX_FMT_NONE) {
        NSAssert(NO, @"supportedPixelFormats is invalid!");
        return nil;
    }
    
    int dest = MRPixelFormat2AV(firstSupportedFmt);
    if ([FFVideoScale checkCanConvertFrom:format to:dest]) {
        //创建像素格式转换上下文
        FFVideoScale *scale = [[FFVideoScale alloc] initWithSrcPixFmt:format dstPixFmt:dest picWidth:self.videoDecoder.picWidth picHeight:self.videoDecoder.picHeight];
        return scale;
    } else {
        //TODO ??
        return nil;
    }
}

- (FFAudioResample0x20 *)createAudioResampleIfNeed
{
    //未指定期望音频格式
    if (self.supportedSampleFormats == MR_SAMPLE_FMT_MASK_NONE) {
        NSAssert(NO, @"supportedSampleFormats can't be none!");
        return nil;
    }
    
    //未指定支持的比特率就使用目标音频的
    if (self.supportedSampleRate == 0) {
        self.supportedSampleRate = self.audioDecoder.sampleRate;
    }
    
    //当前视频的像素格式
    const enum AVSampleFormat format = self.audioDecoder.format;
    
    bool matched = false;
    MRSampleFormat firstSupportedFmt = MR_SAMPLE_FMT_NONE;
    for (int i = MR_SAMPLE_FMT_BEGIN; i <= MR_SAMPLE_FMT_END; i ++) {
        const MRSampleFormat fmt = i;
        const MRSampleFormatMask mask = 1 << fmt;
        if (self.supportedSampleFormats & mask) {
            if (firstSupportedFmt == MR_SAMPLE_FMT_NONE) {
                firstSupportedFmt = fmt;
            }
            
            if (format == MRSampleFormat2AV(fmt)) {
                matched = true;
                break;
            }
        }
    }
    
    if (matched) {
        //采样率不匹配
        if (self.supportedSampleRate != self.audioDecoder.sampleRate) {
            firstSupportedFmt = AVSampleFormat2MR(format);
            matched = NO;
        }
    }
    
    if (matched) {
        //期望音频格式包含了当前音频格式，则直接使用当前格式，不再转换。
        av_log(NULL, AV_LOG_INFO, "audio not need resample!\n");
        return nil;
    }
    
    if (firstSupportedFmt == MR_SAMPLE_FMT_NONE) {
        NSAssert(NO, @"supportedSampleFormats is invalid!");
        return nil;
    }
    
    //创建音频格式转换上下文
    FFAudioResample0x20 *resample = [[FFAudioResample0x20 alloc] initWithSrcSampleFmt:format
                                                                         dstSampleFmt:MRSampleFormat2AV(firstSupportedFmt)
                                                                           srcChannel:self.audioDecoder.channelLayout
                                                                           dstChannel:self.audioDecoder.channelLayout
                                                                              srcRate:self.audioDecoder.sampleRate
                                                                              dstRate:self.supportedSampleRate];
    return resample;
}

- (void)readPacketsFunc
{
    if (![self.contentPath hasPrefix:@"/"]) {
        _init_net_work_once();
    }
    
//    [self beforeConfig];
    [self otherConfig];
    
    AVFormatContext *formatCtx = avformat_alloc_context();
    
    AVFormatContext *erluFormatCtx = avformat_alloc_context();
    
    if (!formatCtx) {
        self.error = _make_nserror_desc(FFPlayerErrorCode_AllocFmtCtxFailed, @"创建 AVFormatContext 失败！");
        [self performErrorResultOnMainThread];
        return;
    }
    
    if (!erluFormatCtx) {
        self.error = _make_nserror_desc(FFPlayerErrorCode_AllocFmtCtxFailed, @"创建 AVFormatContext 失败！");
        [self performErrorResultOnMainThread];
        return;
    }
    
    formatCtx->interrupt_callback.callback = decode_interrupt_cb;
    formatCtx->interrupt_callback.opaque = (__bridge void *)self;
    
    erluFormatCtx->interrupt_callback.callback = decode_interrupt_cb;
    erluFormatCtx->interrupt_callback.opaque = (__bridge void *)self;
    
    /*
     打开输入流，读取文件头信息，不会打开解码器；
     */
    //低版本是 av_open_input_file 方法
    const char *moviePath = [[[NSBundle mainBundle] pathForResource:@"longtest" ofType:@"mp3"] UTF8String];
    
    const char *erlumoviePath = [[[NSBundle mainBundle] pathForResource:@"erlutest" ofType:@"mp3"] UTF8String];
    //打开文件流，读取头信息；
    if (0 != avformat_open_input(&formatCtx, moviePath , NULL, NULL)) {
        //释放内存
//        avformat_free_context(formatCtx);
        //当取消掉时，不给上层回调
        if (self.abort_request) {
            return;
        }
//        self.error = _make_nserror_desc(FFPlayerErrorCode_OpenFileFailed, @"文件打开失败！");
//        [self performErrorResultOnMainThread];
        return;
    }
    
    if (0 != avformat_open_input(&erluFormatCtx, erlumoviePath , NULL, NULL)) {
        //释放内存
//        avformat_free_context(formatCtx);
        //当取消掉时，不给上层回调
        if (self.abort_request) {
            return;
        }
//        self.error = _make_nserror_desc(FFPlayerErrorCode_OpenFileFailed, @"文件打开失败！");
//        [self performErrorResultOnMainThread];
        return;
    }
    
    /* 刚才只是打开了文件，检测了下文件头而已，并不知道流信息；因此开始读包以获取流信息
     设置读包探测大小和最大时长，避免读太多的包！
    */
    formatCtx->probesize = 500 * 1024;
    formatCtx->max_analyze_duration = 5 * AV_TIME_BASE;
    
    erluFormatCtx->probesize = 500 * 1024;
    erluFormatCtx->max_analyze_duration = 5 * AV_TIME_BASE;
    
#if DEBUG
    NSTimeInterval begin = [[NSDate date] timeIntervalSinceReferenceDate];
#endif
    if (0 != avformat_find_stream_info(formatCtx, NULL)) {
        avformat_close_input(&formatCtx);
        self.error = _make_nserror_desc(FFPlayerErrorCode_StreamNotFound, @"不能找到流！");
        [self performErrorResultOnMainThread];
        //出错了，销毁下相关结构体
        avformat_close_input(&formatCtx);
        return;
    }
    
    if (0 != avformat_find_stream_info(erluFormatCtx, NULL)) {
        avformat_close_input(&erluFormatCtx);
        self.error = _make_nserror_desc(FFPlayerErrorCode_StreamNotFound, @"不能找到流！");
        [self performErrorResultOnMainThread];
        //出错了，销毁下相关结构体
        avformat_close_input(&erluFormatCtx);
        return;
    }
    
#if DEBUG
    NSTimeInterval end = [[NSDate date] timeIntervalSinceReferenceDate];
    //用于查看详细信息，调试的时候打出来看下很有必要
    av_dump_format(formatCtx, 0, moviePath, false);
    
    av_dump_format(erluFormatCtx, 0, erlumoviePath, false);
    
    MRFF_DEBUG_LOG(@"avformat_find_stream_info coast time:%g",end-begin);
#endif
    
    //确定最优的音视频流
    int st_index[AVMEDIA_TYPE_NB];
    memset(st_index, -1, sizeof(st_index));
    [self findBestStreams:formatCtx result:&st_index];
    [self findBestStreams:erluFormatCtx result:&st_index];
    
    //打开音频解码器，创建解码线程
    if (st_index[AVMEDIA_TYPE_AUDIO] >= 0){
        
        self.audioDecoder = [self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_AUDIO]];
        
        self.erluaudioDecoder = [self openStreamComponent:erluFormatCtx streamIdx:st_index[AVMEDIA_TYPE_AUDIO]];
        
        if(self.audioDecoder){
            self.audioDecoder.delegate = self;
            self.audioDecoder.name = @"mr-audio-dec";
            self.audioResample = [self createAudioResampleIfNeed];
        } else {
            av_log(NULL, AV_LOG_ERROR, "can't open audio stream.\n");
//            self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"音频流打开失败！");
//            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
//            avformat_close_input(&formatCtx);
//            return;
        }
        
        if(self.erluaudioDecoder){
            self.erluaudioDecoder.delegate = self;
            self.erluaudioDecoder.name = @"mrerlu-audio-dec";
            self.audioResample = [self createAudioResampleIfNeed];
        } else {
            av_log(NULL, AV_LOG_ERROR, "can't open audio stream.\n");
//            self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"音频流打开失败！");
//            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
//            avformat_close_input(&formatCtx);
//            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(onInitAudioRender:)]) {
            if (self.audioResample) {
                [self.delegate onInitAudioRender:AVSampleFormat2MR(self.audioResample.out_sample_fmt)];
            } else {
                [self.delegate onInitAudioRender:AVSampleFormat2MR(self.audioDecoder.format)];
            }
        }
    }

    //打开视频解码器，创建解码线程
    if (st_index[AVMEDIA_TYPE_VIDEO] >= 0){
//        self.videoDecoder = [self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_VIDEO]];
        if(self.videoDecoder){
            self.videoDecoder.delegate = self;
            self.videoDecoder.name = @"mr-video-dec";
            self.videoScale = [self createVideoScaleIfNeed];
        } else {
            av_log(NULL, AV_LOG_ERROR, "can't open video stream.");
//            self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"视频流打开失败！");
//            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
//            avformat_close_input(&formatCtx);
//            return;
        }
    }
    
    //音视频解码线程开始工作
    [self.audioDecoder start];
    [self.erluaudioDecoder start];
    
    [self.videoDecoder start];
    //准备渲染线程
    [self prepareRendererThread];
    //渲染线程开始工作
    [self.rendererThread start];
    
    
    
    //循环读包
    dispatch_queue_t queue = dispatch_queue_create("demux",DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue, ^{
        [self readPacketLoop:formatCtx];
    });
   
    dispatch_queue_t queue2 = dispatch_queue_create("demux2",DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue2, ^{
        [self readerluPacketLoop:erluFormatCtx];
    });
    
    
    
    //读包线程结束了，销毁下相关结构体
//    avformat_close_input(&formatCtx);
//    avformat_close_input(&erluFormatCtx);
}

#pragma mark - FFDecoderDelegate0x20

- (int)decoder:(FFDecoder0x20 *)decoder wantAPacket:(AVPacket *)pkt
{
    if (decoder == self.audioDecoder) {
        return packet_queue_get(&_audioq, pkt, 1);
    } else if (decoder == self.videoDecoder) {
        return packet_queue_get(&_videoq, pkt, 1);
    } else if (decoder == self.erluaudioDecoder) {
        return packet_queue_get(&_erluaudioq, pkt, 1);
    }else {
        return -1;
    }
}

- (void)decoder:(FFDecoder0x20 *)decoder reveivedAFrame:(AVFrame *)frame
{
    
    AVFrame *firstFrame = NULL;
    AVFrame *secondFrame = NULL;
    
    if (decoder == self.audioDecoder) {
        FrameQueue *fq = &_sampq;
        
//        AVFrame *outP = nil;
//        if (self.audioResample) {
//            if (![self.audioResample resampleFrame:frame out:&outP]) {
//                self.error = _make_nserror_desc(FFPlayerErrorCode_ResampleFrameFailed, @"音频帧重采样失败！");
//                [self performErrorResultOnMainThread];
//                return;
//            }
//        } else {
//            outP = frame;
//        }

        firstFrame = frame;
        
//        frame_queue_push(fq, frame, 0.0);
        int firstresult = av_buffersrc_add_frame_flags(buffersrc1_ctx, frame, AV_BUFFERSRC_FLAG_KEEP_REF);

        if (firstresult < 0) {
            printf("33333909090 %s",av_err2str(firstresult));
        }
        
        self.audioFrameCount++;
    } else if (decoder == self.videoDecoder) {
        FrameQueue *fq = &_pictq;
        
        AVFrame *outP = nil;
        if (self.videoScale) {
            if (![self.videoScale rescaleFrame:frame out:&outP]) {
                self.error = _make_nserror_desc(FFPlayerErrorCode_RescaleFrameFailed, @"视频帧重转失败！");
                [self performErrorResultOnMainThread];
                return;
            }
        } else {
            outP = frame;
        }
//        frame_queue_push(fq, outP, 0.0);
//        self.videoFrameCount++;
    } else if (decoder == self.erluaudioDecoder) {
        FrameQueue *fq = &_erlusampq;
        
//        AVFrame *outP = nil;
//        if (self.audioResample) {
//            if (![self.audioResample resampleFrame:frame out:&outP]) {
//                self.error = _make_nserror_desc(FFPlayerErrorCode_ResampleFrameFailed, @"音频帧重采样失败！");
//                [self performErrorResultOnMainThread];
//                return;
//            }
//        } else {
//            outP = frame;
//        }
        
        secondFrame = frame;
//        frame_queue_push(fq, frame, 0.0);
//        self.audioFrameCount++;
        
        int sencondresult = av_buffersrc_add_frame_flags(buffersrc2_ctx, frame, AV_BUFFERSRC_FLAG_KEEP_REF);

        if (sencondresult < 0) {
            printf("222222909090 %s",av_err2str(sencondresult));
        }
    }
    
    AVFrame *mixFrame = av_frame_alloc();
    int result = av_buffersink_get_frame(buffersink_ctx, mixFrame);
    if (result < 0) {
        printf("333333909090 %s",av_err2str(result));
    } else {

        FrameQueue *fq = &_sampq;
        frame_queue_push(fq, mixFrame, 0.0);
    }
}

- (void)mutilRecord {
    
}

- (void)beforeConfig {
    char args[512];
    const AVFilter *buffersrc = avfilter_get_by_name("abuffer");
    const AVFilter *buffersink = avfilter_get_by_name("abuffersink");
    AVFilterInOut *output = avfilter_inout_alloc();
    AVFilterInOut *inputs[2];
    inputs[0] = avfilter_inout_alloc();
    inputs[1] = avfilter_inout_alloc();

    char ch_layout[128];
    int nb_channels = 0;
    int pix_fmts[] = {self.audioDecoder.sampleFormat, AV_SAMPLE_FMT_NONE };

    int ret = 0;
    //创建滤镜容器
    filter_graph = avfilter_graph_alloc();
    if (!inputs[0] || !inputs[1] || !output || !filter_graph) {
        ret = AVERROR(ENOMEM);
        goto end;
    }

    //声道布局
    nb_channels = self.audioDecoder.channelLayout;
    av_get_channel_layout_string(ch_layout, sizeof(ch_layout), nb_channels, self.audioDecoder.channelLayout);

    //输入缓存1的配置
    snprintf(args, sizeof(args),
        "sample_rate=44100:sample_fmt=8:channel_layout=stereo:channels=2:time_base=1/14112000");

    
    ret = avfilter_graph_create_filter(&buffersrc1_ctx, buffersrc, "in1",
                                       args, NULL, filter_graph);
    if (ret < 0)
    {
        goto end;
    }

    //输入缓存2的配置
    
    ret = avfilter_graph_create_filter(&buffersrc2_ctx, buffersrc, "in2",
        args, NULL, filter_graph);
    if (ret < 0)
    {
        goto end;
    }

    //创建输出
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
        NULL, NULL, filter_graph);
    if (ret < 0)
    {
        goto end;
    }
    
    enum AVSampleFormat out_sample_fmts[2];
    out_sample_fmts[0]= AV_SAMPLE_FMT_FLTP;
    out_sample_fmts[1] = AV_SAMPLE_FMT_NONE;

    int64_t out_channel_layouts[2];
    out_channel_layouts[0] = AV_CH_LAYOUT_STEREO;
    out_channel_layouts[1] = -1;

    int out_sample_rates[2];
    out_sample_rates[0] = 44100;
    out_sample_rates[1] = -1;

    do{
        ret = av_opt_set_int_list(buffersink_ctx, "sample_fmts", out_sample_fmts, -1,
                                AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output sample format\n");
            break;
        }
        ret = av_opt_set_int_list(buffersink_ctx, "channel_layouts", out_channel_layouts, -1,
                                AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output channel layout\n");
            break;
        }
        ret = av_opt_set_int_list(buffersink_ctx, "sample_rates", out_sample_rates, -1,
                                AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output sample rate\n");
            break;
        }
    }while(0);

    inputs[0]->name = av_strdup("in1");
    inputs[0]->filter_ctx = buffersrc1_ctx;
    inputs[0]->pad_idx = 0;
    inputs[0]->next = inputs[1];

    inputs[1]->name = av_strdup("in2");
    inputs[1]->filter_ctx = buffersrc2_ctx;
    inputs[1]->pad_idx = 0;
    inputs[1]->next = NULL;

    output->name = av_strdup("out");
    output->filter_ctx = buffersink_ctx;
    output->pad_idx = 0;
    output->next = NULL;
    
    char filter_description[256];
//    snprintf(filter_description, sizeof(filter_description),
//             "[in1]aresample=44100[a1];[in2]aresample=44100[a2];[a1][a2]amix[out]");
    
    
//    snprintf(filter_description, sizeof(filter_description),"inputs=2:duration=first:dropout_transition=3");

    //引脚的输出和输入与滤镜容器的相反
    avfilter_graph_set_auto_convert(filter_graph, AVFILTER_AUTO_CONVERT_NONE);
    if ((ret = avfilter_graph_parse_ptr(filter_graph, filter_description,
        &output, inputs, NULL)) < 0) {
        goto end;
    }

    //使滤镜容器生效
    if ((ret = avfilter_graph_config(filter_graph, NULL)) < 0) {
        goto end;
    }
    
    printf("description \n%s", avfilter_graph_dump(filter_graph, NULL));
    
end:
    avfilter_inout_free(inputs);
    avfilter_inout_free(&output);
    
}

- (void)mixAudio:(AVFrame *)frame1 andFrame2:(AVFrame *)frame2 {
    //设置缓存滤镜和输出滤镜
    
    finalFrame = av_frame_alloc();
    
    int result = 0;
    
    if (filter_graph != NULL)
    {
        result = av_buffersrc_add_frame_flags(buffersrc1_ctx, frame1, AV_BUFFERSRC_FLAG_KEEP_REF);

        if (result < 0) {
            printf("909090 %s",av_err2str(result));
        }
    }

    if (filter_graph != NULL) {
        result = av_buffersrc_add_frame_flags(buffersrc2_ctx, frame2, AV_BUFFERSRC_FLAG_KEEP_REF);
        if (result < 0) {
            printf("909090 %s",av_err2str(result));
        }
    }

    if (filter_graph != NULL) {
        result = av_buffersink_get_frame(buffersink_ctx, finalFrame);
        if (result < 0) {
            printf("909090 %s",av_err2str(result));
        } else {
            
            FrameQueue *fq = &_finalSampq;
            frame_queue_push(fq, finalFrame, 0.0);
        }
    }
    if (result < 0) {
        
    }
}

#pragma mark - RendererThread

- (void)prepareRendererThread
{
    self.rendererThread = [[MRThread alloc] initWithTarget:self selector:@selector(rendererThreadFunc) object:nil];
    self.rendererThread.name = @"mr-renderer";
}

- (CVPixelBufferRef _Nullable)pixelBufferFromAVFrame:(AVFrame *)frame
{
#if USE_PIXEL_BUFFER_POOL
    if (!self.pixelBufferPool){
        CVPixelBufferPoolRef pixelBufferPool = [MRConvertUtil createCVPixelBufferPoolRef:frame->format w:frame->width h:frame->height fullRange:frame->color_range != AVCOL_RANGE_MPEG];
        if (pixelBufferPool) {
            CVPixelBufferPoolRetain(pixelBufferPool);
            self.pixelBufferPool = pixelBufferPool;
        }
    }
#endif
    
    CVPixelBufferRef pixelBuffer = [MRConvertUtil pixelBufferFromAVFrame:frame opt:self.pixelBufferPool];
    return pixelBuffer;
}

- (void)doAudioDisplayVideoFrame:(Frame *)vp
{
    if ([self.delegate respondsToSelector:@selector(reveiveFrameToRenderer:)]) {
        @autoreleasepool {
//            CVPixelBufferRef pixelBuffer = [self pixelBufferFromAVFrame:vp->frame];
//            if (pixelBuffer) {
                [self.delegate reveiveAudioToPlay];
//            }
        }
    }
}

- (void)doDisplayVideoFrame:(Frame *)vp
{
    if ([self.delegate respondsToSelector:@selector(reveiveFrameToRenderer:)]) {
        @autoreleasepool {
            CVPixelBufferRef pixelBuffer = [self pixelBufferFromAVFrame:vp->frame];
            if (pixelBuffer) {
                [self.delegate reveiveFrameToRenderer:pixelBuffer];
            }
        }
    }
}

- (void)rendererThreadFunc
{
    //调用了stop方法，则不再渲染
    while (!self.abort_request) {
        
        NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
        AVFrame *firstFrame = NULL; AVFrame*secondFrame = NULL;
        if (frame_queue_nb_remaining(&_sampq) > 0) {
            Frame *vp = frame_queue_peek(&_sampq);
            firstFrame = vp->frame;
            
//            int result = av_buffersrc_add_frame_flags(buffersrc1_ctx, firstFrame, AV_BUFFERSRC_FLAG_KEEP_REF);
            [self doAudioDisplayVideoFrame:vp];
//            [self doDisplayVideoFrame:vp];
//            frame_queue_pop(&_pictq);
//            self.videoFrameCount--;
            
//            frame_queue_pop(&_sampq);
//            self.audioFrameCount--;
        }
        
        if (frame_queue_nb_remaining(&_erlusampq) > 0) {
            Frame *vp = frame_queue_peek(&_erlusampq);
            secondFrame = vp->frame;
//            frame_queue_pop(&_erlusampq);
//            [self doAudioDisplayVideoFrame:vp];
            
//            int result = av_buffersrc_add_frame_flags(buffersrc1_ctx, secondFrame, AV_BUFFERSRC_FLAG_KEEP_REF);
        }
        
        NSTimeInterval end = CFAbsoluteTimeGetCurrent();
        int cost = (end - begin) * 1000;
        av_log(NULL, AV_LOG_DEBUG, "render video frame cost:%dms\n", cost);
        mr_msleep(40 - cost);
        
//        mr_msleep(10);
        
//        if (firstFrame != nil && secondFrame != nil) {
//            [self mixAudio:firstFrame andFrame2:secondFrame];
//
//            if (frame_queue_nb_remaining(&_finalSampq) > 0) {
//                Frame *vp = frame_queue_peek(&_finalSampq);
//    //            frame_queue_pop(&_finalSampq);
//                [self doAudioDisplayVideoFrame:vp];
//            }
//        }
    }
}

- (UInt32)fetchPacketSample:(uint8_t *)buffer
                  wantBytes:(UInt32)bufferSize
{
    UInt32 filled = 0;
    while (bufferSize > 0) {
        Frame *ap = NULL;
        //队列里缓存帧大于0，则取出
        if (frame_queue_nb_remaining(&_sampq) > 0) {
            ap = frame_queue_peek(&_sampq);
            av_log(NULL, AV_LOG_VERBOSE, "render audio frame %lld\n", ap->frame->pts);
        }
        
//        if (frame_queue_nb_remaining(&_finalSampq) > 0) {
//            ap = frame_queue_peek(&_finalSampq);
//            av_log(NULL, AV_LOG_VERBOSE, "render audio frame %lld\n", ap->frame->pts);
//        }
        
        if (NULL == ap) {
            return filled;
        }
        
        uint8_t *src = ap->frame->data[0];
        const int fmt = ap->frame->format;
        assert(0 == av_sample_fmt_is_planar(fmt));
        
        int data_size = av_samples_get_buffer_size(ap->frame->linesize, 2, ap->frame->nb_samples, fmt, 1);
        int l_src_size = data_size;//ap->frame->linesize[0];
        const int offset = ap->offset;
        const void *from = src + offset;
        int left = l_src_size - offset;
        
        //根据剩余数据长度和需要数据长度算出应当copy的长度
        int leftBytesToCopy = FFMIN(bufferSize, left);
        
        memcpy(buffer, from, leftBytesToCopy);
        buffer += leftBytesToCopy;
        bufferSize -= leftBytesToCopy;
        ap->offset += leftBytesToCopy;
        filled += leftBytesToCopy;
        if (leftBytesToCopy >= left){
            //读取完毕，则清空；读取下一个包
            av_log(NULL, AV_LOG_DEBUG, "packet sample:next frame\n");
            frame_queue_pop(&_sampq);
            
//            frame_queue_pop(&_finalSampq);
            self.audioFrameCount--;
        }
    }
    return filled;
}

// 真正的播放方法
- (UInt32)fetchPlanarSample:(uint8_t *)l_buffer
                   leftSize:(UInt32)l_size
                      right:(uint8_t *)r_buffer
                  rightSize:(UInt32)r_size
{
    UInt32 filled = 0;
    while (l_size > 0 || r_size > 0) {
        Frame *ap = NULL;
        //队列里缓存帧大于0，则取出
        if (frame_queue_nb_remaining(&_sampq) > 0) {
            ap = frame_queue_peek(&_sampq);
            av_log(NULL, AV_LOG_VERBOSE, "render audio frame %lld\n", ap->frame->pts);
        }
//
//        if (frame_queue_nb_remaining(&_erlusampq) > 0) {
//            ap = frame_queue_peek(&_erlusampq);
//            av_log(NULL, AV_LOG_VERBOSE, "render audio frame %lld\n", ap->frame->pts);
//        }
        
//        if (frame_queue_nb_remaining(&_finalSampq) > 0) {
//            ap = frame_queue_peek(&_finalSampq);
//            av_log(NULL, AV_LOG_VERBOSE, "render audio frame %lld\n", ap->frame->pts);
//        }
        
        if (NULL == ap) {
            return filled;
        }
        
        uint8_t *l_src = ap->frame->data[0];
        const int fmt  = ap->frame->format;
        assert(av_sample_fmt_is_planar(fmt));
        
        int data_size = av_samples_get_buffer_size(ap->frame->linesize, 1, ap->frame->nb_samples, fmt, 1);
        
        int l_src_size = data_size;//af->frame->linesize[0];
        const int offset = ap->offset;
        const void *leftFrom = l_src + offset;
        int leftBytesLeft = l_src_size - offset;
        
        //根据剩余数据长度和需要数据长度算出应当copy的长度
        int leftBytesToCopy = FFMIN(l_size, leftBytesLeft);
        
        memcpy(l_buffer, leftFrom, leftBytesToCopy);
        l_buffer += leftBytesToCopy;
        l_size -= leftBytesToCopy;
        ap->offset += leftBytesToCopy;
        filled += leftBytesToCopy;
        uint8_t *r_src = ap->frame->data[1];
        int r_src_size = l_src_size;//af->frame->linesize[1];
        if (r_src) {
            const void *right_from = r_src + offset;
            int right_bytes_left = r_src_size - offset;
            
            //根据剩余数据长度和需要数据长度算出应当copy的长度
            int rightBytesToCopy = FFMIN(r_size, right_bytes_left);
            memcpy(r_buffer, right_from, rightBytesToCopy);
            r_buffer += rightBytesToCopy;
            r_size -= rightBytesToCopy;
        }
        
        if (leftBytesToCopy >= leftBytesLeft){
            //读取完毕，则清空；读取下一个包
            av_log(NULL, AV_LOG_DEBUG, "packet sample:next frame\n");
            frame_queue_pop(&_sampq);
//            self.audioFrameCount--;
            
//            frame_queue_pop(&_erlusampq);
            
//            frame_queue_pop(&_finalSampq);
        }
    }
    return filled;
}

- (void)performErrorResultOnMainThread
{
    MR_sync_main_queue(^{
        if (self.onErrorBlock) {
            self.onErrorBlock();
        }
    });
}

- (void)play
{
    [self.readThread start];
}

- (void)asyncStop
{
    [self performSelectorInBackground:@selector(_stop) withObject:self];
}

- (void)onError:(dispatch_block_t)block
{
    self.onErrorBlock = block;
}

- (void)onPacketBufferFull:(dispatch_block_t)block
{
    self.onPacketBufferFullBlock = block;
}

- (void)onPacketBufferEmpty:(dispatch_block_t)block
{
    self.onPacketBufferEmptyBlock = block;
}

- (MR_PACKET_SIZE)peekPacketBufferStatus
{
    return (MR_PACKET_SIZE){_videoq.nb_packets,_audioq.nb_packets,0};
}



char av_error[AV_ERROR_MAX_STRING_SIZE] = { 0 };
#define av_err2str(errnum) \
    av_make_error_string(av_error, AV_ERROR_MAX_STRING_SIZE, errnum)



int InitABufferFilter(AVFilterGraph* filterGraph, AVFilterContext** filterctx, const char* name,
                      AVRational timebase, int samplerate, enum AVSampleFormat format, uint64_t channel_layout){
    const AVFilter* bufferfilter = avfilter_get_by_name("abuffer");
    *filterctx = NULL;
    char in_args[512];
    snprintf(in_args, sizeof(in_args),
            "time_base=%d/%d:sample_rate=%d:sample_fmt=%s:channel_layout=0x%" PRId64,
            timebase.num, timebase.den, samplerate,
            av_get_sample_fmt_name(format),
            channel_layout);
    return avfilter_graph_create_filter(filterctx, bufferfilter, name, in_args, NULL, filterGraph);
}

int InitABufferSinkFilter(AVFilterGraph* filterGraph, AVFilterContext** filterctx, const char* name,
                          enum AVSampleFormat format, int samplerate, uint64_t channel_layout){
    const AVFilter* buffersinkfilter = avfilter_get_by_name("abuffersink");

    enum AVSampleFormat out_sample_fmts[2];
    out_sample_fmts[0]= format;
    out_sample_fmts[1] = AV_SAMPLE_FMT_NONE;

    int64_t out_channel_layouts[2];
    out_channel_layouts[0] = channel_layout;
    out_channel_layouts[1] = -1;

    int out_sample_rates[2];
    out_sample_rates[0] = samplerate;
    out_sample_rates[1] = -1;

    int ret = avfilter_graph_create_filter(filterctx, buffersinkfilter, name, NULL, NULL, filterGraph);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot create audio buffer sink\n");
        
    }
    do{
        ret = av_opt_set_int_list(*filterctx, "sample_fmts", out_sample_fmts, -1,
                                AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output sample format\n");
            break;
        }
        ret = av_opt_set_int_list(*filterctx, "channel_layouts", out_channel_layouts, -1,
                                AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output channel layout\n");
            break;
        }
        ret = av_opt_set_int_list(*filterctx, "sample_rates", out_sample_rates, -1,
                                AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output sample rate\n");
            break;
        }
    }while(0);
    
    return ret;
}

- (void)otherConfig {
    char args[512];
    const AVFilter *buffersrc = avfilter_get_by_name("abuffer");
    const AVFilter *buffersink = avfilter_get_by_name("abuffersink");
    AVFilterInOut *output = avfilter_inout_alloc();
    AVFilterInOut *inputs[2];
    inputs[0] = avfilter_inout_alloc();
    inputs[1] = avfilter_inout_alloc();

    char ch_layout[128];
    int nb_channels = 0;
    int pix_fmts[] = {self.audioDecoder.sampleFormat, AV_SAMPLE_FMT_NONE };

    int ret = 0;
    //创建滤镜容器
    filter_graph = avfilter_graph_alloc();
    if (!inputs[0] || !inputs[1] || !output || !filter_graph) {
        ret = AVERROR(ENOMEM);
        
        NSLog(@"fail fail");
        return;
    }

    //声道布局
    nb_channels = self.audioDecoder.channelLayout;
    av_get_channel_layout_string(ch_layout, sizeof(ch_layout), nb_channels, self.audioDecoder.channelLayout);

    //输入缓存1的配置
    snprintf(args, sizeof(args),
        "sample_rate=44100:sample_fmt=8:channel_layout=stereo:channels=2:time_base=1/14112000");

    
    ret = avfilter_graph_create_filter(&buffersrc1_ctx, buffersrc, "in1",
                                       args, NULL, filter_graph);
    if (ret < 0)
    {
        NSLog(@"fail fail");
        return;
    }

    //输入缓存2的配置
    
    ret = avfilter_graph_create_filter(&buffersrc2_ctx, buffersrc, "in2",
        args, NULL, filter_graph);
    if (ret < 0)
    {
        NSLog(@"fail fail");
        return;
    }

    //创建输出
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
        NULL, NULL, filter_graph);
    if (ret < 0)
    {
        NSLog(@"fail fail");
        return;
    }
    
    enum AVSampleFormat out_sample_fmts[2];
    out_sample_fmts[0]= AV_SAMPLE_FMT_FLTP;
    out_sample_fmts[1] = AV_SAMPLE_FMT_NONE;

    int64_t out_channel_layouts[2];
    out_channel_layouts[0] = AV_CH_LAYOUT_STEREO;
    out_channel_layouts[1] = -1;

    int out_sample_rates[2];
    out_sample_rates[0] = 44100;
    out_sample_rates[1] = -1;

    do{
        ret = av_opt_set_int_list(buffersink_ctx, "sample_fmts", out_sample_fmts, -1,
                                AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output sample format\n");
            break;
        }
        ret = av_opt_set_int_list(buffersink_ctx, "channel_layouts", out_channel_layouts, -1,
                                AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output channel layout\n");
            break;
        }
        ret = av_opt_set_int_list(buffersink_ctx, "sample_rates", out_sample_rates, -1,
                                AV_OPT_SEARCH_CHILDREN);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Cannot set output sample rate\n");
            break;
        }
    }while(0);
         
    char in_args[1024];
    
    const AVFilter* mixFilter = avfilter_get_by_name("amix");
    AVFilterContext* mixFilterCtx = NULL;
    //inputs=3:duration=first:dropout_transition=3
    bool first_file_end_exit;
    char duration[20];
    int mix_flags = 0;
    if(mix_flags == 0){
        strcpy(duration, "first");
        first_file_end_exit = true;
    }
    snprintf(in_args, sizeof(in_args),"inputs=2");
    ret = avfilter_graph_create_filter(&mixFilterCtx, mixFilter, "amix", in_args, NULL, filter_graph);

        
        
        
        ret = avfilter_link(buffersrc1_ctx, 0, mixFilterCtx, 0);
        ret = avfilter_link(buffersrc2_ctx, 0, mixFilterCtx, 1);
        ret = avfilter_link(mixFilterCtx, 0, buffersink_ctx, 0);

        ret = avfilter_graph_config(filter_graph, NULL);
        if(ret < 0)
            return;
}


@end
