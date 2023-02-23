//
//  MR0x31FFMpegMovie.m
//  FFmpegTutorial-iOS
//
//  Created by zouran on 2022/10/26.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x31FFMpegMovie.h"
#include <libavcodec/avcodec.h>
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/opt.h"
#include "libavutil/imgutils.h"
#import  "MRConvertUtil.h"
#include <libavformat/avformat.h>
#include <libavutil/pixdesc.h>

@interface MR0x31FFMpegMovie()
{
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
    
    AVOutputFormat *ofmt;
    AVFormatContext *ifmt_ctx, *ofmt_ctx;
    AVPacket pkt;
    const char *in_filename, *out_filename;
    int ret, i;
    int stream_index;
    int *stream_mapping;
    int stream_mapping_size;
    
    AVFrame *de_frame;
        AVFrame *en_frame;
        // 用于视频像素转换
    struct SwsContext *sws_ctx;
        // 用于读取视频
        AVFormatContext *in_fmt;
        // 用于解码
        AVCodecContext *de_ctx;
        // 用于编码
        AVCodecContext *en_ctx;
        // 用于封装jpg
        AVFormatContext *ou_fmt;
        int video_ou_index;
    
    int video_index;
    
    int ptsInc;
    
}

@end


@implementation MR0x31FFMpegMovie

- (void)dealloc {
    NSLog(@"movie delloc");
}

- (void)starPicture:(NSString *)path {
    [self yuvConversionSetup];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        [self mainDoJpgToVideo];
        [self pic:@""];
    });
}

