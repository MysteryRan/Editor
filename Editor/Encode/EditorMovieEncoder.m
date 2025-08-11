//
//  EditorMovieEncoder.m
//  Editor
//
//  Created by zouran on 2023/2/28.
//

#import "EditorMovieEncoder.h"
#import <Photos/Photos.h>
#ifdef __cplusplus
extern "C" {
#endif
#include <libavutil/opt.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#ifdef __cplusplus
};
#endif

@interface EditorMovieEncoder() {
    AVCodecContext                      *pCodecCtx;
    AVCodec                             *pCodec;
    AVPacket                             packet;
    AVFrame                             *pFrame;
    int                                  pictureSize;
    int                                  frameCounter;
    int                                  frameWidth; // 编码的图像宽度
    int                                  frameHeight; // 编码的图像高度
    AVFormatContext *outAVFormatContext;
    FILE *f;
    
    AVPacket *pkt;
    
    
    AVCodecContext *codec_ctx;
    AVFormatContext *fmt_ctx;
    AVStream *video_stream;
    int frame_count;
}

@property (nonatomic, strong) NSURL *outputURL;
@property (nonatomic) int width;
@property (nonatomic) int height;
@property (nonatomic) int fps;
@property (nonatomic) FILE *outputFile;

@end

@implementation EditorMovieEncoder

// 文件保存路径
- (NSString *)savedFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *fileName = [self savedFileName];
    fileName = @"bitrate.h264";
    
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    
    return writablePath;
}

// 拼接文件名
- (NSString *)savedFileName {
    return [[self nowTime2String] stringByAppendingString:@".h264"];
}

// 获取系统当前时间
- (NSString* )nowTime2String {
    NSString *date = nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"YYYY-MM-dd-hh-mm-ss";
    date = [formatter stringFromDate:[NSDate date]];
    
    return date;
}


- (instancetype)initWithVideoConfiguration {
    self = [super init];
    if (self) {
        [self lcinit];
    }
    return self;
}

- (void)lcinit {
    char *filename = [[self savedFilePath] UTF8String];
    /* find the mpeg1video encoder */
    pCodec = avcodec_find_encoder(AV_CODEC_ID_H264);
    if (!pCodec) {
        fprintf(stderr, "Codec '%s' not found\n");
        exit(1);
    }

    pCodecCtx = avcodec_alloc_context3(pCodec);
    if (!pCodecCtx) {
        fprintf(stderr, "Could not allocate video codec context\n");
        exit(1);
    }

    pkt = av_packet_alloc();
    if (!pkt)
        exit(1);

    //https://support.google.com/youtube/answer/1722171?hl=en#zippy=%2Cbitrate
    
    /* resolution must be a multiple of two */
    pCodecCtx->width = 1920;
    pCodecCtx->height = 1080;
    
    /* frames per second */
    pCodecCtx->time_base = (AVRational){1, 25};
    pCodecCtx->framerate = (AVRational){25, 1};
    
    uint64_t normalSet = 1024 * 1024 * 8;
    /* put sample parameters */
    pCodecCtx->bit_rate = normalSet * 10000;
    


    /* emit one intra frame every ten frames
     * check frame pict_type before passing frame
     * to encoder, if frame->pict_type is AV_PICTURE_TYPE_I
     * then gop_size is ignored and the output of encoder
     * will always be I frame irrespective to gop_size
     */
    pCodecCtx->gop_size = 10;
    pCodecCtx->max_b_frames = 1;
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;

    if (pCodec->id == AV_CODEC_ID_H264) {
        av_opt_set(pCodecCtx->priv_data, "preset", "ultrafast", 0);
        av_opt_set(pCodecCtx->priv_data, "tune", "fastdecode", 0);
        av_opt_set(pCodecCtx->priv_data, "profile", "baseline", 0);
    }
    /* open it */
    int ret = avcodec_open2(pCodecCtx, pCodec, NULL);
    if (ret < 0) {
        fprintf(stderr, "Could not open codec: %s\n", av_err2str(ret));
        exit(1);
    }

    f = fopen(filename, "wb");
    if (!f) {
        fprintf(stderr, "Could not open %s\n", filename);
        exit(1);
    }

    pFrame = av_frame_alloc();
    if (!pFrame) {
        fprintf(stderr, "Could not allocate video frame\n");
        exit(1);
    }
    pFrame->format = pCodecCtx->pix_fmt;
    pFrame->width  = pCodecCtx->width;
    pFrame->height = pCodecCtx->height;

    ret = av_frame_get_buffer(pFrame, 0);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate the video frame data\n");
        exit(1);
    }
    
    // 17.h264 封装格式的文件头部，基本上每种编码都有着自己的格式的头部。
