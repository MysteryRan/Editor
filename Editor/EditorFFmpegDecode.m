//
//  EditorFFmpegDecode.m
//  Editor
//
//  Created by zouran on 2022/12/20.
//

#import "EditorFFmpegDecode.h"
#import <AVFoundation/AVFoundation.h>
#import "EditorConvertUtil.h"
#import "GPUImage.h"
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

@interface EditorFFmpegDecode() {
    
    BOOL audioEncodingIsFinished, videoEncodingIsFinished;
    GPUImageMovieWriter *synchronizedMovieWriter;
    AVAssetReader *reader;
    AVPlayerItemVideoOutput *playerItemOutput;
    CADisplayLink *displayLink;
    CMTime previousFrameTime, processingFrameTime;
    CFAbsoluteTime previousActualFrameTime;
    BOOL keepLooping;
    
    GLuint luminanceTexture, chrominanceTexture;
    
    GLProgram *yuvConversionProgram;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    const GLfloat *_preferredConversion;
    
    BOOL isFullYUVRange;
    
    int imageBufferWidth, imageBufferHeight;
}

@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (nonatomic, strong) EditorVideoScale *videoScale;


@end

@implementation EditorFFmpegDecode

- (void)appendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut {
    dispatch_queue_t parseQueue = dispatch_queue_create("parse_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(parseQueue, ^{
        AVStream *stream = NULL;
        AVFormatContext* avformat_context = avformat_alloc_context();
        const char *url = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
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
        int current_index = 0;
        while (av_read_frame(avformat_context,packet)>=0) {
            //>=:读取到了
            // <0:读取错误或者读取完毕
            //2、是否是我们的视频流
            if (packet->stream_index == video_stream_index) {
                // 第七部 视频解码->播放视频->得到视频像素数据
                avcodec_send_packet(videocodec_context, packet);
                int video_decode_result = avcodec_receive_frame(videocodec_context, avframe_in);
                if (video_decode_result == 0) {
//                    NSLog(@"视频====");
                    double ss = av_q2d(stream->time_base);
                    double tsff = av_q2d(stream->time_base) * avframe_in->pts;
                    int64_t ttssee = tsff * AV_TIME_BASE;

                    double tsffori = av_q2d(stream->time_base) * avframe_in->pts;
                    int64_t ttsseeori = tsffori * AV_TIME_BASE;
                    CMTime currentSampleTimeCM = CMTimeMake(ttssee, 1000000);
                    CMTime currentSampleTime = CMTimeMake(ttssee, 1000000);
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
                    __unsafe_unretained EditorFFmpegDecode *weakSelf = self;
                    AVFrame *outP = nil;
                    if (self.videoScale) {
                        if (![self.videoScale rescaleFrame:avframe_in out:&outP]) {
                            return;
                        }
                    }

                    runSynchronouslyOnVideoProcessingQueue(^{
                        CVPixelBufferRef buf = [self pixelBufferFromAVFrame:outP];
                        if (self.delegate && [self.delegate respondsToSelector:@selector(reveiveFrameToRenderer:)] && buf) {
                            [self.delegate reveiveFrameToRenderer:buf];
                        }
                    });


//                    avcodec_flush_buffers(videocodec_context);

                    if (ttssee >= trimOut) {
                        break;
                    }
                }
            }
            else if (packet->stream_index == audio_stream_index) {
                
                
                
                
                
                
                
                
                
            }
        }
        NSLog(@"解码完成");
        
        int ret = avcodec_send_packet(videocodec_context, NULL);
            if (ret < 0) {
                fprintf(stderr, "Error submitting a packet for decoding (%s)\n", av_err2str(ret));
            }

            // get all the available frames from the decoder
        while (ret >= 0) {
            int video_decode_result = avcodec_receive_frame(videocodec_context, avframe_in);
            if (video_decode_result == 0) {
                
                double tsffori = av_q2d(stream->time_base) * avframe_in->pts;
                int64_t ttsseeori = tsffori * AV_TIME_BASE;
                
                AVFrame *outP = nil;
                if (self.videoScale) {
                    if (![self.videoScale rescaleFrame:avframe_in out:&outP]) {
                        return;
                    }
                }

                runSynchronouslyOnVideoProcessingQueue(^{
                    CVPixelBufferRef buf = [self pixelBufferFromAVFrame:outP];
                    if (self.delegate && [self.delegate respondsToSelector:@selector(reveiveFrameToRenderer:)] && buf) {
                        [self.delegate reveiveFrameToRenderer:buf];
                    }
                });
            } else {
                ret = -1;
            }
        }
                
        
        av_packet_free(&packet);
        av_frame_free(&avframe_in);
        avcodec_close(audiocodec_context);
        avcodec_close(videocodec_context);
        avformat_free_context(avformat_context);
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

- (void)dealloc {
    NSLog(@"editorffmpegdecode delloc");
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


@end
