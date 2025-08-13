//
//  FFMpegMovie.m
//  Editor
//
//  Created by zouran on 30/07/2025.
//

#import "EditorFFmpegDecode.h"
#import <AVFoundation/AVFoundation.h>
#import "EditorConvertUtil.h"
#import "EditorVideoScale.h"

#ifdef __cplusplus
extern "C" {
#endif
    
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/opt.h"
#include <libavutil/mathematics.h>
#include <libavutil/time.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libavutil/pixdesc.h>
#include "libavutil/timestamp.h"
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/opt.h>
    
#ifdef __cplusplus
};
#endif

const AVRational COMMON_TIME_BASE = {1, 600};


@interface EditorFFmpegDecode()
{
    CMTime previousFrameTime, processingFrameTime;
    CFAbsoluteTime previousActualFrameTime;
    
    GLuint luminanceTexture, chrominanceTexture;

    GLProgram *yuvConversionProgram;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    const GLfloat *_preferredConversion;
    
    BOOL isFullYUVRange;

    int imageBufferWidth, imageBufferHeight;
    
    //decode
    AVFormatContext *fmt_ctx;
    AVCodecContext *dec_ctx;
    const AVCodec *decoder;
    AVPacket *pkt;
    AVFrame *frame;
    AVStream *stream;
    int video_stream_idx;
    int ret;
    int64_t next_pts;  // 全局PTS计数器
}

@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (nonatomic, strong) EditorVideoScale *videoScale;



@end

@implementation EditorFFmpegDecode