- (void)startEnable:(NSString *)path {
    path = [[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"];
    [self yuvConversionSetup];
    ptsInc = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        AVStream *stream = NULL;
        // http://blog.csdn.net/owen7500/article/details/47187513
        AVFormatContext* avformat_context = avformat_alloc_context();
        const char *url = [path cStringUsingEncoding:NSUTF8StringEncoding];
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
//        AVCodec *audiocodec_avcodec = avcodec_find_decoder(audiocodec_context->codec_id);
        AVCodec *videocodec_avcodec = avcodec_find_decoder(videocodec_context->codec_id);
//        int avcodec_open2_result = avcodec_open2(audiocodec_context,audiocodec_avcodec,NULL);
//        if (avcodec_open2_result != 0){
//            NSLog(@"打开解码器失败");
//            return;
//        }
        int avcodec_open2_result2 = avcodec_open2(videocodec_context,videocodec_avcodec,NULL);
        if (avcodec_open2_result2 != 0){
            NSLog(@"打开解码器失败gggg");
            return;
        }
//        NSLog(@"解码器名称：%@",[NSString stringWithFormat:@"%s", audiocodec_avcodec->name]);
        NSLog(@"解码器名称：%@",[NSString stringWithFormat:@"%s", videocodec_avcodec->name]);
        
//        int re = av_seek_frame(avformat_context, video_stream_index, 20 * AV_TIME_BASE, AVSEEK_FLAG_ANY);
        
    
        AVPacket *packet = (AVPacket*)av_malloc(sizeof(AVPacket));
        AVFrame *avframe_in = av_frame_alloc();
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
                    
                    
//                    double a = avframe_in->pts * ;
//                    sleep(avframe_in->pkt_duration);
//                    sleep(a);
                    
//                    usleep(100000.0 * av_q2d(stream->time_base) * avframe_in->pkt_duration);
                    
//                    NSLog(@"sleep time %f",a);
                    
                    double ts = av_q2d(stream->time_base) * avframe_in->best_effort_timestamp;
                    int64_t ttss = ts * AV_TIME_BASE;
                    
                    if (ttss == 6000000) {
//                        avcodec_close(videocodec_context);
                    }
                    // 缩小10倍 原来是15384
//                    AVRational new_time_base = {1,1};
                    AVRational old = stream->time_base;
                    int oldDen = stream->time_base.den;
                    int newDen = oldDen / 10;
                    AVRational new_time_base = {stream->time_base.num,1};
                    NSLog(@"old time baser %f",av_q2d(stream->time_base));
                    int64_t newPts = av_rescale_q_rnd(avframe_in->pts, new_time_base, stream->time_base,AV_ROUND_PASS_MINMAX);
//                        pkt.dts = av_rescale_q_rnd(pkt.dts, ost->st->time_base, ost->st->time_base, (AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
//                        pkt.duration = av_rescale_q(pkt.duration, ost->st->time_base, ost->st->time_base);
                    
                    
                    double tsff = av_q2d(new_time_base) * avframe_in->best_effort_timestamp;
                    int64_t ttssee = tsff * AV_TIME_BASE;
                    
                    double tsffori = av_q2d(stream->time_base) * avframe_in->best_effort_timestamp;
                    int64_t ttsseeori = tsffori * AV_TIME_BASE;
                    NSLog(@"pts--- %lld  origin pts ---- %lld",ttssee,ttsseeori);
                    
//                    usleep();
                    
//                    int64_t currentSampleTime = ttssee;
                    
                    CMTime currentSampleTimeCM = CMTimeMake(ttssee, 1000000);
                    
                    NSLog(@"second llll %f",CMTimeGetSeconds(currentSampleTimeCM));

                    CMTime currentSampleTime = CMTimeMake(ttssee, 1000000);
                    CMTime differenceFromLastFrame = CMTimeSubtract(currentSampleTime, previousFrameTime);
                    CFAbsoluteTime currentActualTime = CFAbsoluteTimeGetCurrent();
                    
                    CGFloat frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame);
                    CGFloat actualTimeDifference = currentActualTime - previousActualFrameTime;
                    
                    if (frameTimeDifference > actualTimeDifference)
                    {
//                        usleep(1000000.0 * (frameTimeDifference - actualTimeDifference));
                    }
                    
                    previousFrameTime = currentSampleTime;
                    previousActualFrameTime = CFAbsoluteTimeGetCurrent();
                    
                    /*
                    {
                        // Do this outside of the video processing queue to not slow that down while waiting
                        CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef);
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
                    }
                     */
                    
//                    NSLog(@"%lld=====%lld",ttss,avframe_in->pkt_duration);
//                    current_index++;
//                    NSLog(@"当前界面第%d %d",videocodec_context->width , videocodec_context->height);
                    CVPixelBufferRef buf = [MRConvertUtil yuvavFrame2pixelBuffer:avframe_in];
                    
//                    CMTime presentationTimeStamp = kCMTimeInvalid;
//                    int64_t originPTS = avframe_in->pts;
//                    presentationTimeStamp = CMTimeMake(originPTS, originPTS * 1000);
//
//                    int64_t timea = presentationTimeStamp.value;
//                    int64_t timeb = presentationTimeStamp.timescale;
//                    float currentTime = (float)timea / timeb;
//                    NSLog(@"ffmpeg time %f",currentTime);
                    
//                    CMSampleBufferRef sampleBufferRef = [self convertCVImageBufferRefToCMSampleBufferRef:buf withPresentationTimeStamp:presentationTimeStamp];
//                    CVPixelBufferRelease(buf);
//                    NSLog(@"format -> %d",avframe_in->format);
                    __unsafe_unretained MR0x31FFMpegMovie *weakSelf = self;
                    runSynchronouslyOnVideoProcessingQueue(^{
                        if (self.delegate && [self.delegate respondsToSelector:@selector(currenFFMpegtMovie:time:)]) {
                            [self.delegate currenFFMpegtMovie:self time:ttss];
                        }
//                        [weakSelf processMovieFrame:sampleBufferRef];
                        [weakSelf processMovieFrame:buf withSampleTime:kCMTimeZero];
//                        CMSampleBufferInvalidate(sampleBufferRef);
                        CVPixelBufferRelease(buf);
                        
                    });
//                    [self processMovieFrame:sampleBufferRef];
                }
            }
            else if (packet->stream_index == audio_stream_index) {
                
//                avcodec_send_packet(audiocodec_context, packet);
//                int audio_decode_result = avcodec_receive_frame(audiocodec_context, avframe_in);
//                if (audio_decode_result == 0) {
//                    NSLog(@"音频====");
//                    struct SwrContext *au_convert_ctx = swr_alloc();
//                    au_convert_ctx = swr_alloc_set_opts(au_convert_ctx,
//                                                        AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_S16, 44100,
//                                                        audiocodec_context->channel_layout, audiocodec_context->sample_fmt, audiocodec_context->sample_rate,
//                                                        0, NULL);
//                    swr_init(au_convert_ctx);
//                    int out_linesize;
//                    int out_buffer_size = av_samples_get_buffer_size(&out_linesize, audiocodec_context->channels,audiocodec_context->frame_size,audiocodec_context->sample_fmt, 1);
//                    uint8_t *out_buffer = (uint8_t *)av_malloc(out_buffer_size);
//                    //解码
//                    swr_convert(au_convert_ctx, &out_buffer, out_linesize, (const uint8_t **)avframe_in->data ,avframe_in->nb_samples);
//                    swr_free(&au_convert_ctx);
//                    au_convert_ctx = NULL;
//                    //播放
//                    NSData *pcm = [NSData dataWithBytes:out_buffer length:out_buffer_size];
//
//                    if (pcm) {
//
//                    }
//                    av_free(out_buffer);
//                }
            }
        }
        NSLog(@"解码完成");
        av_packet_free(&packet);
        av_frame_free(&avframe_in);
        avcodec_close(audiocodec_context);
        avcodec_close(videocodec_context);
        avformat_free_context(avformat_context);
        
    });

}

- (void)yuvConversionSetup;
{
    if ([GPUImageContext supportsFastTextureUpload])
    {
        runSynchronouslyOnVideoProcessingQueue(^{
            [GPUImageContext useImageProcessingContext];

            _preferredConversion = kColorConversion709;
            isFullYUVRange       = YES;
            yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];

            if (!yuvConversionProgram.initialized)
            {
                [yuvConversionProgram addAttribute:@"position"];
                [yuvConversionProgram addAttribute:@"inputTextureCoordinate"];

                if (![yuvConversionProgram link])
                {
                    NSString *progLog = [yuvConversionProgram programLog];
                    NSLog(@"Program link log: %@", progLog);
                    NSString *fragLog = [yuvConversionProgram fragmentShaderLog];
                    NSLog(@"Fragment shader compile log: %@", fragLog);
                    NSString *vertLog = [yuvConversionProgram vertexShaderLog];
                    NSLog(@"Vertex shader compile log: %@", vertLog);
                    yuvConversionProgram = nil;
                    NSAssert(NO, @"Filter shader link failed");
                }
            }

            yuvConversionPositionAttribute = [yuvConversionProgram attributeIndex:@"position"];
            yuvConversionTextureCoordinateAttribute = [yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
            yuvConversionLuminanceTextureUniform = [yuvConversionProgram uniformIndex:@"luminanceTexture"];
            yuvConversionChrominanceTextureUniform = [yuvConversionProgram uniformIndex:@"chrominanceTexture"];
            yuvConversionMatrixUniform = [yuvConversionProgram uniformIndex:@"colorConversionMatrix"];

            [GPUImageContext setActiveShaderProgram:yuvConversionProgram];

            glEnableVertexAttribArray(yuvConversionPositionAttribute);
            glEnableVertexAttribArray(yuvConversionTextureCoordinateAttribute);
        });
    }
}