//        if (avformat_write_header(pFormatCtx, NULL) < 0) { printf("Failed to write! \n"); return; }
}


- (void)encoding:(CVPixelBufferRef)pixelBuffer timestamp:(CGFloat)timestamp {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    fflush(stdout);

            /* Make sure the frame data is writable.
               On the first round, the frame is fresh from av_frame_get_buffer()
               and therefore we know it is writable.
               But on the next rounds, encode() will have called
               avcodec_send_frame(), and the codec may have kept a reference to
               the frame in its internal structures, that makes the frame
               unwritable.
               av_frame_make_writable() checks that and allocates a new buffer
               for the frame only if necessary.
             */
            int ret = av_frame_make_writable(pFrame);
            if (ret < 0)
                exit(1);

    // prepare a dummy image
    // Y
    pFrame->data[0] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    pFrame->data[1] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);       // U
    pFrame->data[2] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2);  // V

//    pFrame->pts = frameCounter;
    
    if(pkt->pts==AV_NOPTS_VALUE) {
        //Write PTS
        AVRational time_base1=pCodecCtx->time_base;
        //Duration between 2 frames (us)
        int64_t calc_duration=(double)AV_TIME_BASE/av_q2d(pCodecCtx->framerate);
        //Parameters
        pkt->pts=(double)(frameCounter*calc_duration)/(double)(av_q2d(time_base1)*AV_TIME_BASE);
        pkt->dts=pkt->pts;
        pkt->duration=(double)calc_duration/(double)(av_q2d(time_base1)*AV_TIME_BASE);
        frameCounter++;
    }

    encode(pCodecCtx, pFrame, pkt, f, frameCounter);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

static void encode(AVCodecContext *enc_ctx, AVFrame *frame, AVPacket *pkt,
                   FILE *outfile, int ppcount)
{
    int ret;

    /* send the frame to the encoder */
//    if (frame)
//        printf("Send frame %3"PRId64"\n", frame->pts);

    ret = avcodec_send_frame(enc_ctx, frame);
    if (ret < 0) {
        fprintf(stderr, "Error sending a frame for encoding\n");
        exit(1);
    }

    while (avcodec_receive_packet(enc_ctx, pkt) == 0) {
        pkt->stream_index = 0;
//        printf("Write packet %3"PRId64" (size=%5d)\n", pkt->pts, pkt->size);
        fwrite(pkt->data, 1, pkt->size, outfile);
        av_packet_unref(pkt);
    }
}

- (void)teardown {
    avcodec_close(pCodecCtx);
    av_free(pFrame);
    pCodecCtx = NULL;
    pFrame = NULL;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *fileName = @"bitrate.h264";
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    
    NSString *audioPath = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Video"] stringByAppendingPathComponent:@"audioMix.pcm"];
    
    
    NSString *finalPath = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Video"] stringByAppendingPathComponent:@"final.mp4"];
    
//    [FFMpegTool replaceAudio:audioPath videoFile:writablePath];
    
    if ( [PHAssetCreationRequest class] ) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypeVideo fileURL:[NSURL fileURLWithPath:finalPath] options:nil];
        } completionHandler:^( BOOL success, NSError *error ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error) {
                    [self saveSuccess];
                }
            });
        }];
    }
    else {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:finalPath]];
        } completionHandler:^( BOOL success, NSError *error ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error) {
                    [self saveSuccess];
                }
                 
            });
        }];
    }
}

- (void)saveSuccess {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.label.text = @"成功保存视频到相册";
    [hud hideAnimated:YES afterDelay:3];
}

- (instancetype)initWithOutputURL:(NSURL *)outputURL
                            width:(int)width
                           height:(int)height
                              fps:(int)fps {
    if (self = [super init]) {
        _outputURL = outputURL;
        _width = width;
        _height = height;
        _fps = fps;
        frame_count = 0;
        
        if (![self setupFFmpegEncoder]) {
            return nil;
        }
    }
    return self;
}