/*
- (void)appendClipClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut {
    previousFrameTime = kCMTimeZero;
    previousActualFrameTime = CFAbsoluteTimeGetCurrent();
    
    if ([GPUImageContext supportsFastTextureUpload]) {
        isFullYUVRange = YES;
    }

    dispatch_queue_t parseQueue = dispatch_queue_create("parse_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(parseQueue, ^{
        AVStream *stream = NULL;
        AVFormatContext* avformat_context = avformat_alloc_context();
        const char *url = [[[NSBundle mainBundle] pathForResource:@"flower" ofType:@"MP4"] cStringUsingEncoding:NSUTF8StringEncoding];
        int avformat_open_input_result = avformat_open_input(&avformat_context, url, NULL, NULL);
        if(avformat_open_input_result !=0) {
            NSLog(@"封装格式上下文打开文件, 打开文件失败");
            return;
        }
        int avformat_find_stream_info_result = avformat_find_stream_info(avformat_context, NULL);
        if (avformat_find_stream_info_result < 0) {
            NSLog(@"查找失败");
        }
        int audio_stream_index = -1;
        int video_stream_index = -1;
        for (int i = 0; i < avformat_context->nb_streams;i++) {
            // codec 弃用
            if (avformat_context->streams[i]->codecpar->codec_type==AVMEDIA_TYPE_VIDEO){

                stream = avformat_context->streams[i];

                video_stream_index = i;
                break;
            }
        }

        for (int i = 0; i < avformat_context->nb_streams;i++) {
        // codec 弃用
            if (avformat_context->streams[i]->codecpar->codec_type==AVMEDIA_TYPE_AUDIO){
                audio_stream_index = i;
                break;
            }
        }
        AVCodecContext *audiocodec_context = avcodec_alloc_context3(NULL);
        AVCodecContext *videocodec_context = avcodec_alloc_context3(NULL);
        if (audiocodec_context == NULL)  {
            NSLog(@"Could  audiocodec_context not allocate AVCodecContext\n");
            return;
        }
        if (videocodec_context == NULL)  {
            NSLog(@"Could not  videocodec_context allocate AVCodecContext\n");
            return;
        }
//        int avcodec_parameters_to_context_result = avcodec_parameters_to_context(audiocodec_context, avformat_context->streams[audio_stream_index]->codecpar);
//        if (avcodec_parameters_to_context_result != 0) {
//            // 0 成功 其他失败
//            NSLog(@"获取解码器上下文失败");
//            return;
//        }
        int avcodec_parameters_to_context_result = avcodec_parameters_to_context_result = avcodec_parameters_to_context(videocodec_context, avformat_context->streams[video_stream_index]->codecpar);
        if (avcodec_parameters_to_context_result != 0) {
            // 0 成功 其他失败
            NSLog(@"获取解码器video上下文失败");
            return;
        }
        AVCodec *videocodec_avcodec = avcodec_find_decoder(videocodec_context->codec_id);
        int avcodec_open2_result2 = avcodec_open2(videocodec_context,videocodec_avcodec,NULL);
        if (avcodec_open2_result2 != 0){
            NSLog(@"打开解码器失败gggg");
            return;
        }

       self.videoScale = [self createVideoScaleIfNeed:videocodec_context];

//        int re = av_seek_frame(avformat_context, video_stream_index, trimIn, AVSEEK_FLAG_ANY);
//        if (re < 0) {
//            NSLog(@"seek 失败");
//            return;
//        }

        AVPacket *packet = (AVPacket*)av_malloc(sizeof(AVPacket));
        AVFrame *avframe_in = av_frame_alloc();
//        AVFrame *out_frame = av_frame_alloc();
        
        
        AVRational time_base = avformat_context->streams[video_stream_index]->time_base;//关键：时间基准
        
//        int64_t target_us = (int64_t)(10.88 * 1000000);
//        int64_t target_ts = av_rescale_q(target_us, AV_TIME_BASE_Q, time_base);
//        
////        NSLog(@"0000,%lld",target_ts);
//        videocodec_context->skip_loop_filter = AVDISCARD_NONREF;
//        av_seek_frame(avformat_context, video_stream_index, target_ts, AVSEEK_FLAG_BACKWARD);
//        avcodec_flush_buffers(videocodec_context);
        
        int current_index = 0;
        while (av_read_frame(avformat_context,packet)>=0) {
            //>=:读取到了
            // <0:读取错误或者读取完毕
            //2、是否是我们的视频流
            if (packet->stream_index == video_stream_index) {
                // 第七部 视频解码->播放视频->得到视频像素数据
//                double pts_sec = (packet->pts == AV_NOPTS_VALUE) ? 0 : packet->pts * av_q2d(time_base);
                    // 发送数据包并解码...
                if (packet->pts != AV_NOPTS_VALUE) {
                   
                            

                    if (avcodec_send_packet(videocodec_context, packet) < 0) {
                        fprintf(stderr, "发送数据包失败\n");
                        break;
                    }
                    int video_decode_result = avcodec_receive_frame(videocodec_context, avframe_in);
                    if (video_decode_result == 0) {
//                        NSLog(@"视频====");
                        
                        printf("Decode frame pts %d pkt.duration %d\n", (int)packet->pts, (int)packet->duration);
                        
                        //                    double ss = av_q2d(stream->time_base);
                        double tsff = av_q2d(stream->time_base) * avframe_in->pts;
                        int64_t ttssee = tsff * AV_TIME_BASE;
                        
                        double tsffori = av_q2d(stream->time_base) * avframe_in->pts;
                        //                    int64_t ttsseeori = tsffori * AV_TIME_BASE;
                        //                    CMTime currentSampleTimeCM = CMTimeMake(ttssee, 1000000);
                        CMTime currentSampleTime = CMTimeMake(ttssee, AV_TIME_BASE);
                        CMTime differenceFromLastFrame = CMTimeSubtract(currentSampleTime, previousFrameTime);
                        CFAbsoluteTime currentActualTime = CFAbsoluteTimeGetCurrent();
                        
                        CGFloat frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame);
                        CGFloat actualTimeDifference = currentActualTime - previousActualFrameTime;
                        
                        if (frameTimeDifference > actualTimeDifference)
                        {
                            usleep(1000000.0 * (frameTimeDifference - actualTimeDifference));
                        }
                        
                        previousFrameTime = currentSampleTime;
                        previousActualFrameTime = CFAbsoluteTimeGetCurrent();
                        __unsafe_unretained EditorFFmpegDecode *weakSelf = self;
                        AVFrame *outP = nil;
                        if (self.videoScale) {
                            if (![self.videoScale rescaleFrame:avframe_in out:&outP]) {
                                return;
                            }
                        }
                        //                    printf("Decode frame pts %d pkt.duration %d\n", (int)avframe_in->format, (int)avframe_in->buf);
                        NSLog(@"%@-----%d",self.videoScale,outP->width);
                        [self processFFmpegFrame:outP];
//                        runSynchronouslyOnVideoProcessingQueue(^{
//                            CVPixelBufferRef buf = [self pixelBufferFromAVFrame:outP];
//                            
//                            CVPixelBufferRef pixelBuffer = buf; // 输入的CVPixelBufferRef
//                            CMTime timestamp = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000); // 自定义时间戳
//                            
//                            // 创建格式描述
//                            CMVideoFormatDescriptionRef formatDesc;
//                            OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDesc);
//                            
//                            // 封装为CMSampleBufferRef
//                            CMSampleBufferRef sampleBuffer = NULL;
//                            CMSampleTimingInfo timingInfo = { kCMTimeInvalid, timestamp, timestamp };
//                            status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixelBuffer, formatDesc, &timingInfo, &sampleBuffer);
//                            [self processMovieFrame:sampleBuffer];
//                            
//                            CVPixelBufferRelease(buf);
//                            CVPixelBufferRelease(pixelBuffer);
//                            
//                            
//                        });
                        
                        
                        //                    avcodec_flush_buffers(videocodec_context);
                        
                        //                    if (ttssee >= trimOut) {
                        //                        break;
                        //                    }
                    }
                }
            }
            
        }
        NSLog(@"解码完成");
        
        
//        int ret = avcodec_send_packet(videocodec_context, NULL);
//            if (ret < 0) {
//                fprintf(stderr, "Error submitting a packet for decoding (%s)\n", av_err2str(ret));
//            }

            // get all the available frames from the decoder
//        while (ret >= 0) {
//
//            int video_decode_result = avcodec_receive_frame(videocodec_context, avframe_in);
//            if (video_decode_result == 0) {
//                fprintf(stderr, "frame frame frame", av_err2str(ret));
//
//                double tsffori = av_q2d(stream->time_base) * avframe_in->pts;
//                int64_t ttsseeori = tsffori * AV_TIME_BASE;
//
//                AVFrame *outP = nil;
//
//
////                runSynchronouslyOnVideoProcessingQueue(^{
//                    CVPixelBufferRef buf = [self pixelBufferFromAVFrame:avframe_in];
//
////                });
//            } else {
//                ret = -1;
//            }
//        }
                
        
        av_packet_free(&packet);
        av_frame_free(&avframe_in);
        avcodec_close(audiocodec_context);
        avcodec_close(videocodec_context);
        avformat_free_context(avformat_context);
    });
}
 */