#pragma mark -
#pragma mark Movie processing

- (void)enableSynchronizedEncodingUsingMovieWriter:(GPUImageMovieWriter *)movieWriter;
{
    synchronizedMovieWriter = movieWriter;
    movieWriter.encodingLiveVideo = NO;
}

- (CMSampleBufferRef)convertCVImageBufferRefToCMSampleBufferRef:(CVImageBufferRef)pixelBuffer withPresentationTimeStamp:(CMTime)presentationTimeStamp
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CMSampleBufferRef newSampleBuffer = NULL;
    OSStatus res = 0;
    
    CMSampleTimingInfo timingInfo;
    timingInfo.duration              = kCMTimeInvalid;
    timingInfo.decodeTimeStamp       = presentationTimeStamp;
    timingInfo.presentationTimeStamp = presentationTimeStamp;
    
    CMVideoFormatDescriptionRef videoInfo = NULL;
    res = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    if (res != 0) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
    }
    
    res = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                             pixelBuffer,
                                             true,
                                             NULL,
                                             NULL,
                                             videoInfo,
                                             &timingInfo, &newSampleBuffer);
    
    CFRelease(videoInfo);
    if (res != 0) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
        
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return newSampleBuffer;
}



- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer;
{
//    CMTimeGetSeconds
//    CMTimeSubtract
    
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(movieSampleBuffer);
    CVImageBufferRef movieFrame = CMSampleBufferGetImageBuffer(movieSampleBuffer);

//    processingFrameTime = currentSampleTime;
    [self processMovieFrame:movieFrame withSampleTime:currentSampleTime];
}

- (void)processMovieFrame:(CVPixelBufferRef)movieFrame withSampleTime:(CMTime)currentSampleTime
{
    int bufferHeight = (int) CVPixelBufferGetHeight(movieFrame);
    int bufferWidth = (int) CVPixelBufferGetWidth(movieFrame);

    CFTypeRef colorAttachments = CVBufferGetAttachment(movieFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL)
    {
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo)
        {
            if (isFullYUVRange)
            {
                _preferredConversion = kColorConversion601FullRange;
            }
            else
            {
                _preferredConversion = kColorConversion601;
            }
        }
        else
        {
            _preferredConversion = kColorConversion709;
        }
    }
    else
    {
        if (isFullYUVRange)
        {
            _preferredConversion = kColorConversion601FullRange;
        }
        else
        {
            _preferredConversion = kColorConversion601;
        }

    }
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();

    // Fix issue 1580
    [GPUImageContext useImageProcessingContext];
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        CVOpenGLESTextureRef luminanceTextureRef = NULL;
        CVOpenGLESTextureRef chrominanceTextureRef = NULL;

        //        if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
        if (CVPixelBufferGetPlaneCount(movieFrame) > 0) // Check for YUV planar inputs to do RGB conversion
        {

            if ( (imageBufferWidth != bufferWidth) && (imageBufferHeight != bufferHeight) )
            {
                imageBufferWidth = bufferWidth;
                imageBufferHeight = bufferHeight;
            }

            CVReturn err;
            // Y-plane
            glActiveTexture(GL_TEXTURE4);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            }
            else
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }

            luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, luminanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

            // UV-plane
            glActiveTexture(GL_TEXTURE5);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            }
            else
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }

            chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

//            if (!allTargetsWantMonochromeData)
//            {
                [self convertYUVToRGBOutput];
//            }

            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
            }
            
            [outputFramebuffer unlock];

            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
            }

            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
            CFRelease(luminanceTextureRef);
            CFRelease(chrominanceTextureRef);
        }
        else
        {
            // TODO: Mesh this with the new framebuffer cache
//            CVPixelBufferLockBaseAddress(movieFrame, 0);
//
//            CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, coreVideoTextureCache, movieFrame, NULL, GL_TEXTURE_2D, GL_RGBA, bufferWidth, bufferHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &texture);
//
//            if (!texture || err) {
//                NSLog(@"Movie CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
//                NSAssert(NO, @"Camera failure");
//                return;
//            }
//
//            outputTexture = CVOpenGLESTextureGetName(texture);
//            //        glBindTexture(CVOpenGLESTextureGetTarget(texture), outputTexture);
//            glBindTexture(GL_TEXTURE_2D, outputTexture);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//
//            for (id<GPUImageInput> currentTarget in targets)
//            {
//                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
//                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
//
//                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
//                [currentTarget setInputTexture:outputTexture atIndex:targetTextureIndex];
//
//                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
//            }
//
//            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
//            CVOpenGLESTextureCacheFlush(coreVideoTextureCache, 0);
//            CFRelease(texture);
//
//            outputTexture = 0;
        }
    }
    else
    {
        // Upload to texture
        CVPixelBufferLockBaseAddress(movieFrame, 0);
        
//        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(bufferWidth, bufferHeight) textureOptions:self.outputTextureOptions onlyTexture:YES];

        glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
        // Using BGRA extension to pull in video frame data directly
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     self.outputTextureOptions.internalFormat,
                     bufferWidth,
                     bufferHeight,
                     0,
                     self.outputTextureOptions.format,
                     self.outputTextureOptions.type,
                     CVPixelBufferGetBaseAddress(movieFrame));
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
        }
        
        [outputFramebuffer unlock];
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
        }
        CVPixelBufferUnlockBaseAddress(movieFrame, 0);
    }
}