- (BOOL)setupFFmpegEncoder {
    // 1. 初始化FFmpeg
    avformat_network_init();
    
    // 2. 创建输出上下文 (MP4容器)
    avformat_alloc_output_context2(&fmt_ctx, NULL, "mp4", _outputURL.path.UTF8String);
    if (!fmt_ctx) {
        NSLog(@"Failed to create output context");
        return NO;
    }
    
    // 3. 查找硬件编码器 (NVENC)
    const AVCodec *codec = avcodec_find_encoder_by_name("h264_nvenc");
    if (!codec) {
        NSLog(@"NVENC encoder not found");
        return NO;
    }
    
    // 4. 创建编码器上下文
    codec_ctx = avcodec_alloc_context3(codec);
    codec_ctx->width = 720;
    codec_ctx->height = 720;
    codec_ctx->time_base = (AVRational){1, 600};
    codec_ctx->framerate = (AVRational){30, 1};
    codec_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    codec_ctx->gop_size = 60; // GOP大小
    codec_ctx->max_b_frames = 0; // B帧数
    codec_ctx->bit_rate = 4000000; // 4Mbps
    
    // 5. 创建CUDA硬件设备上下文
    AVBufferRef *hw_device_ctx = NULL;
    int ret = av_hwdevice_ctx_create(&hw_device_ctx, AV_HWDEVICE_TYPE_VIDEOTOOLBOX, NULL, NULL, 0);
    if (ret < 0) {
        NSLog(@"Failed to create CUDA device context: %s", av_err2str(ret));
        return NO;
    }
    codec_ctx->hw_device_ctx = av_buffer_ref(hw_device_ctx);
    
    // 6. 打开编码器
    ret = avcodec_open2(codec_ctx, codec, NULL);
    if (ret < 0) {
        NSLog(@"Failed to open codec: %s", av_err2str(ret));
        return NO;
    }
    
    // 7. 创建视频流
    video_stream = avformat_new_stream(fmt_ctx, codec);
    video_stream->time_base = codec_ctx->time_base;
    avcodec_parameters_from_context(video_stream->codecpar, codec_ctx);
    
    // 8. 打开输出文件
    ret = avio_open(&fmt_ctx->pb, _outputURL.path.UTF8String, AVIO_FLAG_WRITE);
    if (ret < 0) {
        NSLog(@"Failed to open output file: %s", av_err2str(ret));
        return NO;
    }
    
    // 9. 写入文件头
    ret = avformat_write_header(fmt_ctx, NULL);
    if (ret < 0) {
        NSLog(@"Failed to write header: %s", av_err2str(ret));
        return NO;
    }
    
    return YES;
}

- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer {
    // 1. 创建硬件帧
    AVFrame *frame = av_frame_alloc();
    frame->width = _width;
    frame->height = _height;
    frame->format = AV_PIX_FMT_CUDA;
    
    // 2. 从CVPixelBuffer创建CUDA帧
    CVReturn ret = CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (ret != kCVReturnSuccess) {
        NSLog(@"Failed to lock pixel buffer");
        return;
    }
    
    // 3. 创建CUDA帧（实际实现需要更复杂的CUDA内存映射）
    // 这里简化处理：实际应用中应使用CUDA图形API直接映射OpenGL纹理
    av_hwframe_get_buffer(codec_ctx->hw_frames_ctx, frame, 0);
    
    // 4. 设置帧属性
    frame->pts = av_rescale_q(frame_count, codec_ctx->time_base, video_stream->time_base);
    frame_count++;
    
    // 5. 发送帧到编码器
    int send_ret = avcodec_send_frame(codec_ctx, frame);
    if (send_ret < 0) {
        NSLog(@"Error sending frame: %s", av_err2str(send_ret));
    }
    
    // 6. 接收编码后的包
    AVPacket *pkt = av_packet_alloc();
    while (avcodec_receive_packet(codec_ctx, pkt) == 0) {
        pkt->stream_index = video_stream->index;
        av_packet_rescale_ts(pkt, codec_ctx->time_base, video_stream->time_base);
        av_interleaved_write_frame(fmt_ctx, pkt);
        av_packet_unref(pkt);
    }
    
    // 7. 清理
    av_frame_free(&frame);
    av_packet_free(&pkt);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

- (void)finishEncoding {
    // 发送空帧冲刷编码器
    avcodec_send_frame(codec_ctx, NULL);
    
    AVPacket *pkt = av_packet_alloc();
    while (avcodec_receive_packet(codec_ctx, pkt) == 0) {
        pkt->stream_index = video_stream->index;
        av_packet_rescale_ts(pkt, codec_ctx->time_base, video_stream->time_base);
        av_interleaved_write_frame(fmt_ctx, pkt);
        av_packet_unref(pkt);
    }
    
    // 写入文件尾
    av_write_trailer(fmt_ctx);
    
    // 释放资源
    avcodec_free_context(&codec_ctx);
    avio_closep(&fmt_ctx->pb);
    avformat_free_context(fmt_ctx);
}


@end