- (instancetype)init {
    self = [super init];
    if (self) {
        self->video_stream_idx = -1;
        [self yuvConversionSetup];
    }
    return self;
}

- (void)processFFmpegFrame:(AVFrame *)outP {
    runSynchronouslyOnVideoProcessingQueue(^{
        CVPixelBufferRef buf = [self pixelBufferFromAVFrame:outP];
        
        CVPixelBufferRef pixelBuffer = buf; // 输入的CVPixelBufferRef
        CMTime timestamp = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000); // 自定义时间戳
        
        // 创建格式描述
        CMVideoFormatDescriptionRef formatDesc;
        OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDesc);
        
        // 封装为CMSampleBufferRef
        CMSampleBufferRef sampleBuffer = NULL;
        CMSampleTimingInfo timingInfo = { kCMTimeInvalid, timestamp, timestamp };
        status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixelBuffer, formatDesc, &timingInfo, &sampleBuffer);
        [self processMovieFrame:sampleBuffer];
        
        CVPixelBufferRelease(buf);
        CVPixelBufferRelease(pixelBuffer);
    });
}

- (CVPixelBufferRef _Nullable)pixelBufferFromAVFrame:(AVFrame *)frame
{
#if USE_PIXEL_BUFFER_POOL
    if (!self.pixelBufferPool){
        CVPixelBufferPoolRef pixelBufferPool = [EditorConvertUtil createCVPixelBufferPoolRef:frame->format w:frame->width h:frame->height fullRange:frame->color_range != AVCOL_RANGE_MPEG];
        if (pixelBufferPool) {
            CVPixelBufferPoolRetain(pixelBufferPool);
            self.pixelBufferPool = pixelBufferPool;
        }
    }
#endif
    
    CVPixelBufferRef pixelBuffer = [EditorConvertUtil pixelBufferFromAVFrame:frame opt:self.pixelBufferPool];
    return pixelBuffer;
}

