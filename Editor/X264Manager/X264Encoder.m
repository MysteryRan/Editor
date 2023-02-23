//
//  X264Encoder.m
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 2017/10/1.
//  Copyright © 2017年 suntongmian@163.com. All rights reserved.
//

#import "X264Encoder.h"
#import "WriteH264Streaming.h"

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

@interface X264Encoder ()

@property (strong, nonatomic) VideoConfiguration *videoConfiguration;

@end

@implementation X264Encoder
{
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
}

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


- (instancetype)initWithVideoConfiguration:(VideoConfiguration *)videoConfiguration {
    self = [super init];
    if (self) {
        self.videoConfiguration = videoConfiguration;
        //        [self setupEncoder];
        [self lcinit];
    }
    return self;
}

- (void)setupEncoder {
    avcodec_register_all(); // 注册FFmpeg所有编解码器
    
    frameCounter = 0;
    frameWidth = self.videoConfiguration.videoSize.width;
    frameHeight = self.videoConfiguration.videoSize.height;
    // Param that must set
    pCodecCtx = avcodec_alloc_context3(pCodec);
    pCodecCtx->codec_id = AV_CODEC_ID_H264;
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    pCodecCtx->width = frameWidth;
    pCodecCtx->height = frameHeight;
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = self.videoConfiguration.frameRate;
    pCodecCtx->bit_rate = self.videoConfiguration.bitrate;
    pCodecCtx->gop_size = self.videoConfiguration.maxKeyframeInterval;
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
    //    pCodecCtx->me_range = 16;
    //    pCodecCtx->max_qdiff = 4;
    //    pCodecCtx->qcompress = 0.6;
    // Optional Param
    //    pCodecCtx->max_b_frames = 3;
    
    // Set Option
    AVDictionary *param = NULL;
    if(pCodecCtx->codec_id == AV_CODEC_ID_H264) {
        av_dict_set(&param, "preset", "slow", 0);
        av_dict_set(&param, "tune", "zerolatency", 0);
        //        av_dict_set(&param, "profile", "main", 0);
    }
    
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec) {
        NSLog(@"Can not find encoder!");
    }
    
    if (avcodec_open2(pCodecCtx, pCodec, &param) < 0) {
        NSLog(@"Failed to open encoder!");
    }
    
    pFrame = av_frame_alloc();
    pFrame->width = frameWidth;
    pFrame->height = frameHeight;
    pFrame->format = AV_PIX_FMT_YUV420P;
    
    avpicture_fill((AVPicture *)pFrame, NULL, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    
    pictureSize = avpicture_get_size(pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    av_new_packet(&packet, pictureSize);
}

//- (void)encoding:(CVPixelBufferRef)pixelBuffer timestamp:(CGFloat)timestamp {
//    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
//
//    int planes = CVPixelBufferGetPlaneCount(pixelBuffer);
//    for (int i = 0; i < planes; i++) {
//        pFrame->data[i] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i);
//        pFrame->linesize[i] = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i);
//    }
//
//    pFrame->pts = frameCounter;
//
//    // Encode
//    int got_picture = 0;
//    if (!pCodecCtx) {
//        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
//        return;
//    }
//    int ret = avcodec_encode_video2(pCodecCtx, &packet, pFrame, &got_picture);
//    if(ret < 0) {
//        NSLog(@"Failed to encode!");
//    }
//    if (got_picture == 1) {
//        NSLog(@"-------->");
//        NSLog(@"Succeed to encode frame: %5d\tsize:%5d", frameCounter, packet.size);
//        frameCounter++;
//
//        WriteH264Streaming *writeH264Streaming = self.outputObject;
//        [writeH264Streaming writeFrame:packet streamIndex:packet.stream_index];
//
//        av_free_packet(&packet);
//    }
//
//    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
//
//}

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

    /* put sample parameters */
    pCodecCtx->bit_rate = 17300 * 1000;
    /* resolution must be a multiple of two */
    pCodecCtx->width = 1920;
    pCodecCtx->height = 1080;
    /* frames per second */
    pCodecCtx->time_base = (AVRational){1, 25};
    pCodecCtx->framerate = (AVRational){25, 1};

    /* emit one intra frame every ten frames
     * check frame pict_type before passing frame
     * to encoder, if frame->pict_type is AV_PICTURE_TYPE_I
     * then gop_size is ignored and the output of encoder
     * will always be I frame irrespective to gop_size
     */
    pCodecCtx->gop_size = 30;
    pCodecCtx->max_b_frames = 5;
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
    pFrame->data[0] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);                                // Y
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
    if (frame)
        printf("Send frame %3"PRId64"\n", frame->pts);

    ret = avcodec_send_frame(enc_ctx, frame);
    if (ret < 0) {
        fprintf(stderr, "Error sending a frame for encoding\n");
        exit(1);
    }

    while (avcodec_receive_packet(enc_ctx, pkt) == 0) {
        pkt->stream_index = 0;
        printf("Write packet %3"PRId64" (size=%5d)\n", pkt->pts, pkt->size);
        fwrite(pkt->data, 1, pkt->size, outfile);
        av_packet_unref(pkt);
    }
}