- (void)endProcessing;
{
    keepLooping = NO;
    [displayLink setPaused:YES];

    for (id<GPUImageInput> currentTarget in targets)
    {
        [currentTarget endProcessing];
    }
    
    if (synchronizedMovieWriter != nil)
    {
        [synchronizedMovieWriter setVideoInputReadyCallback:^{return NO;}];
        [synchronizedMovieWriter setAudioInputReadyCallback:^{return NO;}];
    }
    
}

- (void)cancelProcessing
{
    if (reader) {
        [reader cancelReading];
    }
    [self endProcessing];
}

- (void)convertYUVToRGBOutput;
{
    [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(imageBufferWidth, imageBufferHeight) onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };

    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };

    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(yuvConversionLuminanceTextureUniform, 4);

    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(yuvConversionChrominanceTextureUniform, 5);

    glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);

    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (BOOL)audioEncodingIsFinished {
    return audioEncodingIsFinished;
}

- (BOOL)videoEncodingIsFinished {
    return videoEncodingIsFinished;
}

- (NSString *)creatFile:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    NSString *tmpPath = [path stringByAppendingPathComponent:@"temp"];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpPath withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString* outFilePath = [tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", fileName]];
    return outFilePath;
}

- (int)remux {

    
    
    in_filename  = [[[NSBundle mainBundle] pathForResource:@"Timer" ofType:@"mp4"] cStringUsingEncoding:NSUTF8StringEncoding];
    NSString * path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@.mp4",@"Timer"]];
    
    NSString * imagepath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@.png",@"Timer"]];
    
    NSData *data = UIImagePNGRepresentation([UIImage imageNamed:@"saved"]);
    [data writeToFile:imagepath
           atomically:YES];
    
    in_filename = [[[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"] cStringUsingEncoding:NSUTF8StringEncoding];
    
//    out_filename = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    NSString * outpath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@.mov",@"Timer"]];
    out_filename = [self creatFile:@"nbnbooo.mp4"].UTF8String;
    
//    const char *url = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:outpath])
    {
        [[NSFileManager defaultManager] createFileAtPath:outpath contents:nil attributes:nil];
    }
    
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
    
    if ([[NSFileManager defaultManager] isWritableFileAtPath:path]) {
          NSLog(@"isWritable");
       }
       if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) {
          NSLog(@"isReadable");
       }
       if ( [[NSFileManager defaultManager] isExecutableFileAtPath:path]){
          NSLog(@"is Executable");
       }
    
//    [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];

    av_register_all();
    
    AVFormatContext* ifmt_ctx = avformat_alloc_context();
    AVFormatContext* ofmt_ctx = avformat_alloc_context();

    if ((ret = avformat_open_input(&ifmt_ctx, in_filename, NULL, NULL)) < 0) {
        fprintf(stderr, "Could not open input file '%s'", in_filename);
        goto end;
    }

    if ((ret = avformat_find_stream_info(ifmt_ctx, NULL)) < 0) {
        fprintf(stderr, "Failed to retrieve input stream information");
        goto end;
    }

//    av_dump_format(ifmt_ctx, NULL, in_filename, NULL);
    
    ret = avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, "output.mp4");

    if (ret < 0) {
        fprintf(stderr, "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }

    stream_mapping_size = ifmt_ctx->nb_streams;
    stream_mapping = av_mallocz_array(stream_mapping_size, sizeof(*stream_mapping));
    if (!stream_mapping) {
        ret = AVERROR(ENOMEM);
        goto end;
    }

    ofmt = ofmt_ctx->oformat;

    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        AVStream *out_stream;
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVCodecParameters *in_codecpar = in_stream->codecpar;

        if (in_codecpar->codec_type != AVMEDIA_TYPE_AUDIO &&
            in_codecpar->codec_type != AVMEDIA_TYPE_VIDEO &&
            in_codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            stream_mapping[i] = -1;
            continue;
        }

        stream_mapping[i] = stream_index++;

        out_stream = avformat_new_stream(ofmt_ctx, NULL);
        if (!out_stream) {
            fprintf(stderr, "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }

        ret = avcodec_parameters_copy(out_stream->codecpar, in_codecpar);
        if (ret < 0) {
            fprintf(stderr, "Failed to copy codec parameters\n");
            goto end;
        }
        out_stream->codecpar->codec_tag = 0;
    }
    av_dump_format(ofmt_ctx, 0, out_filename, 1);

    if (!(ofmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            fprintf(stderr, "Could not open output file '%s'", out_filename);
            goto end;
        }
    }

    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file\n");
        goto end;
    }

    while (1) {
        AVStream *in_stream, *out_stream;

        ret = av_read_frame(ifmt_ctx, &pkt);
        if (ret < 0)
            break;

        in_stream  = ifmt_ctx->streams[pkt.stream_index];
        if (pkt.stream_index >= stream_mapping_size ||
            stream_mapping[pkt.stream_index] < 0) {
            av_packet_unref(&pkt);
            continue;
        }

        pkt.stream_index = stream_mapping[pkt.stream_index];
        out_stream = ofmt_ctx->streams[pkt.stream_index];
        log_packet(ifmt_ctx, &pkt, "in");

        /* copy packet */
        pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
        pkt.pos = -1;
        log_packet(ofmt_ctx, &pkt, "out");

        ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
        if (ret < 0) {
            fprintf(stderr, "Error muxing packet\n");
            break;
        }
        av_packet_unref(&pkt);
    }

    av_write_trailer(ofmt_ctx);
end:

    avformat_close_input(&ifmt_ctx);

    /* close output */
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
        avio_closep(&ofmt_ctx->pb);
    avformat_free_context(ofmt_ctx);

    av_freep(&stream_mapping);

    if (ret < 0 && ret != AVERROR_EOF) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
        return 1;
    }

    return 0;
}

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt, const char *tag)
{
//    AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;
//
//    printf("%s: pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s stream_index:%d\n",
//           tag,
//           av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
//           av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
//           av_ts2str(pkt->duration), av_ts2timestr(pkt->duration, time_base),
//           pkt->stream_index);
}

- (int)cut_video:(double)from_seconds end:(double)end_seconds in_f:(char*) in_filename out_f:( char*)out_filename {
    AVOutputFormat *ofmt = NULL;
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    AVPacket pkt;
    int ret, i;
    
    in_filename  = [[[NSBundle mainBundle] pathForResource:@"Timer" ofType:@"mp4"] cStringUsingEncoding:NSUTF8StringEncoding];
    NSString * path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@.mp4",@"ran"]];
    out_filename = [path cStringUsingEncoding:NSUTF8StringEncoding];

    av_register_all();

    if ((ret = avformat_open_input(&ifmt_ctx, in_filename, 0, 0)) < 0) {
        fprintf(stderr, "Could not open input file '%s'", in_filename);
        goto end;
    }

    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
        fprintf(stderr, "Failed to retrieve input stream information");
        goto end;
    }

    av_dump_format(ifmt_ctx, 0, in_filename, 0);

    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);
    if (!ofmt_ctx) {
        fprintf(stderr, "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }

    ofmt = ofmt_ctx->oformat;

    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
        if (!out_stream) {
            fprintf(stderr, "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }

        ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
        if (ret < 0) {
            fprintf(stderr, "Failed to copy context from input to output stream codec context\n");
            goto end;
        }
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
            out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    av_dump_format(ofmt_ctx, 0, out_filename, 1);

    if (!(ofmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            fprintf(stderr, "Could not open output file '%s'", out_filename);
            goto end;
        }
    }

    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file\n");
        goto end;
    }

    //    int indexs[8] = {0};


    //    int64_t start_from = 8*AV_TIME_BASE;
    ret = av_seek_frame(ifmt_ctx, -1, 5*AV_TIME_BASE, AVSEEK_FLAG_ANY);
    if (ret < 0) {
        fprintf(stderr, "Error seek\n");
        goto end;
    }

    int64_t *dts_start_from = malloc(sizeof(int64_t) * ifmt_ctx->nb_streams);
    memset(dts_start_from, 0, sizeof(int64_t) * ifmt_ctx->nb_streams);
    int64_t *pts_start_from = malloc(sizeof(int64_t) * ifmt_ctx->nb_streams);
    memset(pts_start_from, 0, sizeof(int64_t) * ifmt_ctx->nb_streams);

    while (1) {
        AVStream *in_stream, *out_stream;

        ret = av_read_frame(ifmt_ctx, &pkt);
        if (ret < 0)
            break;

        in_stream  = ifmt_ctx->streams[pkt.stream_index];
        out_stream = ofmt_ctx->streams[pkt.stream_index];

        log_packet(ifmt_ctx, &pkt, "in");

        if (av_q2d(in_stream->time_base) * pkt.pts > 10) {
            av_free_packet(&pkt);
            break;
        }

        if (dts_start_from[pkt.stream_index] == 0) {
            dts_start_from[pkt.stream_index] = pkt.dts;
//            printf("dts_start_from: %s\n", av_ts2str(dts_start_from[pkt.stream_index]));
        }
        if (pts_start_from[pkt.stream_index] == 0) {
            pts_start_from[pkt.stream_index] = pkt.pts;
//            printf("pts_start_from: %s\n", av_ts2str(pts_start_from[pkt.stream_index]));
        }

        /* copy packet */
        pkt.pts = av_rescale_q_rnd(pkt.pts - pts_start_from[pkt.stream_index], in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        pkt.dts = av_rescale_q_rnd(pkt.dts - dts_start_from[pkt.stream_index], in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
        if (pkt.pts < 0) {
            pkt.pts = 0;
        }
        if (pkt.dts < 0) {
            pkt.dts = 0;
        }
        pkt.duration = (int)av_rescale_q((int64_t)pkt.duration, in_stream->time_base, out_stream->time_base);
        pkt.pos = -1;
        log_packet(ofmt_ctx, &pkt, "out");
        printf("\n");

        ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
        if (ret < 0) {
            fprintf(stderr, "Error muxing packet\n");
            break;
        }
        av_free_packet(&pkt);
    }
    free(dts_start_from);
    free(pts_start_from);

    av_write_trailer(ofmt_ctx);
end:

    avformat_close_input(&ifmt_ctx);

    /* close output */
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
        avio_closep(&ofmt_ctx->pb);
    avformat_free_context(ofmt_ctx);

    if (ret < 0 && ret != AVERROR_EOF) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
        return 1;
    }

    return 0;
}


- (void)writes {
        

}

- (void)mainDoJpgToVideo {
        AVOutputFormat *ofmt = NULL;
        AVFormatContext *in_fmt = NULL, *ofmt_ctx = NULL;
        AVPacket pkt;
        const char *in_filename, *out_filename;
        int ret, i;
        int stream_index = 0;
        int *stream_mapping = NULL;
        int stream_mapping_size = 0;
        
        int video_ou_index = 0;
        
        
        AVStream *stream;
        
        NSString *srcpath = [[NSBundle mainBundle] pathForResource:@"saved" ofType:@"png"];
        NSString *desPath = [self creatFile:@"savedpng.mp4"];
        
        int video_index = -1;
        
        // 创建jpg的解封装上下文
        if (avformat_open_input(&in_fmt, [srcpath UTF8String], NULL, NULL) < 0) {
            return;
        }
        if (avformat_find_stream_info(in_fmt, NULL) < 0) {
            return;
        }
        
        // 创建解码器及初始化解码器上下文用于对jpg进行解码
        for (int i=0; i<in_fmt->nb_streams; i++) {
            AVStream *stream = in_fmt->streams[i];
            /** 对于jpg图片来说，它里面就是一路视频流，所以媒体类型就是AVMEDIA_TYPE_VIDEO
             */
            if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
                AVCodec *codec = avcodec_find_decoder(stream->codecpar->codec_id);
                if (!codec) {
                    return;
                }
                de_ctx = avcodec_alloc_context3(codec);
                if (!de_ctx) {
                    return;
                }
                
                // 设置解码参数;文件解封装的AVStream中就包括了解码参数，这里直接流中拷贝即可
                if (avcodec_parameters_to_context(de_ctx, stream->codecpar) < 0) {
                    return;
                }
                
                // 初始化解码器及解码器上下文
                if (avcodec_open2(de_ctx, codec, NULL) < 0) {
                    return;
                }
                video_index = i;
                break;
            }
        }
        
        // 创建mp4文件封装器
        if (avformat_alloc_output_context2(&ofmt_ctx,NULL,NULL,[desPath UTF8String]) < 0) {
            return;
        }
        
        // 添加视频流
        stream = avformat_new_stream(ofmt_ctx, NULL);
        
        video_ou_index = stream->index;
        
        // 创建h264的编码器及编码器上下文
        AVCodec *en_codec = avcodec_find_encoder(AV_CODEC_ID_H264);
        if (!en_codec) {
            return;
        }
        en_ctx = avcodec_alloc_context3(en_codec);
        if (!en_ctx) {
            return;
        }
        // 设置编码参数
        AVStream *in_stream = in_fmt->streams[video_index];
        en_ctx->width = in_stream->codecpar->width;
        en_ctx->height = in_stream->codecpar->height;
        en_ctx->pix_fmt = (enum AVPixelFormat)in_stream->codecpar->format;
        en_ctx->bit_rate = 0.96*1000000;
        en_ctx->framerate = (AVRational){5,1};
        en_ctx->time_base = (AVRational){1,5};
        // 某些封装格式必须要设置，否则会造成封装后文件中信息的缺失
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            en_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
        }
        // x264编码特有
        if (en_codec->id == AV_CODEC_ID_H264) {
            // 代表了编码的速度级别
            av_opt_set(en_ctx->priv_data,"preset","slow",0);
            en_ctx->flags2 = AV_CODEC_FLAG2_LOCAL_HEADER;
        }
        
        // 初始化编码器及编码器上下文
        if (avcodec_open2(en_ctx,en_codec,NULL) < 0) {
           
        }
        
        // 设置视频流参数;对于封装来说，直接从编码器上下文拷贝即可
        if (avcodec_parameters_from_context(stream->codecpar, en_ctx) < 0) {
            return;
        }
        
        // 初始化封装器输出缓冲区
        if (!(ofmt_ctx->oformat->flags & AVFMT_NOFILE)) {
            if (avio_open2(&ofmt_ctx->pb, [desPath UTF8String], AVIO_FLAG_WRITE, NULL, NULL) < 0) {
                return;
            }
        }
        
        // 创建像素格式转换器
        sws_ctx = sws_getContext(de_ctx->width, de_ctx->height, de_ctx->pix_fmt,
                                             en_ctx->width, en_ctx->height, en_ctx->pix_fmt,
                                             0, NULL, NULL, NULL);
        if (!sws_ctx) {
            return;
        }
        
        // 写入封装器头文件信息；此函数内部会对封装器参数做进一步初始化
        if (avformat_write_header(ofmt_ctx, NULL) < 0) {
            return;
        }
        
    
        // 创建编解码用的AVFrame
        de_frame = av_frame_alloc();
        en_frame = av_frame_alloc();
        en_frame->width = en_ctx->width;
        en_frame->height = en_ctx->height;
        en_frame->format = en_ctx->pix_fmt;
        av_frame_get_buffer(en_frame, 0);
        av_frame_make_writable(en_frame);
        
        AVPacket *in_pkt = av_packet_alloc();
        while (av_read_frame(in_fmt, in_pkt) == 0) {
            
            
            if (in_pkt->stream_index != video_index) {
                continue;
            }
            
            // 先解码
            [self doDecode:in_pkt];
            av_packet_unref(in_pkt);
        }
        
        // 刷新解码缓冲区
        //    doDecode(NULL);
        av_write_trailer(ofmt_ctx);
}
    
- (void)doDecode:(AVPacket *)in_pkt
{
    static int num_pts = 0;
    // 先解码
    avcodec_send_packet(de_ctx, in_pkt);
    while (true) {
        int ret = avcodec_receive_frame(de_ctx, de_frame);
        if (ret == AVERROR_EOF) {
            [self doEncode:NULL];
            break;
        } else if(ret < 0) {
            break;
        }
        
        // 成功解码了；先进行格式转换然后再编码
        if(sws_scale(sws_ctx, de_frame->data, de_frame->linesize, 0, de_frame->height, en_frame->data, en_frame->linesize) < 0) {
            return;
        }
        
        // 编码前要设置好pts的值，如果en_ctx->time_base为{1,fps}，那么这里pts的值即为帧的个数值
        en_frame->pts = num_pts++;
        [self doEncode:en_frame];
    }
    
}

- (void)doEncode:(AVFrame *)en_frame1 {
    
    avcodec_send_frame(en_ctx, en_frame1);
    while (true) {
        AVPacket *ou_pkt = av_packet_alloc();
        if (avcodec_receive_packet(en_ctx, ou_pkt) < 0) {
            av_packet_unref(ou_pkt);
            break;
        }
        
        // 成功编码了;写入之前要进行时间基的转换
        AVStream *stream = ou_fmt->streams[video_ou_index];
        av_packet_rescale_ts(ou_pkt, en_ctx->time_base, stream->time_base);
        av_write_frame(ou_fmt, ou_pkt);
    }
}

- (void)pic:(NSString *)path {
//    path = [[NSBundle mainBundle] pathForResource:@"black_empty" ofType:@"mp4"];
//    path = [[NSBundle mainBundle] pathForResource:@"clipname_010" ofType:@"png"];
    path = [[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"];
    
    AVStream *stream = NULL;
    // http://blog.csdn.net/owen7500/article/details/47187513
    AVFormatContext* avformat_context = avformat_alloc_context();
    const char *url = [path cStringUsingEncoding:NSUTF8StringEncoding];
    int avformat_open_input_result = avformat_open_input(&avformat_context, url, NULL, NULL);
    if(avformat_open_input_result !=0) {
        NSLog(@"封装格式上下文打开文件, 打开文件失败");
        return;
    }
    int avformat_find_stream_info_result = avformat_find_stream_info(avformat_context, NULL);
    if (avformat_find_stream_info_result < 0) {
        NSLog(@"查找失败");
    }
    int video_stream_index = -1;
    for (int i = 0; i < avformat_context->nb_streams;i++) {
        // codec 弃用
        if (avformat_context->streams[i]->codecpar->codec_type==AVMEDIA_TYPE_VIDEO){
            
            stream = avformat_context->streams[i];
            
            video_stream_index = i;
            break;
        }
    }
    
    AVCodecContext *videocodec_context = avcodec_alloc_context3(NULL);
    
    if (videocodec_context == NULL)  {
        NSLog(@"Could not  videocodec_context allocate AVCodecContext\n");
        return;
    }
   
    int avcodec_parameters_to_context_result = avcodec_parameters_to_context(videocodec_context, avformat_context->streams[video_stream_index]->codecpar);
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
    NSLog(@"解码器名称：%@",[NSString stringWithFormat:@"%s", videocodec_avcodec->name]);
    
//        int re = av_seek_frame(avformat_context, video_stream_index, 20 * AV_TIME_BASE, AVSEEK_FLAG_ANY);
    

    AVPacket *packet = (AVPacket*)av_malloc(sizeof(AVPacket));
    AVFrame *avframe_in = av_frame_alloc();
//    int current_index = 0;
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
                
                
//                    double a = avframe_in->pts * ;
//                    sleep(avframe_in->pkt_duration);
//                    sleep(a);
                
//                    usleep(100000.0 * av_q2d(stream->time_base) * avframe_in->pkt_duration);
                
//                    NSLog(@"sleep time %f",a);
                
                double ts = av_q2d(stream->time_base) * avframe_in->best_effort_timestamp;
                int64_t ttss = ts * AV_TIME_BASE;
                
                if (ttss == 6000000) {
//                        avcodec_close(videocodec_context);
                }
                double tsff = av_q2d(stream->time_base) * avframe_in->pts;
                int64_t ttssee = tsff * AV_TIME_BASE;
                NSLog(@"pts--- %lld",ttssee);
                

                
//                    usleep();
                
//                    int64_t currentSampleTime = ttssee;
                
                CMTime currentSampleTimeCM = CMTimeMake(ttssee, 1000000);
                
                NSLog(@"second llll %f",CMTimeGetSeconds(currentSampleTimeCM));

                CMTime currentSampleTime = CMTimeMake(ttssee, 1000000);
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
                
                /*
                {
                    // Do this outside of the video processing queue to not slow that down while waiting
                    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef);
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
                }
                 */
                
//                if (sws_isSupportedInput(avframe_in->format) <= 0) {
//                    NSAssert(NO, @"%d is not supported as input format");
//                } else if (sws_isSupportedOutput(AV_PIX_FMT_YUV420P) <= 0) {
//                    NSAssert(NO, @"%d is not supported as output format");
//                }
//                struct SwsContext *sws_ctx = sws_getContext(avframe_in->width,
//                                                     avframe_in->height,
//                                                     avframe_in->format,
//                                                     avframe_in->width,
//                                                     avframe_in->height,
//                             AV_PIX_FMT_YUV420P,
//                            SWS_FAST_BILINEAR,
//                             NULL,
//                             NULL,
//                             NULL
//                             );
//
//                AVFrame *out_frame = av_frame_alloc();
//                //important！
//                av_frame_copy_props(out_frame, avframe_in);
//
//                if(NULL == out_frame->data[0]){
//                    out_frame->format  = AV_PIX_FMT_YUV420P;
//                    out_frame->width   = avframe_in->width;
//                    out_frame->height  = avframe_in->height;
//
//                    av_image_fill_linesizes(out_frame->linesize, out_frame->format, out_frame->width);
//                    av_image_alloc(out_frame->data, out_frame->linesize, avframe_in->width, avframe_in->height, AV_PIX_FMT_YUV420P, 1);
//                }
//
//                int scale = sws_scale(sws_ctx, (uint8_t const * const *)avframe_in->data,
//                          avframe_in->linesize, 0, avframe_in->height,
//                          out_frame->data, out_frame->linesize);
                
//                    NSLog(@"%lld=====%lld",ttss,avframe_in->pkt_duration);
//                    current_index++;
//                    NSLog(@"当前界面第%d %d",videocodec_context->width , videocodec_context->height);
//                CVPixelBufferRef buf = [MRConvertUtil yuvavFrame2pixelBuffer:out_frame];
                CVPixelBufferRef buf = [MRConvertUtil yuvavFrame2pixelBuffer:avframe_in];
                
//                    CMTime presentationTimeStamp = kCMTimeInvalid;
//                    int64_t originPTS = avframe_in->pts;
//                    presentationTimeStamp = CMTimeMake(originPTS, originPTS * 1000);
//
//                    int64_t timea = presentationTimeStamp.value;
//                    int64_t timeb = presentationTimeStamp.timescale;
//                    float currentTime = (float)timea / timeb;
//                    NSLog(@"ffmpeg time %f",currentTime);
                
//                    CMSampleBufferRef sampleBufferRef = [self convertCVImageBufferRefToCMSampleBufferRef:buf withPresentationTimeStamp:presentationTimeStamp];
//                    CVPixelBufferRelease(buf);
//                    NSLog(@"format -> %d",avframe_in->format);
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(currenFFMpegtMovie:time:)]) {
                    [self.delegate currenFFMpegtMovie:self time:ttssee];
                }
                
                __unsafe_unretained MR0x31FFMpegMovie *weakSelf = self;
                runSynchronouslyOnVideoProcessingQueue(^{
//                    if (self.delegate && [self.delegate respondsToSelector:@selector(currenFFMpegtMovie:time:)]) {
//                        [self.delegate currenFFMpegtMovie:self time:ttss];
//                    }
//                        [weakSelf processMovieFrame:sampleBufferRef];
                    [weakSelf processMovieFrame:buf withSampleTime:kCMTimeZero];
//                        CMSampleBufferInvalidate(sampleBufferRef);
                    CVPixelBufferRelease(buf);
                    
                });
//                    [self processMovieFrame:sampleBufferRef];
            }
        }
        
    }
    NSLog(@"解码完成");
    av_packet_free(&packet);
    av_frame_free(&avframe_in);
    avcodec_close(videocodec_context);
    avformat_free_context(avformat_context);
}