- (EditorVideoScale *)createVideoScaleIfNeed:(AVCodecContext *)context
{
    //未指定期望像素格式
    
    if ([EditorVideoScale checkCanConvertFrom:AV_PIX_FMT_YUV420P to:AV_PIX_FMT_NV12]) {
        //创建像素格式转换上下文
        EditorVideoScale *scale = [[EditorVideoScale alloc] initWithSrcPixFmt:AV_PIX_FMT_YUV420P dstPixFmt:AV_PIX_FMT_NV12 picWidth:context->width picHeight:context->height];
        return scale;
    } else {
        //TODO ??
        return nil;
    }
}

// 时间戳转换函数
int64_t convert_to_common_pts(int64_t src_pts, AVRational src_time_base) {
    return av_rescale_q(src_pts, src_time_base, AV_TIME_BASE_Q);
}

// 时间值转换函数
double convert_to_common_time(int64_t src_pts, AVRational src_time_base) {
    return av_q2d(AV_TIME_BASE_Q) * convert_to_common_pts(src_pts, src_time_base);
}

- (void)beginDecode {
    dispatch_queue_t parseQueue = dispatch_queue_create("parse_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(parseQueue, ^{
    // 分配数据包和帧
    self->pkt = av_packet_alloc();
    self->frame = av_frame_alloc();
    if (!self->pkt || !self->frame) {
        self->ret = AVERROR(ENOMEM);
        return;
    }
    
        double trimInSec = self.trimIn / (AV_TIME_BASE * 1.0);
        double trimOutSec = self.trimOut / (AV_TIME_BASE * 1.0);

    // 计算起始和结束时间戳（以流时间基为单位）
    int64_t start_ts = (int64_t)(trimInSec / av_q2d(self->stream->time_base));
    int64_t end_ts = (int64_t)(trimOutSec / av_q2d(self->stream->time_base));
//
        printf("Decoding from %llds to %llds (ts: %"PRId64" to %"PRId64")\n",self.trimIn, self.trimOut, start_ts, end_ts);
    
    // 定位到起始位置（关键帧）
        self->ret = av_seek_frame(self->fmt_ctx, self->video_stream_idx, start_ts, AVSEEK_FLAG_BACKWARD);
        if (self->ret < 0) {
            fprintf(stderr, "Seek failed: %s\n", av_err2str(self->ret));
        return;;
    }
    
    // 刷新解码器缓冲区
        avcodec_flush_buffers(self->dec_ctx);
    
    int in_target_range = 0;
    int frames_decoded = 0;
    
        self.videoScale = [self createVideoScaleIfNeed:self->dec_ctx];

    // 解码循环
        while (av_read_frame(self->fmt_ctx, self->pkt) >= 0) {
            if (self->pkt->stream_index != self->video_stream_idx) {
            av_packet_unref(self->pkt);
            continue;
        }
        
//        // 检查是否超出结束时间
//        NSLog(@"pkt->pts--->%lld",pkt->pts);
//        if (pkt->pts != AV_NOPTS_VALUE && pkt->pts > end_ts) {
//            fprintf(stderr, "Error 否超出结束时间: %s\n", av_err2str(ret));
//            av_packet_unref(pkt);
//            break;
//        }
        
        // 发送数据包到解码器
            self->ret = avcodec_send_packet(self->dec_ctx, self->pkt);
            if (self->ret < 0 && self->ret != AVERROR(EAGAIN)) {
                fprintf(stderr, "Error sending packet: %s\n", av_err2str(self->ret));
                av_packet_unref(self->pkt);
            continue;
        }
        
            av_packet_unref(self->pkt);
        
        // 接收解码后的帧
        while (self->ret >= 0) {
            self->ret = avcodec_receive_frame(self->dec_ctx, self->frame);
            if (self->ret == AVERROR(EAGAIN) || self->ret == AVERROR_EOF) {
//                fprintf(stderr, "Error during : %s\n", av_err2str(ret));
                break;
            } else if (self->ret < 0) {
//                fprintf(stderr, "Error during decoding: %s\n", av_err2str(ret));
                break;
            }
            
            // 计算帧时间（秒）
            // flower time_base 1/600      fps 1/30 pts+= 20
            // samplevv time_base 1/90000  fps 1/30 pts+= 300
            // 更新全局PTS计数器（按帧率递增）
//            self->next_pts += av_rescale_q(1, AV_TIME_BASE_Q, (AVRational){1, 30}); // 假设30fps
//            NSLog(@"hhhhh frame pts %lld",av_rescale_q(1, AV_TIME_BASE_Q, self->stream->time_base));

            
            self->next_pts += 20;
            int64_t new_pts = av_rescale_q_rnd(
               self->frame->pts,
                self->stream->time_base,    // 输入时间基
               AV_TIME_BASE_Q,   // 输出时间基
                AV_ROUND_NEAR_INF        // 最接近的舍入模式
            );
            
            double frame_time = new_pts * av_q2d(AV_TIME_BASE_Q);
            
            NSLog(@"hhhhh frame pts %lld",self->frame->pts);

            
//            frame_time = convert_to_common_time(self->frame->pts, self->stream->time_base);
            
//            NSLog(@"qqqq frame pts %lld",frame->pts);

//            int64_t newnew = av_rescale_q_rnd(self->frame->pts, self->stream->time_base, AV_TIME_BASE_Q, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
            
//            NSLog(@"hhhhh frame pts %lld",newnew);
//            frame_time = newnew * av_q2d(AV_TIME_BASE_Q);
            
            int64_t frame_ll_time = frame_time * AV_TIME_BASE;
            // 检查是否进入目标范围
            if (!in_target_range && frame_ll_time >= self.trimIn) {
                in_target_range = 1;
                printf("----- START of target segment -----\n");
            }
            
            // 处理目标范围内的帧
            if (in_target_range) {
//                NSLog(@"cmopare %lld ---- %lld",frame_ll_time,self.trimOut);
                frames_decoded++;
                //匀速播放
                double timestep = av_q2d(self->stream->time_base) * self->frame->pts;
                CMTime currentSampleTime = CMTimeMake(timestep * AV_TIME_BASE, AV_TIME_BASE);
                CMTime differenceFromLastFrame = CMTimeSubtract(currentSampleTime, self->previousFrameTime);
                CFAbsoluteTime currentActualTime = CFAbsoluteTimeGetCurrent();
                CGFloat frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame);
                CGFloat actualTimeDifference = currentActualTime - self->previousActualFrameTime;
                if (frameTimeDifference > actualTimeDifference)
                {
                    usleep(1000000.0 * (frameTimeDifference - actualTimeDifference));
                }
                self->previousFrameTime = currentSampleTime;
                self->previousActualFrameTime = CFAbsoluteTimeGetCurrent();
                
                // 输出帧信息
                //                    printf("Frame %4d: pts=%s pts_time=%fs %dx%d\n",
                //                           frames_decoded,
                //                           av_ts2str(frame->pts), frame_time,
                //                           frame->width, frame->height);
                
                //整个在时间线上的位置
                int64_t current = 0 + frame_ll_time - self.trimIn;
                NSLog(@"neibu  %lld",current);

                if (self.decodeDelegate && [self.decodeDelegate respondsToSelector:@selector(clipCurrentTime:withDecode:)]) {
                    [self.decodeDelegate clipCurrentTime:current withDecode:self];
                }
                
//                if (frame_time >= 3.0) {
//                    
//                    //                        return;
//                }
                
                // 在这里处理帧：保存、分析等
                AVFrame *outP = nil;
                if (self.videoScale) {
                    if (![self.videoScale rescaleFrame:self->frame out:&outP]) {
                        return;
                    }
                }
                [self processFFmpegFrame:outP];
                if (frame_ll_time >= self.trimOut) {
                    printf("----- END of target segment -----\n");
                    in_target_range = 0;
                    return;
                }
            }
            
            av_frame_unref(self->frame);
        }
    }
    
//            printf("Decoded %d frames between %.1fs and %.1fs\n",frames_decoded, start_sec, end_sec);
    
    av_packet_free(&self->pkt);
    av_frame_free(&self->frame);
        avcodec_free_context(&self->dec_ctx);
    avformat_close_input(&self->fmt_ctx);
    
    });
    
}