- (void)originencoding:(CVPixelBufferRef)pixelBuffer timestamp:(CGFloat)timestamp {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    int pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    switch (pixelFormat) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            NSLog(@"pixel format NV12");
            break;
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            NSLog(@"pixel format NV12");
            break;
        case kCVPixelFormatType_32BGRA:
            NSLog(@"pixel format 32BGRA");
            break;
        default:
//            NSLog(@"pixel format unknown");
            break;
    }

    BOOL plane = CVPixelBufferIsPlanar(pixelBuffer);

//    UInt8 *pY = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
//    UInt8 *pUV = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
//    size_t width = CVPixelBufferGetWidth(pixelBuffer);
//    size_t height = CVPixelBufferGetHeight(pixelBuffer);
//    size_t pYBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
//    size_t pUVBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
//
//    UInt8 *pYUV420P = (UInt8 *)malloc(width * height * 3 / 2); // buffer to store YUV with layout YYYYYYYYUUVV
//
//    /* convert NV12 data to YUV420*/
//    UInt8 *pU = pYUV420P + (width * height);
//    UInt8 *pV = pU + (width * height / 4);
//    for(int i = 0; i < height; i++) {
//        memcpy(pYUV420P + i * width, pY + i * pYBytes, width);
//    }
//    for(int j = 0; j < height / 2; j++) {
//        for(int i = 0; i < width / 2; i++) {
//            *(pU++) = pUV[i<<1];
//            *(pV++) = pUV[(i<<1) + 1];
//        }
//        pUV += pUVBytes;
//    }

    // add code to push pYUV420P to video encoder here

    // scale
    // add code to scale image here
    // ...

    //Read raw YUV data
    pFrame->data[0] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);                                // Y
    pFrame->data[1] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);       // U
    pFrame->data[2] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2);  // V
    // PTS
    pFrame->pts = frameCounter;
    // Encode
    int got_picture = 0;
    if (!pCodecCtx) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return;
    }
//    int ret = avcodec_encode_video2(pCodecCtx, &packet, pFrame, &got_picture);

    int ret = avcodec_send_frame(pCodecCtx, pFrame);
    if (ret != 0){
        NSLog( @"error send_frame");
    }
    ret = avcodec_receive_packet(pCodecCtx, &packet);

    if(ret < 0) {
        NSLog(@"Failed to encode!");
    }
    if (got_picture == 1) {
        NSLog(@"-------->");
        NSLog(@"Succeed to encode frame: %5d\tsize:%5d", frameCounter, packet.size);
        frameCounter++;

        WriteH264Streaming *writeH264Streaming = self.outputObject;
        [writeH264Streaming writeFrame:packet streamIndex:packet.stream_index];

        av_free_packet(&packet);
    }

//    free(pYUV420P);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)teardown {
    WriteH264Streaming *writeH264Streaming = self.outputObject;
    writeH264Streaming = nil;
    
    avcodec_close(pCodecCtx);
    av_free(pFrame);
    pCodecCtx = NULL;
    pFrame = NULL;
}

#pragma mark -- H264OutputProtocol
- (void)setOutput:(id<H264OutputProtocol>)output {
    self.outputObject = output;
}

- (void)dealloc {
    
}

@end