- (void)appendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut {
    [self yuvConversionSetup];
    self.filePath = filePath;
    int ret = AVERROR(EAGAIN);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        AVStream *stream = NULL;
        // http://blog.csdn.net/owen7500/article/details/47187513
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
//        AVCodec *audiocodec_avcodec = avcodec_find_decoder(audiocodec_context->codec_id);
        AVCodec *videocodec_avcodec = avcodec_find_decoder(videocodec_context->codec_id);
//        int avcodec_open2_result = avcodec_open2(audiocodec_context,audiocodec_avcodec,NULL);
//        if (avcodec_open2_result != 0){
//            NSLog(@"打开解码器失败");
//            return;
//        }
        int avcodec_open2_result2 = avcodec_open2(videocodec_context,videocodec_avcodec,NULL);
        if (avcodec_open2_result2 != 0){
            NSLog(@"打开解码器失败gggg");
            return;
        }
        
//        int re = av_seek_frame(avformat_context, video_stream_index, trimIn, AVSEEK_FLAG_ANY);
//        if (re < 0) {
//            NSLog(@"seek 失败");
//            return;
//        }
        
        AVPacket *packet = (AVPacket*)av_malloc(sizeof(AVPacket));
        AVFrame *avframe_in = av_frame_alloc();
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
                    
                    CVPixelBufferRef buf = [MRConvertUtil yuvavFrame2pixelBuffer:avframe_in];
                    
                    __unsafe_unretained MR0x31FFMpegMovie *weakSelf = self;
                    runSynchronouslyOnVideoProcessingQueue(^{
                        if (self.delegate && [self.delegate respondsToSelector:@selector(currenFFMpegtMovie:time:)]) {
//                            [self.delegate currenFFMpegtMovie:self time:ttssee];
                            [self.delegate currenFFMpegtMovie:self time:ttssee];
                        }
                        if (buf) {
                            [weakSelf processMovieFrame:buf withSampleTime:kCMTimeZero];
                            CVPixelBufferRelease(buf);
                        }
                    });
                    
//                    avcodec_flush_buffers(videocodec_context);
                    
//                    if (ttssee >= trimOut) {
//                        break;
//                    }
                }
            }
            else if (packet->stream_index == audio_stream_index) {
                
            }
        }
        NSLog(@"解码完成");
        if (self.delegate && [self.delegate respondsToSelector:@selector(currenFFMpegtMovie:decodeFinished:)]) {
//            [self.delegate currenFFMpegtMovie:self decodeFinished:YES];
            
//            [self.delegate currenFFMpegtMovie:self decodeFinished:YES time:0];
        }
        av_packet_free(&packet);
        av_frame_free(&avframe_in);
        avcodec_close(audiocodec_context);
        avcodec_close(videocodec_context);
        avformat_free_context(avformat_context);
        
    });
}


@end