- (void)appendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut {
    previousFrameTime = kCMTimeZero;
    previousActualFrameTime = CFAbsoluteTimeGetCurrent();
    next_pts = 0;
    self.trimIn = trimIn;
    self.trimOut = trimOut;
    
    if ([GPUImageContext supportsFastTextureUpload]) {
        isFullYUVRange = YES;
    }
    

        const char *filename = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
        
        // 打开输入文件
        if ((ret = avformat_open_input(&fmt_ctx, filename, NULL, NULL)) < 0) {
            fprintf(stderr, "Could not open file: %s\n", av_err2str(ret));
            return;
        }
        
        // 获取流信息
        if ((ret = avformat_find_stream_info(fmt_ctx, NULL)) < 0) {
            fprintf(stderr, "Failed to find stream info: %s\n", av_err2str(ret));
            return;
        }
        
        // 查找视频流
        video_stream_idx = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
        if (video_stream_idx < 0) {
            fprintf(stderr, "Could not find video stream\n");
            ret = AVERROR(EINVAL);
            return;
        }
        
        stream = fmt_ctx->streams[video_stream_idx];
        
        // 创建解码器上下文
        decoder = avcodec_find_decoder(stream->codecpar->codec_id);
        if (!decoder) {
            fprintf(stderr, "Failed to find decoder\n");
            ret = AVERROR_DECODER_NOT_FOUND;
            return;
        }
        
        dec_ctx = avcodec_alloc_context3(decoder);
        if (!dec_ctx) {
            fprintf(stderr, "Failed to allocate decoder context\n");
            ret = AVERROR(ENOMEM);
            return;
        }
        
        // 复制编解码器参数
        if ((ret = avcodec_parameters_to_context(dec_ctx, stream->codecpar)) < 0) {
            fprintf(stderr, "Failed to copy codec parameters: %s\n", av_err2str(ret));
            return;
        }
        
        // 打开解码器
        if ((ret = avcodec_open2(dec_ctx, decoder, NULL)) < 0) {
            fprintf(stderr, "Failed to open decoder: %s\n", av_err2str(ret));
            return;
        }
        
        

}

/*
- (void)appendPhotoClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut {
    // 将图片加载为 AVFrame
    dispatch_queue_t parseQueue = dispatch_queue_create("parse_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(parseQueue, ^{
        AVFormatContext *fmt_ctx = NULL;
        AVCodecContext *dec_ctx = NULL;
        const AVCodec *decoder;
        AVPacket *pkt = NULL;
        AVFrame *frame = NULL;
        int video_stream_idx = -1;
        int ret = 0;
        
        const char *filename = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
//        const char *filename = [[[NSBundle mainBundle] pathForResource:@"eye" ofType:@"png"] cStringUsingEncoding:NSUTF8StringEncoding];

        // 打开输入文件
        if ((ret = avformat_open_input(&fmt_ctx, filename, NULL, NULL)) < 0) {
            fprintf(stderr, "Could not open file: %s\n", av_err2str(ret));
            return;
        }
        
        // 获取流信息
        if ((ret = avformat_find_stream_info(fmt_ctx, NULL)) < 0) {
            fprintf(stderr, "Failed to find stream info: %s\n", av_err2str(ret));
            return;
        }
        
        // 查找视频流
        video_stream_idx = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
        if (video_stream_idx < 0) {
            fprintf(stderr, "Could not find video stream\n");
            ret = AVERROR(EINVAL);
            return;
        }
        
        AVStream *stream = fmt_ctx->streams[video_stream_idx];
        
        // 创建解码器上下文
        decoder = avcodec_find_decoder(stream->codecpar->codec_id);
        if (!decoder) {
            fprintf(stderr, "Failed to find decoder\n");
            ret = AVERROR_DECODER_NOT_FOUND;
            return;
        }
        
        dec_ctx = avcodec_alloc_context3(decoder);
        if (!dec_ctx) {
            fprintf(stderr, "Failed to allocate decoder context\n");
            ret = AVERROR(ENOMEM);
            return;
        }
        
        // 复制编解码器参数
        if ((ret = avcodec_parameters_to_context(dec_ctx, stream->codecpar)) < 0) {
            fprintf(stderr, "Failed to copy codec parameters: %s\n", av_err2str(ret));
            return;
        }
        
        // 打开解码器
        if ((ret = avcodec_open2(dec_ctx, decoder, NULL)) < 0) {
            fprintf(stderr, "Failed to open decoder: %s\n", av_err2str(ret));
            return;
        }
        self.videoScale = [self createVideoScaleIfNeed:dec_ctx];

        // 分配数据包和帧
        pkt = av_packet_alloc();
        frame = av_frame_alloc();
        if (!pkt || !frame) {
            ret = AVERROR(ENOMEM);
            return;
        }
        
        // 解码循环
        while (av_read_frame(fmt_ctx, pkt) >= 0) {
            if (pkt->stream_index != video_stream_idx) {
                av_packet_unref(pkt);
                continue;
            }
            
            // 发送数据包到解码器
            ret = avcodec_send_packet(dec_ctx, pkt);
            if (ret < 0 && ret != AVERROR(EAGAIN)) {
                fprintf(stderr, "Error sending packet: %s\n", av_err2str(ret));
                av_packet_unref(pkt);
                continue;
            }
            
            av_packet_unref(pkt);
            
            // 接收解码后的帧
            while (ret >= 0) {
                ret = avcodec_receive_frame(dec_ctx, frame);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                    break;
                } else if (ret < 0) {
                    fprintf(stderr, "Error during decoding: %s\n", av_err2str(ret));
                    break;
                }
                
                // 在这里处理帧：保存、分析等
                AVFrame *outP = nil;
                if (self.videoScale) {
                    if (![self.videoScale rescaleFrame:frame out:&outP]) {
                        return;
                    }
                }
                //5s
                int frame_count = (5 * 30);
                // 参数设置
                int fps = 30;
                AVRational time_base = {1, 600};
                // 计算帧间隔
                double frame_interval_sec = 1.0 / fps; // 0.03333秒
                int64_t pts_increment = frame_interval_sec / (time_base.num / (double)time_base.den);
                int64_t pts = 0;
                for (int i = 0; i <= frame_count; i++) {
                    frame->pts = pts;
                    NSLog(@"frame->pts %lld",frame->pts);
                    double frame_time = frame->pts * av_q2d(time_base);
                    usleep(1000000.0 * frame_interval_sec);
                    uint32_t frame_ll_time = frame_time * AV_TIME_BASE;
                    int64_t current = 0 + frame_ll_time - trimIn;
                    if (self.decodeDelegate && [self.decodeDelegate respondsToSelector:@selector(clipCurrentTime:)]) {
                        [self.decodeDelegate clipCurrentTime:current];
                    }
                    [self processFFmpegFrame:outP];
                    pts += pts_increment;
                }
                
                
                av_frame_unref(frame);
                
            }
        }
    });
}
 */

//const int fps = 30 * section;

/*
for (int i = 0; i < frame_count; i++) {
            // 设置时间戳
            image_frame->pts = pts++;
            
            // 发送帧到编码器
            int ret = avcodec_send_frame(codec_ctx, image_frame);
            if (ret < 0) {
                std::cerr << "发送帧到编码器失败" << std::endl;
                break;
            }

            // 接收编码后的包
            while (ret >= 0) {
                AVPacket pkt;
                av_init_packet(&pkt);
                pkt.data = nullptr;
                pkt.size = 0;
                
                ret = avcodec_receive_packet(codec_ctx, &pkt);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                    av_packet_unref(&pkt);
                    break;
                } else if (ret < 0) {
                    std::cerr << "编码期间发生错误" << std::endl;
                    av_packet_unref(&pkt);
                    break;
                }
                
                // 写入编码后的包
                av_packet_rescale_ts(&pkt, codec_ctx->time_base, fmt_ctx->streams[0]->time_base);
                pkt.stream_index = 0;
                av_interleaved_write_frame(fmt_ctx, &pkt);
                av_packet_unref(&pkt);
            }
 */

@end
