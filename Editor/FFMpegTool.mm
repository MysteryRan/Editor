//
//  FFMpegTool.m
//  ffmpegDemo
//
//  Created by zouran on 2022/11/25.
//

#import "FFMpegTool.h"

#define STREAM_DURATION   10.0
#define STREAM_FRAME_RATE 25 /* 25 images/s */
#define STREAM_PIX_FMT    AV_PIX_FMT_YUV420P /* default pix_fmt */

#define SCALE_FLAGS SWS_BICUBIC

typedef struct AudioConfig {
    //采样的格式
    AVSampleFormat format = AV_SAMPLE_FMT_NONE;
    //采样率
    int sample_rate = 0;
    //声道的布局
    uint64_t ch_layout = AV_CH_LAYOUT_STEREO;
    //时间基
    AVRational timebase = { 1, 1 };
    AudioConfig(AVSampleFormat format, int sample_rate, uint64_t ch_layout, AVRational timebase)
    {
        this->format = format;
        this->sample_rate = sample_rate;
        this->ch_layout = ch_layout;
        this->timebase = timebase;
    }

} AudioConfig;

typedef struct OutputStream {
    AVStream *st;
    AVCodecContext *enc;

    /* pts of the next frame that will be generated */
    int64_t next_pts;
    int samples_count;

    AVFrame *frame;
    AVFrame *tmp_frame;

    AVPacket *tmp_pkt;

    float t, tincr, tincr2;

    struct SwsContext *sws_ctx;
    struct SwrContext *swr_ctx;
} OutputStream;

@interface FFMpegTool() {
    
    //输出槽
        AVFilterContext *buffersink_ctx ;
        //输入缓存1
        AVFilterContext *buffersrc1_ctx ;
        //输入缓存2
        AVFilterContext *buffersrc2_ctx ;
        //滤镜图
        AVFilterGraph *filter_graph;
        //滤镜描述
        const char *description;
    
    
    int videoIndex;
    bool isMp4;
    AVFormatContext *ifmt_ctx, *ofmt_ctx;
    AVPacket pkt;
    NSString *in_filename, *out_filename;
    AVCodecContext *encCtx;
    
}

@end

@implementation FFMpegTool

- (BOOL)writeHeader {
    AVOutputFormat *ofmt = NULL;
    AVStream *out_stream;
    AVCodec *encoder;
    int ret;
    ofmt = ofmt_ctx->oformat;
    for (int i = 0; i < ifmt_ctx->nb_streams; i++) {
        AVStream *in_stream = ifmt_ctx->streams[i];
        if (in_stream->codec->codec_type == AVMEDIA_TYPE_VIDEO)
        {
            videoIndex = i;
            AVCodec *pCodec = avcodec_find_encoder(in_stream->codec->codec_id);
            out_stream = avformat_new_stream(ofmt_ctx, pCodec);
            if (!out_stream) {
                printf("Failed allocating output stream\n");
                ret = AVERROR_UNKNOWN;
                return false;
            }
            encCtx = out_stream->codec;
            encCtx->codec_id = in_stream->codec->codec_id;
            encCtx->codec_type = in_stream->codec->codec_type;
            encCtx->pix_fmt = in_stream->codec->pix_fmt;
            encCtx->width = in_stream->codec->width;
            encCtx->height = in_stream->codec->height;
            encCtx->flags = in_stream->codec->flags;
            encCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
            av_opt_set(encCtx->priv_data, "tune", "zerolatency", 0);
            ofmt_ctx->streams[i]->avg_frame_rate = in_stream->avg_frame_rate;
            if (in_stream->codec->time_base.den > 25)
            {
                encCtx->time_base = { 1, 25 };
                encCtx->pkt_timebase = { 1, 25 };
            }
            else{
                AVRational tmp = in_stream->avg_frame_rate;
                
                //encCtx->time_base = in_stream->codec->time_base;
                //encCtx->pkt_timebase = in_stream->codec->pkt_timebase;
                encCtx->time_base = { tmp.den, tmp.num };
            }
            AVDictionary *param=0;
            if (encCtx->codec_id == AV_CODEC_ID_H264) {
                av_opt_set(&param, "preset", "slow", 0);
                //av_dict_set(&param, "profile", "main", 0);
            }
            //没有这句，导致得到的视频没有缩略图等信息
            ret = avcodec_open2(encCtx, pCodec, &param);
        }
        
    }
    /*
     //encCtx->extradata = new uint8_t[32];//给extradata成员参数分配内存
     //encCtx->extradata_size = 32;//extradata成员参数分配内存大小
     ////给extradata成员参数设置值
     ////00 00 00 01
     //encCtx->extradata[0] = 0x00;
     //encCtx->extradata[1] = 0x00;
     //encCtx->extradata[2] = 0x00;
     //encCtx->extradata[3] = 0x01;
     ////67 42 80 1e
     //encCtx->extradata[4] = 0x67;
     //encCtx->extradata[5] = 0x42;
     //encCtx->extradata[6] = 0x80;
     //encCtx->extradata[7] = 0x1e;
     ////88 8b 40 50
     //encCtx->extradata[8] = 0x88;
     //encCtx->extradata[9] = 0x8b;
     //encCtx->extradata[10] = 0x40;
     //encCtx->extradata[11] = 0x50;
     ////1e d0 80 00
     //encCtx->extradata[12] = 0x1e;
     //encCtx->extradata[13] = 0xd0;
     //encCtx->extradata[14] = 0x80;
     //encCtx->extradata[15] = 0x00;
     ////03 84 00 00
     //encCtx->extradata[16] = 0x03;
     //encCtx->extradata[17] = 0x84;
     //encCtx->extradata[18] = 0x00;
     //encCtx->extradata[19] = 0x00;
     ////af c8 02 00
     //encCtx->extradata[20] = 0xaf;
     //encCtx->extradata[21] = 0xc8;
     //encCtx->extradata[22] = 0x02;
     //encCtx->extradata[23] = 0x00;
     ////00 00 00 01
     //encCtx->extradata[24] = 0x00;
     //encCtx->extradata[25] = 0x00;
     //encCtx->extradata[26] = 0x00;
     //encCtx->extradata[27] = 0x01;
     ////68 ce 38 80
     //encCtx->extradata[28] = 0x68;
     //encCtx->extradata[29] = 0xce;
     //encCtx->extradata[30] = 0x38;
     //encCtx->extradata[31] = 0x80;*/
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&ofmt_ctx->pb, [out_filename UTF8String], AVIO_FLAG_WRITE);
        if (ret < 0) {
            return false;
        }
    }
    /*
     out_stream->codec->codec_tag = 0;
     if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
     out_stream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
     */
    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0){
        return false;
    }
    return true;
}

- (int)otherexport:(NSString *)rrin_filename oo:(NSString *)rrout_filename {

    in_filename = rrin_filename;
    out_filename = rrout_filename;
    
    AVPacket readPkt;
        int ret;
        if ((ret = avformat_open_input(&ifmt_ctx, [in_filename UTF8String], 0, 0)) < 0) {
            return false;
        }

        if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
            return false;
        }
    /*
        string::size_type pos = out_filename.find_last_of(".");
        if (pos == string::npos)
            out_filename.append(".mp4");
     */
        avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, [out_filename UTF8String]);
        if (![self writeHeader])
            return false;
        int frame_index = 0;
        AVBitStreamFilterContext* h264bsfc = av_bitstream_filter_init("h264_mp4toannexb");
        int startFlag = 1;
        int64_t pts_start_time = 0;
        int64_t dts_start_time = 0;
        int64_t pre_pts = 0;
        int64_t pre_dts = 0;
        while (1)
        {
            
            ret = av_read_frame(ifmt_ctx, &readPkt);
            if (ret < 0)
            {
                break;
            }
            if (readPkt.stream_index == videoIndex)
            {
                ++frame_index;
                //过滤掉前面的非I帧
                if (frame_index == startFlag&&readPkt.flags != AV_PKT_FLAG_KEY){
                    ++startFlag;
                    continue;
                }
                if (frame_index == startFlag){
                    pts_start_time = readPkt.pts>0? readPkt.pts:0;
                    dts_start_time = readPkt.dts>0? readPkt.dts:0;
                    pre_dts = dts_start_time;
                    pre_pts = pts_start_time;
                }

                //过滤得到h264数据包
                isMp4 = YES;
                if (isMp4)
                    av_bitstream_filter_filter(h264bsfc, ifmt_ctx->streams[videoIndex]->codec, NULL, &readPkt.data, &readPkt.size, readPkt.data, readPkt.size, 0);

                if (readPkt.pts != AV_NOPTS_VALUE){
                    readPkt.pts = readPkt.pts - pts_start_time;
                }
                if (readPkt.dts != AV_NOPTS_VALUE){
                    if (readPkt.dts <= pre_dts&&frame_index != startFlag){
                        //保证 dts 单调递增
                        int64_t delta = av_rescale_q(1, ofmt_ctx->streams[0]->time_base, ifmt_ctx->streams[videoIndex]->time_base);
                        readPkt.dts = pre_dts + delta + 1;
                    }
                    else{
                        //initDts(&readPkt.dts, dts_start_time);
                        readPkt.dts = readPkt.dts - dts_start_time;
                    }
                }
                pre_dts = readPkt.dts;
                pre_pts = readPkt.pts;
                
                av_packet_rescale_ts(&readPkt, ifmt_ctx->streams[videoIndex]->time_base, ofmt_ctx->streams[0]->time_base);
                if (readPkt.duration < 0)
                {
                    readPkt.duration = 0;
                }
                if (readPkt.pts < readPkt.dts)
                {
                    readPkt.pts = readPkt.dts + 1;
                }
                readPkt.stream_index = 0;
                //这里如果使用av_interleaved_write_frame 会导致有时候写的视频文件没有数据。
                ret =av_write_frame(ofmt_ctx, &readPkt);
                if (ret < 0) {
                    //break;
                   NSLog(@"write failed");
                }
            }
            
            av_packet_unref(&readPkt);

        }
        av_bitstream_filter_close(h264bsfc);
        av_packet_unref(&readPkt);
        av_write_trailer(ofmt_ctx);
        return true;
}

+ (int)hevcexport:(const char *)in_filename toPath:(const char *)out_filename {
    AVOutputFormat *ofmt = NULL;
        AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
        AVPacket pkt;
        int ret, i;
        int stream_index = 0;
        int *stream_mapping = NULL;
        int stream_mapping_size = 0;
        int64_t *in_last_dts = NULL;
        int64_t *out_last_dts = NULL;
        AVDictionary *options = NULL;

        avformat_network_init();
        av_log_set_level(AV_LOG_WARNING);

        

        if ((ret = avformat_open_input(&ifmt_ctx, in_filename, 0, &options)) < 0) {
            fprintf(stderr, "Could not open input file '%s'\n", in_filename);
            goto end;
        }

        if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
            fprintf(stderr, "Failed to retrieve input stream information\n");
            goto end;
        }

        av_dump_format(ifmt_ctx, 0, in_filename, 0);

        avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);
        if (!ofmt_ctx) {
            fprintf(stderr, "Could not create output context\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }

        stream_mapping_size = ifmt_ctx->nb_streams;
        stream_mapping = (int *)av_mallocz_array(stream_mapping_size, sizeof(*stream_mapping));
        if (!stream_mapping) {
            ret = AVERROR(ENOMEM);
            goto end;
        }

        in_last_dts = (int64_t *)av_mallocz_array(stream_mapping_size, sizeof(int64_t));
        if (!in_last_dts) {
            ret = AVERROR(ENOMEM);
            goto end;
        }

        out_last_dts = (int64_t *)av_mallocz_array(stream_mapping_size, sizeof(int64_t));
        if (!out_last_dts) {
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

            if (out_stream->codecpar->codec_id == AV_CODEC_ID_HEVC) {
                out_stream->codecpar->codec_tag = MKTAG('h', 'v', 'c', '1');
            } else {
                out_stream->codecpar->codec_tag = 0;
            }

            in_last_dts[i] = AV_NOPTS_VALUE;
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

//        (void)signal(SIGUSR1, handle_stop);

        while (1) {
            AVStream *in_stream, *out_stream;

            ret = av_read_frame(ifmt_ctx, &pkt);
            if (ret < 0)
                break;

            in_stream = ifmt_ctx->streams[pkt.stream_index];
            if (pkt.stream_index >= stream_mapping_size ||
                stream_mapping[pkt.stream_index] < 0) {
                av_packet_unref(&pkt);
                continue;
            }

            pkt.stream_index = stream_mapping[pkt.stream_index];
            out_stream = ofmt_ctx->streams[pkt.stream_index];

            /* rescale DTS to be monotonic increasing */
            int64_t dts;
            do {
                if (in_last_dts[pkt.stream_index] == AV_NOPTS_VALUE) {
                    dts = 0;
                    break;
                }

                if (pkt.dts > in_last_dts[pkt.stream_index]) {
                    if (pkt.dts > in_last_dts[pkt.stream_index] + 1000) {
                        dts = out_last_dts[pkt.stream_index] + 10;
                    } else {
                        dts = pkt.dts - in_last_dts[pkt.stream_index] + out_last_dts[pkt.stream_index];
                    }
                } else {
                    dts = out_last_dts[pkt.stream_index] + 10;
                }
            } while (0);
            in_last_dts[pkt.stream_index] = pkt.dts;
            out_last_dts[pkt.stream_index] = dts;

            /* shift pts */
            int64_t cts = pkt.pts - pkt.dts;
            pkt.dts = dts;
            pkt.pts = dts + cts;

            /* copy packet */
            pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF);
            pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF);
            pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
            pkt.pos = -1;

            av_interleaved_write_frame(ofmt_ctx, &pkt);
            av_packet_unref(&pkt);
        }

        av_write_trailer(ofmt_ctx);
    end:

        avformat_close_input(&ifmt_ctx);

        /* close output */
        if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
            avio_closep(&ofmt_ctx->pb);
        avformat_free_context(ofmt_ctx);

        av_dict_free(&options);
        av_freep(&stream_mapping);
        av_freep(&in_last_dts);
        av_freep(&out_last_dts);

        if (ret < 0 && ret != AVERROR_EOF) {
            return ret;
        }

        return 0;
}

+ (int)exportAblumPhoto:(const char *)fromPath toPath:(const char *)path {
    AVOutputFormat *ofmt = NULL;
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    AVPacket pkt;
    const char *in_filename, *out_filename;
    int ret, i;
    int stream_index = 0;
    int *stream_mapping = NULL;
    int stream_mapping_size = 0;

    // if (argc < 3) {
    //     printf("usage: %s input output\n"
    //            "API example program to remux a media file with libavformat and libavcodec.\n"
    //            "The output format is guessed according to the file extension.\n"
    //            "\n", argv[0]);
    //     return 1;
    // }

//    fromPath  = [[[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"] UTF8String];
    out_filename = path;

    // av_register_all();

    if ((ret = avformat_open_input(&ifmt_ctx, fromPath, 0, 0)) < 0) {
        fprintf(stderr, "Could not open input file '%s'", in_filename);
        goto end;
    }

    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
        fprintf(stderr, "Failed to retrieve input stream information");
        goto end;
    }

    av_dump_format(ifmt_ctx, 0, in_filename, 0);

    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, path);
    if (!ofmt_ctx) {
        fprintf(stderr, "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }

    stream_mapping_size = ifmt_ctx->nb_streams;
    stream_mapping = (int *)av_mallocz_array(stream_mapping_size, sizeof(*stream_mapping));
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
        pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF);
        pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF);
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

+ (NSString *)createvideo_file_url:(NSString *)file {
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

- (NSString *)createvideofileurl:(NSString *)file {
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

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt, const char *tag)
{
    AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;

    printf("%s: pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s stream_index:%d\n",
           tag,
           av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
           av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
           av_ts2str(pkt->duration), av_ts2timestr(pkt->duration, time_base),
           pkt->stream_index);
}

+ (MediaInfo *)openStreamFunc:(NSString *)path {
    
    MediaInfo *info = [[MediaInfo alloc] init];
    
    NSParameterAssert(path);
    if (![path hasPrefix:@"/"]) {
        
    }
    
    AVFormatContext *formatCtx = NULL;
    /*
     打开输入流，读取文件头信息，不会打开解码器；
     */
    //低版本是 av_open_input_file 方法
    const char *moviePath = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    //打开文件流，读取头信息；
    if (0 != avformat_open_input(&formatCtx, moviePath , NULL, NULL)) {
        //关闭，释放内存，置空
        avformat_close_input(&formatCtx);
    } else {
        /* 刚才只是打开了文件，检测了下文件头而已，并不知道流信息；因此开始读包以获取流信息
         设置读包探测大小和最大时长，避免读太多的包！
         */
        formatCtx->probesize = 500 * 1024;
        formatCtx->max_analyze_duration = 5 * AV_TIME_BASE;
#if DEBUG

#endif
        if (0 != avformat_find_stream_info(formatCtx, NULL)) {
            avformat_close_input(&formatCtx);
        } else {
#if DEBUG
            //用于查看详细信息，调试的时候打出来看下很有必要
            av_dump_format(formatCtx, 0, moviePath, false);
#endif
            /* 接下来，尝试找到我们关心的信息*/
            NSMutableString *text = [[NSMutableString alloc]init];
            
            /*AVFormatContext 的 streams 变量是个数组，里面存放了 nb_streams 个元素，每个元素都是一个 AVStream */
            [text appendFormat:@"共 %u 个流，总时长: %lld 秒",formatCtx->nb_streams,formatCtx->duration/AV_TIME_BASE];
            //遍历所有的流
            for (int i = 0; i < formatCtx->nb_streams; i++) {
                
                AVStream *stream = formatCtx->streams[i];
                
                AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
                if (!codecCtx) {
                    continue;
                }
                
                int ret = avcodec_parameters_to_context(codecCtx, stream->codecpar);
                if (ret < 0) {
                    avcodec_free_context(&codecCtx);
                    continue;
                }
                
                //AVCodecContext *codec = stream->codec;
                enum FFMAVMediaType codec_type = codecCtx->codec_type;
                switch (codec_type) {
                        //音频流
                    case AVMEDIA_TYPE_AUDIO:
                    {
                        //采样率
                        int sample_rate = codecCtx->sample_rate;
                        //声道数
                        int channels = codecCtx->channels;
                        //平均比特率
                        int64_t brate = codecCtx->bit_rate;
                        //时长
                        int duration = stream->duration * av_q2d(stream->time_base);
                        //解码器id
                        enum AVCodecID codecID = codecCtx->codec_id;
                        //根据解码器id找到对应名称
                        const char *codecDesc = avcodec_get_name(codecID);
                        //音频采样格式
                        enum AVSampleFormat format = codecCtx->sample_fmt;
                        //获取音频采样格式名称
                        const char * formatDesc = av_get_sample_fmt_name(format);
                        
//                        [text appendFormat:@"\n\nAudio Stream：\n%d/%d；%d Kbps，%.1f KHz， %d channels，%s，%s，duration:%ds",stream->time_base.num,stream->time_base.den,(int)(brate/1000.0),sample_rate/1000.0,channels,codecDesc,formatDesc,duration];
                    }
                        break;
                        //视频流
                    case AVMEDIA_TYPE_VIDEO:
                    {
                        //画面宽度，单位像素
                        int vwidth = codecCtx->width;
                        //画面高度，单位像素
                        int vheight = codecCtx->height;
                        //比特率
                        int64_t brate = codecCtx->bit_rate;
                        //解码器id
                        enum AVCodecID codecID = codecCtx->codec_id;
                        //根据解码器id找到对应名称
                        const char *codecDesc = avcodec_get_name(codecID);
                        //视频像素格式
                        enum AVPixelFormat format = codecCtx->pix_fmt;
                        //获取视频像素格式名称
                        const char * formatDesc = av_get_pix_fmt_name(format);
                        //帧率
                        CGFloat fps, timebase = 0.04;
                        if (stream->time_base.den && stream->time_base.num) {
                            timebase = av_q2d(stream->time_base);
                        }
                        
                        if (stream->avg_frame_rate.den && stream->avg_frame_rate.num) {
                            fps = av_q2d(stream->avg_frame_rate);
                        }else if (stream->r_frame_rate.den && stream->r_frame_rate.num){
                            fps = av_q2d(stream->r_frame_rate);
                        }else{
                            fps = 1.0 / timebase;
                        }
                        //时长
                        double duration = stream->duration * av_q2d(stream->time_base);
                        int64_t nvDuration = duration * AV_TIME_BASE;
//                        [text appendFormat:@"\n\nVideo Stream：\n%d/%d；%dKbps，%d*%d，%dfps， %s， %s，duration:%ds",stream->time_base.num,stream->time_base.den,(int)(brate/1024.0),vwidth,vheight,(int)fps,codecDesc,formatDesc,duration];
                        
                        info.width = vwidth;
                        info.height = vheight;
                        info.duration = nvDuration;
                    }
                        break;
                    case AVMEDIA_TYPE_ATTACHMENT:
                    {
                    }
                        break;
                    default:
                    {
                    }
                        break;
                }
                avcodec_free_context(&codecCtx);
            }
            //关闭流
            avformat_close_input(&formatCtx);
        }
    }
    
    return info;
}

+ (void)copytest {
    ffcopymain();
}


static int write_frame(AVFormatContext *fmt_ctx, AVCodecContext *c,
                       AVStream *st, AVFrame *frame, AVPacket *pkt)
{
    int ret;

    // send the frame to the encoder
    ret = avcodec_send_frame(c, frame);
    if (ret < 0) {
        fprintf(stderr, "Error sending a frame to the encoder: %s\n",
                av_err2str(ret));
        exit(1);
    }

    while (ret >= 0) {
        ret = avcodec_receive_packet(c, pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
            break;
        else if (ret < 0) {
            fprintf(stderr, "Error encoding a frame: %s\n", av_err2str(ret));
            exit(1);
        }

        /* rescale output packet timestamp values from codec to stream timebase */
        av_packet_rescale_ts(pkt, c->time_base, st->time_base);
        pkt->stream_index = st->index;

        /* Write the compressed frame to the media file. */
//        log_packet(fmt_ctx, pkt);
        ret = av_interleaved_write_frame(fmt_ctx, pkt);
        /* pkt is now blank (av_interleaved_write_frame() takes ownership of
         * its contents and resets pkt), so that no unreferencing is necessary.
         * This would be different if one used av_write_frame(). */
        if (ret < 0) {
            fprintf(stderr, "Error while writing output packet: %s\n", av_err2str(ret));
            exit(1);
        }
    }

    return ret == AVERROR_EOF ? 1 : 0;
}

/* Add an output stream. */
static void add_stream(OutputStream *ost, AVFormatContext *oc,
                       const AVCodec **codec,
                       enum AVCodecID codec_id)
{
    AVCodecContext *c;
    int i;

    /* find the encoder */
    *codec = avcodec_find_encoder(codec_id);
    if (!(*codec)) {
        fprintf(stderr, "Could not find encoder for '%s'\n",
                avcodec_get_name(codec_id));
        exit(1);
    }

    ost->tmp_pkt = av_packet_alloc();
    if (!ost->tmp_pkt) {
        fprintf(stderr, "Could not allocate AVPacket\n");
        exit(1);
    }

    ost->st = avformat_new_stream(oc, NULL);
    if (!ost->st) {
        fprintf(stderr, "Could not allocate stream\n");
        exit(1);
    }
    ost->st->id = oc->nb_streams-1;
    c = avcodec_alloc_context3(*codec);
    if (!c) {
        fprintf(stderr, "Could not alloc an encoding context\n");
        exit(1);
    }
    ost->enc = c;

    switch ((*codec)->type) {
    case AVMEDIA_TYPE_AUDIO:
        c->sample_fmt  = (*codec)->sample_fmts ?
            (*codec)->sample_fmts[0] : AV_SAMPLE_FMT_FLTP;
        c->bit_rate    = 64000;
        c->sample_rate = 44100;
        if ((*codec)->supported_samplerates) {
            c->sample_rate = (*codec)->supported_samplerates[0];
            for (i = 0; (*codec)->supported_samplerates[i]; i++) {
                if ((*codec)->supported_samplerates[i] == 44100)
                    c->sample_rate = 44100;
            }
        }
//        av_channel_layout_copy(&c->channel_layout, &(AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO);
        ost->st->time_base = (AVRational){ 1, c->sample_rate };
        break;

    case AVMEDIA_TYPE_VIDEO:
        c->codec_id = codec_id;

        c->bit_rate = 400000;
        /* Resolution must be a multiple of two. */
        c->width    = 352;
        c->height   = 288;
        /* timebase: This is the fundamental unit of time (in seconds) in terms
         * of which frame timestamps are represented. For fixed-fps content,
         * timebase should be 1/framerate and timestamp increments should be
         * identical to 1. */
        ost->st->time_base = (AVRational){ 1, STREAM_FRAME_RATE };
        c->time_base       = ost->st->time_base;

        c->gop_size      = 12; /* emit one intra frame every twelve frames at most */
        c->pix_fmt       = STREAM_PIX_FMT;
        if (c->codec_id == AV_CODEC_ID_MPEG2VIDEO) {
            /* just for testing, we also add B-frames */
            c->max_b_frames = 2;
        }
        if (c->codec_id == AV_CODEC_ID_MPEG1VIDEO) {
            /* Needed to avoid using macroblocks in which some coeffs overflow.
             * This does not happen with normal video, it just happens here as
             * the motion of the chroma plane does not match the luma plane. */
            c->mb_decision = 2;
        }
        break;

    default:
        break;
    }

    /* Some formats want stream headers to be separate. */
    if (oc->oformat->flags & AVFMT_GLOBALHEADER)
        c->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
}

/**************************************************************/
/* audio output */

static AVFrame *alloc_audio_frame(enum AVSampleFormat sample_fmt,
                                  int sample_rate, int nb_samples)
{
    AVFrame *frame = av_frame_alloc();
    int ret;

    if (!frame) {
        fprintf(stderr, "Error allocating an audio frame\n");
        exit(1);
    }

    frame->format = sample_fmt;
//    av_channel_layout_copy(&frame->channel_layout, AV_CH_LAYOUT_MONO);
    frame->channel_layout = AV_CH_LAYOUT_MONO;
    frame->sample_rate = sample_rate;
    frame->nb_samples = nb_samples;

    if (nb_samples) {
        ret = av_frame_get_buffer(frame, 0);
        if (ret < 0) {
            fprintf(stderr, "Error allocating an audio buffer\n");
            exit(1);
        }
    }

    return frame;
}

static void open_audio(AVFormatContext *oc, const AVCodec *codec,
                       OutputStream *ost, AVDictionary *opt_arg)
{
    AVCodecContext *c;
    int nb_samples;
    int ret;
    AVDictionary *opt = NULL;

    c = ost->enc;
    
    c->channels      = 1;
    c->channel_layout= AV_CH_LAYOUT_MONO;

    /* open it */
    av_dict_copy(&opt, opt_arg, 0);
    ret = avcodec_open2(c, codec, &opt);
    av_dict_free(&opt);
    if (ret < 0) {
        fprintf(stderr, "Could not open audio codec: %s\n", av_err2str(ret));
        exit(1);
    }

    /* init signal generator */
    ost->t     = 0;
    ost->tincr = 2 * M_PI * 110.0 / c->sample_rate;
    /* increment frequency by 110 Hz per second */
    ost->tincr2 = 2 * M_PI * 110.0 / c->sample_rate / c->sample_rate;

    if (c->codec->capabilities & AV_CODEC_CAP_VARIABLE_FRAME_SIZE)
        nb_samples = 10000;
    else
        nb_samples = c->frame_size;

    ost->frame     = alloc_audio_frame(c->sample_fmt,
                                       c->sample_rate, nb_samples);
    ost->tmp_frame = alloc_audio_frame(AV_SAMPLE_FMT_S16,
                                       c->sample_rate, nb_samples);

    /* copy the stream parameters to the muxer */
    ret = avcodec_parameters_from_context(ost->st->codecpar, c);
    if (ret < 0) {
        fprintf(stderr, "Could not copy the stream parameters\n");
        exit(1);
    }

    /* create resampler context */
    ost->swr_ctx = swr_alloc();
    if (!ost->swr_ctx) {
        fprintf(stderr, "Could not allocate resampler context\n");
        exit(1);
    }

    /* set options */
    
//    av_opt_set_channel_layout(ost->swr_ctx, "in_chlayout", AV_CH_LAYOUT_MONO, 0);
//    av_opt_set_channel_layout(ost->swr_ctx,"in_chlayout",&c->channel_layout,0);
//    av_opt_set_channel_layout  (ost->swr_ctx, "in_chlayout",       &c->channel_layout,      0);
//    av_opt_set_int       (ost->swr_ctx, "in_sample_rate",     c->sample_rate,    0);
//    av_opt_set_sample_fmt(ost->swr_ctx, "in_sample_fmt",      AV_SAMPLE_FMT_S16, 0);
//    av_opt_set_channel_layout  (ost->swr_ctx, "out_chlayout",     AV_CH_LAYOUT_MONO,      0);
//    av_opt_set_int       (ost->swr_ctx, "out_sample_rate",    c->sample_rate,    0);
//    av_opt_set_sample_fmt(ost->swr_ctx, "out_sample_fmt",     c->sample_fmt,     0);
    
    ost->swr_ctx = swr_alloc_set_opts(NULL,
                                       AV_CH_LAYOUT_MONO,AV_SAMPLE_FMT_S16,c->sample_rate,
                                       AV_CH_LAYOUT_MONO,AV_SAMPLE_FMT_S16,c->sample_rate,
                                             0,
                                             NULL);

    /* initialize the resampling context */
    if ((ret = swr_init(ost->swr_ctx)) < 0) {
        fprintf(stderr, "Failed to initialize the resampling context\n");
        exit(1);
    }
}

/* Prepare a 16 bit dummy audio frame of 'frame_size' samples and
 * 'nb_channels' channels. */
static AVFrame *get_audio_frame(OutputStream *ost)
{
    AVFrame *frame = ost->tmp_frame;
    int j, i, v;
    int16_t *q = (int16_t*)frame->data[0];

    /* check if we want to generate more frames */
    if (av_compare_ts(ost->next_pts, ost->enc->time_base,
                      STREAM_DURATION, (AVRational){ 1, 1 }) > 0)
        return NULL;

    for (j = 0; j <frame->nb_samples; j++) {
        v = (int)(sin(ost->t) * 10000);
//        for (i = 0; i < ost->enc->channel_layout.nb_channels; i++)
//            *q++ = v;
        ost->t     += ost->tincr;
        ost->tincr += ost->tincr2;
    }

    frame->pts = ost->next_pts;
    ost->next_pts  += frame->nb_samples;

    return frame;
}

/*
 * encode one audio frame and send it to the muxer
 * return 1 when encoding is finished, 0 otherwise
 */
static int write_audio_frame(AVFormatContext *oc, OutputStream *ost)
{
    AVCodecContext *c;
    AVFrame *frame;
    int ret;
    int dst_nb_samples;

    c = ost->enc;

    frame = get_audio_frame(ost);

    if (frame) {
        /* convert samples from native format to destination codec format, using the resampler */
        /* compute destination number of samples */
        dst_nb_samples = av_rescale_rnd(swr_get_delay(ost->swr_ctx, c->sample_rate) + frame->nb_samples,
                                        c->sample_rate, c->sample_rate, AV_ROUND_UP);
//        av_assert0(dst_nb_samples == frame->nb_samples);

        /* when we pass a frame to the encoder, it may keep a reference to it
         * internally;
         * make sure we do not overwrite it here
         */
        ret = av_frame_make_writable(ost->frame);
        if (ret < 0)
            exit(1);

        /* convert to destination format */
        ret = swr_convert(ost->swr_ctx,
                          ost->frame->data, dst_nb_samples,
                          (const uint8_t **)frame->data, frame->nb_samples);
        if (ret < 0) {
            fprintf(stderr, "Error while converting\n");
            exit(1);
        }
        frame = ost->frame;

        frame->pts = av_rescale_q(ost->samples_count, (AVRational){1, c->sample_rate}, c->time_base);
        ost->samples_count += dst_nb_samples;
    }

    return write_frame(oc, c, ost->st, frame, ost->tmp_pkt);
}

/**************************************************************/
/* video output */

static AVFrame *alloc_picture(enum AVPixelFormat pix_fmt, int width, int height)
{
    AVFrame *picture;
    int ret;

    picture = av_frame_alloc();
    if (!picture)
        return NULL;

    picture->format = pix_fmt;
    picture->width  = width;
    picture->height = height;

    /* allocate the buffers for the frame data */
    ret = av_frame_get_buffer(picture, 0);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate frame data.\n");
        exit(1);
    }

    return picture;
}

static void open_video(AVFormatContext *oc, const AVCodec *codec,
                       OutputStream *ost, AVDictionary *opt_arg)
{
    int ret;
    AVCodecContext *c = ost->enc;
    AVDictionary *opt = NULL;

    av_dict_copy(&opt, opt_arg, 0);

    /* open the codec */
    ret = avcodec_open2(c, codec, &opt);
    av_dict_free(&opt);
    if (ret < 0) {
        fprintf(stderr, "Could not open video codec: %s\n", av_err2str(ret));
        exit(1);
    }

    /* allocate and init a re-usable frame */
    ost->frame = alloc_picture(c->pix_fmt, c->width, c->height);
    if (!ost->frame) {
        fprintf(stderr, "Could not allocate video frame\n");
        exit(1);
    }

    /* If the output format is not YUV420P, then a temporary YUV420P
     * picture is needed too. It is then converted to the required
     * output format. */
    ost->tmp_frame = NULL;
    if (c->pix_fmt != AV_PIX_FMT_YUV420P) {
        ost->tmp_frame = alloc_picture(AV_PIX_FMT_YUV420P, c->width, c->height);
        if (!ost->tmp_frame) {
            fprintf(stderr, "Could not allocate temporary picture\n");
            exit(1);
        }
    }

    /* copy the stream parameters to the muxer */
    ret = avcodec_parameters_from_context(ost->st->codecpar, c);
    if (ret < 0) {
        fprintf(stderr, "Could not copy the stream parameters\n");
        exit(1);
    }
}

/* Prepare a dummy image. */
static void fill_yuv_image(AVFrame *pict, int frame_index,
                           int width, int height)
{
    int x, y, i;

    i = frame_index;

    /* Y */
    for (y = 0; y < height; y++)
        for (x = 0; x < width; x++)
            pict->data[0][y * pict->linesize[0] + x] = x + y + i * 3;

    /* Cb and Cr */
    for (y = 0; y < height / 2; y++) {
        for (x = 0; x < width / 2; x++) {
            pict->data[1][y * pict->linesize[1] + x] = 128 + y + i * 2;
            pict->data[2][y * pict->linesize[2] + x] = 64 + x + i * 5;
        }
    }
}

static AVFrame *get_video_frame(OutputStream *ost)
{
    AVCodecContext *c = ost->enc;

    /* check if we want to generate more frames */
    if (av_compare_ts(ost->next_pts, c->time_base,
                      STREAM_DURATION, (AVRational){ 1, 1 }) > 0)
        return NULL;

    /* when we pass a frame to the encoder, it may keep a reference to it
     * internally; make sure we do not overwrite it here */
    if (av_frame_make_writable(ost->frame) < 0)
        exit(1);

    if (c->pix_fmt != AV_PIX_FMT_YUV420P) {
        /* as we only generate a YUV420P picture, we must convert it
         * to the codec pixel format if needed */
        if (!ost->sws_ctx) {
            ost->sws_ctx = sws_getContext(c->width, c->height,
                                          AV_PIX_FMT_YUV420P,
                                          c->width, c->height,
                                          c->pix_fmt,
                                          SCALE_FLAGS, NULL, NULL, NULL);
            if (!ost->sws_ctx) {
                fprintf(stderr,
                        "Could not initialize the conversion context\n");
                exit(1);
            }
        }
        fill_yuv_image(ost->tmp_frame, ost->next_pts, c->width, c->height);
        sws_scale(ost->sws_ctx, (const uint8_t * const *) ost->tmp_frame->data,
                  ost->tmp_frame->linesize, 0, c->height, ost->frame->data,
                  ost->frame->linesize);
    } else {
        fill_yuv_image(ost->frame, ost->next_pts, c->width, c->height);
    }

    ost->frame->pts = ost->next_pts++;

    return ost->frame;
}

/*
 * encode one video frame and send it to the muxer
 * return 1 when encoding is finished, 0 otherwise
 */
static int write_video_frame(AVFormatContext *oc, OutputStream *ost)
{
    return write_frame(oc, ost->enc, ost->st, get_video_frame(ost), ost->tmp_pkt);
}

static void close_stream(AVFormatContext *oc, OutputStream *ost)
{
    avcodec_free_context(&ost->enc);
    av_frame_free(&ost->frame);
    av_frame_free(&ost->tmp_frame);
    av_packet_free(&ost->tmp_pkt);
    sws_freeContext(ost->sws_ctx);
    swr_free(&ost->swr_ctx);
}

/**************************************************************/
/* media file output */

int ffcopymain()
{
    OutputStream video_st = { 0 }, audio_st = { 0 };
    const AVOutputFormat *fmt;
    const char *filename;
    AVFormatContext *oc;
    const AVCodec *audio_codec, *video_codec;
    int ret;
    int have_video = 0, have_audio = 0;
    int encode_video = 0, encode_audio = 0;
    AVDictionary *opt = NULL;
    int i;

//    if (argc < 2) {
//        printf("usage: %s output_file\n"
//               "API example program to output a media file with libavformat.\n"
//               "This program generates a synthetic audio and video stream, encodes and\n"
//               "muxes them into a file named output_file.\n"
//               "The output format is automatically guessed according to the file extension.\n"
//               "Raw images can also be output by using '%%d' in the filename.\n"
//               "\n", argv[0]);
//        return 1;
//    }
//
//    filename = argv[1];
    
    NSString * videoPath =  [@"ffcopymux" stringByAppendingString:@".mp4"];
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
    
    
    filename = [videoPath UTF8String];
//    for (i = 2; i+1 < argc; i+=2) {
//        if (!strcmp(argv[i], "-flags") || !strcmp(argv[i], "-fflags"))
//            av_dict_set(&opt, argv[i]+1, argv[i+1], 0);
//    }

    /* allocate the output media context */
    avformat_alloc_output_context2(&oc, NULL, NULL, filename);
    if (!oc) {
        printf("Could not deduce output format from file extension: using MPEG.\n");
        avformat_alloc_output_context2(&oc, NULL, "mpeg", filename);
    }
    if (!oc)
        return 1;

    fmt = oc->oformat;

    /* Add the audio and video streams using the default format codecs
     * and initialize the codecs. */
    if (fmt->video_codec != AV_CODEC_ID_NONE) {
        add_stream(&video_st, oc, &video_codec, fmt->video_codec);
        have_video = 1;
        encode_video = 1;
    }
    if (fmt->audio_codec != AV_CODEC_ID_NONE) {
        add_stream(&audio_st, oc, &audio_codec, fmt->audio_codec);
        have_audio = 1;
        encode_audio = 1;
    }

    /* Now that all the parameters are set, we can open the audio and
     * video codecs and allocate the necessary encode buffers. */
    if (have_video)
        open_video(oc, video_codec, &video_st, opt);

    if (have_audio)
        open_audio(oc, audio_codec, &audio_st, opt);

    av_dump_format(oc, 0, filename, 1);

    /* open the output file, if needed */
    if (!(fmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&oc->pb, filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            fprintf(stderr, "Could not open '%s': %s\n", filename,
                    av_err2str(ret));
            return 1;
        }
    }

    /* Write the stream header, if any. */
    ret = avformat_write_header(oc, &opt);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file: %s\n",
                av_err2str(ret));
        return 1;
    }

    while (encode_video || encode_audio) {
        /* select the stream to encode */
        if (encode_video &&
            (!encode_audio || av_compare_ts(video_st.next_pts, video_st.enc->time_base,
                                            audio_st.next_pts, audio_st.enc->time_base) <= 0)) {
            encode_video = !write_video_frame(oc, &video_st);
        } else {
            encode_audio = !write_audio_frame(oc, &audio_st);
        }
    }

    av_write_trailer(oc);

    /* Close each codec. */
    if (have_video)
        close_stream(oc, &video_st);
    if (have_audio)
        close_stream(oc, &audio_st);

    if (!(fmt->flags & AVFMT_NOFILE))
        /* Close the output file. */
        avio_closep(&oc->pb);

    /* free the stream */
    avformat_free_context(oc);

    return 0;
}

+ (int)replaceAudio {
    AVOutputFormat *ofmt = NULL;
    //Input AVFormatContext and Output AVFormatContext
    AVFormatContext *ifmt_ctx_v = NULL, *ifmt_ctx_a = NULL,*ofmt_ctx = NULL;
    AVPacket pkt;
    int ret, i;
    int videoindex_v=-1,videoindex_out=-1;
    int audioindex_a=-1,audioindex_out=-1;
    int frame_index=0;
    int64_t cur_pts_v=0,cur_pts_a=0;


    const char *in_filename_a = [[[NSBundle mainBundle] pathForResource:@"audioMix" ofType:@"pcm"] UTF8String];
    const char * in_filename_v=  [[[NSBundle mainBundle] pathForResource:@"bitrate" ofType:@"h264"] UTF8String];

    
        const char *out_filename = [[self createvideo_file_url:@"androidppp"] UTF8String];//Output file URL
    av_register_all();
    //Input
    if ((ret = avformat_open_input(&ifmt_ctx_v, in_filename_v, 0, 0)) < 0) {//打开输入的视频文件
        goto end;
    }
    if ((ret = avformat_find_stream_info(ifmt_ctx_v, 0)) < 0) {//获取视频文件信息
        goto end;
    }

    if ((ret = avformat_open_input(&ifmt_ctx_a, in_filename_a, 0, 0)) < 0) {//打开输入的音频文件
        goto end;
    }
    if ((ret = avformat_find_stream_info(ifmt_ctx_a, 0)) < 0) {//获取音频文件信息
        goto end;
    }

    av_dump_format(ifmt_ctx_v, 0, in_filename_v, 0);
    av_dump_format(ifmt_ctx_a, 0, in_filename_a, 0);
    //Output
    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);//初始化输出码流的AVFormatContext。
    if (!ofmt_ctx) {
        ret = AVERROR_UNKNOWN;
        return -1;
    }
    ofmt = ofmt_ctx->oformat;

    //从输入的AVStream中获取一个输出的out_stream
    for (i = 0; i < ifmt_ctx_v->nb_streams; i++) {
        //Create output AVStream according to input AVStream
        if(ifmt_ctx_v->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO){
            AVStream *in_stream = ifmt_ctx_v->streams[i];
            AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);//创建流通道AVStream
            videoindex_v=i;
            if (!out_stream) {
                ret = AVERROR_UNKNOWN;
                break;
            }
            videoindex_out=out_stream->index;
            //Copy the settings of AVCodecContext
            if (avcodec_copy_context(out_stream->codec, in_stream->codec) < 0) {
                break;
            }
            out_stream->codec->codec_tag = 0;
            if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
                out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
            break;
        }
    }

    for (i = 0; i < ifmt_ctx_a->nb_streams; i++) {
        //Create output AVStream according to input AVStream
        if(ifmt_ctx_a->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO){
            AVStream *in_stream = ifmt_ctx_a->streams[i];
            AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
            audioindex_a=i;
            if (!out_stream) {
                ret = AVERROR_UNKNOWN;
                goto end;
            }
            audioindex_out=out_stream->index;
            //Copy the settings of AVCodecContext
            if (avcodec_copy_context(out_stream->codec, in_stream->codec) < 0) {
                goto end;
            }
            out_stream->codec->codec_tag = 0;
            if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
                out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

            break;
        }
    }

    av_dump_format(ofmt_ctx, 0, out_filename, 1);
    //Open output file
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        if (avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE) < 0) {//打开输出文件。
            return -1;
        }
    }
    //Write file header
    if (avformat_write_header(ofmt_ctx, NULL) < 0) {
        return -1;
    }


    //FIX
#if USE_H264BSF
    AVBitStreamFilterContext* h264bsfc =  av_bitstream_filter_init("h264_mp4toannexb");
#endif
#if USE_AACBSF
    AVBitStreamFilterContext* aacbsfc =  av_bitstream_filter_init("aac_adtstoasc");
#endif

    while (1) {
        AVFormatContext *ifmt_ctx;
        int stream_index=0;
        AVStream *in_stream, *out_stream;

        //Get an AVPacket .   av_compare_ts是比较时间戳用的。通过该函数可以决定该写入视频还是音频。
        if(av_compare_ts(cur_pts_v,ifmt_ctx_v->streams[videoindex_v]->time_base,cur_pts_a,ifmt_ctx_a->streams[audioindex_a]->time_base) <= 0){
            
            ifmt_ctx=ifmt_ctx_v;
            stream_index=videoindex_out;

            if(av_read_frame(ifmt_ctx, &pkt) >= 0){
                do{
                    in_stream  = ifmt_ctx->streams[pkt.stream_index];
                    out_stream = ofmt_ctx->streams[stream_index];

                    if(pkt.stream_index==videoindex_v){
                        //FIX：No PTS (Example: Raw H.264) H.264裸流没有PTS，因此必须手动写入PTS
                        //Simple Write PTS
                        if(pkt.pts==AV_NOPTS_VALUE){
                            //Write PTS
                            AVRational time_base1=in_stream->time_base;
                            //Duration between 2 frames (us)
                            int64_t calc_duration=(double)AV_TIME_BASE/av_q2d(in_stream->r_frame_rate);
                            //Parameters
                            pkt.pts=(double)(frame_index*calc_duration)/(double)(av_q2d(time_base1)*AV_TIME_BASE);
                            pkt.dts=pkt.pts;
                            pkt.duration=(double)calc_duration/(double)(av_q2d(time_base1)*AV_TIME_BASE);
                            frame_index++;
                        }

                        cur_pts_v=pkt.pts;
                        NSLog(@"cur_pts_v------%lld",cur_pts_v);
                        break;
                    }
                }while(av_read_frame(ifmt_ctx, &pkt) >= 0);
            }else{
                break;
            }
        }else{
            ifmt_ctx=ifmt_ctx_a;
            stream_index=audioindex_out;
            if(av_read_frame(ifmt_ctx, &pkt) >= 0){
                do{
                    in_stream  = ifmt_ctx->streams[pkt.stream_index];
                    out_stream = ofmt_ctx->streams[stream_index];

                    if(pkt.stream_index==audioindex_a){

                        //FIX：No PTS
                        //Simple Write PTS
                        if(pkt.pts==AV_NOPTS_VALUE){
                            //Write PTS
                            AVRational time_base1=in_stream->time_base;
                            //Duration between 2 frames (us)
                            int64_t calc_duration=(double)AV_TIME_BASE/av_q2d(in_stream->r_frame_rate);
                            //Parameters
                            pkt.pts=(double)(frame_index*calc_duration)/(double)(av_q2d(time_base1)*AV_TIME_BASE);
                            pkt.dts=pkt.pts;
                            pkt.duration=(double)calc_duration/(double)(av_q2d(time_base1)*AV_TIME_BASE);
                            frame_index++;
                        }
                        cur_pts_a=pkt.pts;
                        NSLog(@"cur_pts_a------%lld",cur_pts_a);
                        break;
                    }
                }while(av_read_frame(ifmt_ctx, &pkt) >= 0);
            }else{
                break;
            }

        }

        //FIX:Bitstream Filter
#if USE_H264BSF
        av_bitstream_filter_filter(h264bsfc, in_stream->codec, NULL, &pkt.data, &pkt.size, pkt.data, pkt.size, 0);
#endif
#if USE_AACBSF
        av_bitstream_filter_filter(aacbsfc, out_stream->codec, NULL, &pkt.data, &pkt.size, pkt.data, pkt.size, 0);
#endif


        //Convert PTS/DTS
        pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, (AVRounding)(AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, (AVRounding)(AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
        pkt.pos = -1;
        pkt.stream_index=stream_index;

        //Write AVPacket 音频或视频裸流
        if (av_interleaved_write_frame(ofmt_ctx, &pkt) < 0) {
            break;
        }
        av_free_packet(&pkt);

    }
    //Write file trailer
    av_write_trailer(ofmt_ctx);

#if USE_H264BSF
    av_bitstream_filter_close(h264bsfc);
#endif
#if USE_AACBSF
    av_bitstream_filter_close(aacbsfc);
#endif

    end:
    avformat_close_input(&ifmt_ctx_v);
    avformat_close_input(&ifmt_ctx_a);
    /* close output */
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
        avio_close(ofmt_ctx->pb);
    avformat_free_context(ofmt_ctx);
    if (ret < 0 && ret != AVERROR_EOF) {
        return -1;
    }
    return 0;
}

- (int)create:(const char *)filter_descr withcon:(AudioConfig *)inConfig1 withcon:(AudioConfig *)inConfig2 withcon:(AudioConfig *)outConfig {
    description = filter_descr;
    char args[512];
    int ret = 0;

    //设置缓存滤镜和输出滤镜
    const AVFilter *buffersrc = avfilter_get_by_name("abuffer");
    const AVFilter *buffersink = avfilter_get_by_name("abuffersink");
    AVFilterInOut *output = avfilter_inout_alloc();
    AVFilterInOut *inputs[2];
    inputs[0] = avfilter_inout_alloc();
    inputs[1] = avfilter_inout_alloc();

    char ch_layout[128];
    int nb_channels = 0;
    int pix_fmts[] = {outConfig->format, AV_SAMPLE_FMT_NONE };

    //创建滤镜容器
    filter_graph = avfilter_graph_alloc();
    if (!inputs[0] || !inputs[1] || !output || !filter_graph) {
        ret = AVERROR(ENOMEM);
        goto end;
    }

    //声道布局
    nb_channels = av_get_channel_layout_nb_channels(inConfig1->ch_layout);
    av_get_channel_layout_string(ch_layout, sizeof(ch_layout), nb_channels, inConfig1->ch_layout);

    //输入缓存1的配置
    snprintf(args, sizeof(args),
        "sample_rate=%d:sample_fmt=%d:channel_layout=%s:channels=%d:time_base=%d/%d",
        inConfig1->sample_rate,
        inConfig1->format,
        ch_layout,
        nb_channels,
        inConfig1->timebase.num,
        inConfig1->timebase.den);
    ret = avfilter_graph_create_filter(&buffersrc1_ctx, buffersrc, "in1",
        args, nullptr, filter_graph);
    if (ret < 0)
    {
        goto end;
    }

    //输入缓存2的配置
    nb_channels = av_get_channel_layout_nb_channels(inConfig2->ch_layout);
    av_get_channel_layout_string(ch_layout, sizeof(ch_layout), nb_channels, inConfig2->ch_layout);
    snprintf(args, sizeof(args),
        "sample_rate=%d:sample_fmt=%d:channel_layout=%s:channels=%d:time_base=%d/%d",
        inConfig2->sample_rate,
        inConfig2->format,
        ch_layout,
        nb_channels,
        inConfig2->timebase.num,
        inConfig2->timebase.den);
    ret = avfilter_graph_create_filter(&buffersrc2_ctx, buffersrc, "in2",
        args, nullptr, filter_graph);
    if (ret < 0)
    {
        goto end;
    }

    //创建输出
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
        nullptr, nullptr, filter_graph);
    if (ret < 0)
    {
        goto end;
    }

    ret = av_opt_set_int_list(buffersink_ctx, "sample_fmts", pix_fmts,
        AV_SAMPLE_FMT_NONE, AV_OPT_SEARCH_CHILDREN);
    if (ret < 0) {
        goto end;
    }

    inputs[0]->name = av_strdup("in1");
    inputs[0]->filter_ctx = buffersrc1_ctx;
    inputs[0]->pad_idx = 0;
    inputs[0]->next = inputs[1];

    inputs[1]->name = av_strdup("in2");
    inputs[1]->filter_ctx = buffersrc2_ctx;
    inputs[1]->pad_idx = 0;
    inputs[1]->next = nullptr;

    output->name = av_strdup("out");
    output->filter_ctx = buffersink_ctx;
    output->pad_idx = 0;
    output->next = nullptr;

    //引脚的输出和输入与滤镜容器的相反
    avfilter_graph_set_auto_convert(filter_graph, AVFILTER_AUTO_CONVERT_NONE);
    if ((ret = avfilter_graph_parse_ptr(filter_graph, filter_descr,
        &output, inputs, nullptr)) < 0) {
        goto end;
    }

    //使滤镜容器生效
    if ((ret = avfilter_graph_config(filter_graph, nullptr)) < 0) {
        goto end;
    }

end:
    avfilter_inout_free(inputs);
    avfilter_inout_free(&output);

    return ret;
}

- (int)twocreate:(const char *)filter_descr withcon:(AudioConfig *)inConfig withcon:(AudioConfig *)outConfig {
    description = filter_descr;
    char args[512];
    int ret = 0;
    const AVFilter *buffersrc = avfilter_get_by_name("abuffer");
    const AVFilter *buffersink = avfilter_get_by_name("abuffersink");
    AVFilterInOut *output = avfilter_inout_alloc();
    AVFilterInOut *input = avfilter_inout_alloc();

    char ch_layout[128];
    int nb_channels = 0;
    int pix_fmts[] = { outConfig->format, AV_SAMPLE_FMT_NONE };

    filter_graph = avfilter_graph_alloc();
    if (!input || !output || !filter_graph) {
        ret = AVERROR(ENOMEM);
        goto end;
    }

    //缓存源和槽定义
    nb_channels = av_get_channel_layout_nb_channels(inConfig->ch_layout);
    av_get_channel_layout_string(ch_layout, sizeof(ch_layout), nb_channels, inConfig->ch_layout);
    snprintf(args, sizeof(args),
        "sample_rate=%d:sample_fmt=%d:channel_layout=%s:channels=%d:time_base=%d/%d",
        inConfig->sample_rate,
        inConfig->format,
        ch_layout,
        nb_channels,
        inConfig->timebase.num,
        inConfig->timebase.den);
    ret = avfilter_graph_create_filter(&buffersrc1_ctx, buffersrc, "in1",
        args, nullptr, filter_graph);
    if (ret < 0) {
        goto end;
    }

    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
        nullptr, nullptr, filter_graph);
    if (ret < 0) {
        goto end;
    }

    ret = av_opt_set_int_list(buffersink_ctx, "sample_fmts", pix_fmts,
        AV_SAMPLE_FMT_NONE, AV_OPT_SEARCH_CHILDREN);
    if (ret < 0) {
        goto end;
    }

    input->name = av_strdup("in");
    input->filter_ctx = buffersrc1_ctx;
    input->pad_idx = 0;
    input->next = nullptr;

    output->name = av_strdup("out");
    output->filter_ctx = buffersink_ctx;
    output->pad_idx = 0;
    output->next = nullptr;

    if ((ret = avfilter_graph_parse_ptr(filter_graph, filter_descr,
        &output, &input, nullptr)) < 0) {
        goto end;
    }

    if ((ret = avfilter_graph_config(filter_graph, nullptr)) < 0)
    {
        goto end;
    }

end:
    avfilter_inout_free(&input);
    avfilter_inout_free(&output);

    return ret;
}

-(void)dumpGraph {
    printf("%s\n%s", description, avfilter_graph_dump(filter_graph, nullptr));
}


-(void)destroy {
    if (filter_graph)
        avfilter_graph_free(&filter_graph);

    filter_graph = nullptr;
}

-(int)filter:(AVFrame *)input1 with:(AVFrame *)input2 with:(AVFrame *)result
{
    int ret = av_buffersrc_add_frame_flags(buffersrc1_ctx, input1, AV_BUFFERSRC_FLAG_KEEP_REF);
    if (ret < 0)
    {
        return ret;
    }

    ret = av_buffersrc_add_frame_flags(buffersrc2_ctx, input2, AV_BUFFERSRC_FLAG_KEEP_REF);
    if (ret < 0)
    {
        return ret;
    }

    return av_buffersink_get_samples(buffersink_ctx, result, result->nb_samples);
}

-(int)getFrame:(AVFrame *)result {
    if (filter_graph != nullptr)
    {
        int ret = av_buffersink_get_samples(buffersink_ctx, result, result->nb_samples);
        return ret;
    }
    return -1;
}

-(int)addInput1:(AVFrame *)input {
    if (filter_graph != nullptr)
    {
        return av_buffersrc_add_frame_flags(buffersrc1_ctx, input, AV_BUFFERSRC_FLAG_KEEP_REF);
    }
    return - 1;
}

-(int)addInput2:(AVFrame *)input {
    if (filter_graph != nullptr)
    {
        return av_buffersrc_add_frame_flags(buffersrc2_ctx, input, AV_BUFFERSRC_FLAG_KEEP_REF);
    }
    return -1;
}

-(int)add_bgm_to_video:(const char *)output_filename with:(const char *)input_filename with:(const char *)bgm_filename with:(float)bgm_volume
{
    
    NSString *one = [self createvideofileurl:@"addbgm"];
    
    output_filename = [one UTF8String];
    
    input_filename = [[[NSBundle mainBundle] pathForResource:@"flower" ofType:@"MP4"] UTF8String];
    
    bgm_filename = [[[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"] UTF8String];
    
    int ret = 0;
    //各种解码器的上下文
    AVFormatContext *outFmtContext = nullptr;
    AVFormatContext *inFmtContext = nullptr;
    AVFormatContext *bgmFmtContext = nullptr;
    AVCodecContext *inAudioContext = nullptr;
    AVCodecContext *inVideoContext = nullptr;
    AVCodecContext *outAudioContext = nullptr;
    AVCodecContext *bgmAudioContext = nullptr;
//    AudioFilter filter;

    //音视频流信息
    AVStream *inAudioStream = nullptr;
    AVStream *inVideoStream = nullptr;
    AVStream *outAudioStream = nullptr;
    AVStream *outVideoStream = nullptr;
    AVStream *bgmAudioStream = nullptr;

    AVCodec *audioCodec = nullptr;

    //打开视频文件获取上下文
    ret = openVideoFile(input_filename, inFmtContext, inAudioContext, inVideoContext, inAudioStream,
        inVideoStream);
    if (ret < 0) return ret;

    //打开音频文件获取上下文
    ret = openAudioFile(bgm_filename, bgmFmtContext, bgmAudioContext, bgmAudioStream);
    if (ret < 0) return ret;

    //创建输出的上下文
    ret = avformat_alloc_output_context2(&outFmtContext, nullptr, nullptr, output_filename);

    audioCodec = avcodec_find_encoder(inAudioStream->codecpar->codec_id);

    //创建输出视频流，不需要编码
    outVideoStream = avformat_new_stream(outFmtContext, nullptr);
    if (!outVideoStream) {
        return -1;
    }
    outVideoStream->id = outFmtContext->nb_streams - 1;
    ret = avcodec_parameters_copy(outVideoStream->codecpar, inVideoStream->codecpar);
    if (ret < 0) {
        return -1;
    }
    outVideoStream->codecpar->codec_tag = 0;

    //创建音频流,需要编码
    outAudioStream = avformat_new_stream(outFmtContext, audioCodec);
    if (!outAudioStream)
    {
        return -1;
    }
    outAudioStream->id = outFmtContext->nb_streams - 1;

    //设置音频参数
    outAudioContext = avcodec_alloc_context3(audioCodec);
    avcodec_parameters_to_context(outAudioContext, inAudioStream->codecpar);
    outAudioContext->codec_type = inAudioContext->codec_type;
    outAudioContext->codec_id = inAudioContext->codec_id;
    outAudioContext->sample_fmt = inAudioContext->sample_fmt;
    outAudioContext->sample_rate = inAudioContext->sample_rate;
    outAudioContext->bit_rate = inAudioContext->bit_rate;
    outAudioContext->channel_layout = inAudioContext->channel_layout;
    outAudioContext->channels = inAudioContext->channels;
    outAudioContext->time_base = AVRational{ 1, outAudioContext->sample_rate };
    outAudioContext->flags |= AV_CODEC_FLAG_LOW_DELAY;
    outAudioStream->time_base = outAudioContext->time_base;
    if (outFmtContext->oformat->flags & AVFMT_GLOBALHEADER)
    {
        outAudioContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    //打开编码器
    ret = avcodec_open2(outAudioContext, audioCodec, nullptr);
    if (ret < 0)
    {
        return -1;
    }
    ret = avcodec_parameters_from_context(outAudioStream->codecpar, outAudioContext);
    if (ret < 0)
    {
        return -1;
    }

    //拷贝原始数据
    av_dict_copy(&outFmtContext->metadata, inFmtContext->metadata, 0);
    av_dict_copy(&outVideoStream->metadata, inVideoStream->metadata, 0);
    av_dict_copy(&outAudioStream->metadata, inAudioStream->metadata, 0);


    //设置输入输出配置
    AudioConfig inputConfig{ inAudioContext->sample_fmt,
        inAudioContext->sample_rate,
        inAudioContext->channel_layout,
        inAudioContext->time_base };
    AudioConfig bgmConfig{ bgmAudioContext->sample_fmt,
        bgmAudioContext->sample_rate,
        bgmAudioContext->channel_layout,
        bgmAudioContext->time_base };
    AudioConfig outputConfig{ outAudioContext->sample_fmt,
        outAudioContext->sample_rate,
        outAudioContext->channel_layout,
        outAudioContext->time_base };

    //通过滤镜修改音频的音量和采样率
    char filter_description[256];
    char ch_layout[128];
    av_get_channel_layout_string(ch_layout, 128, av_get_channel_layout_nb_channels(outAudioContext->channel_layout),
        outAudioContext->channel_layout);
    snprintf(filter_description, sizeof(filter_description),
        "[in1]aresample=%d[a1];[in2]aresample=%d,volume=volume=%f[a2];[a1][a2]amix[out]",
        outAudioContext->sample_rate,
        outAudioContext->sample_rate,
        bgm_volume);
//    self create:filter_description, &inputConfig, &bgmConfig, &outputConfig);
    [self create:filter_description withcon:&inputConfig withcon:&bgmConfig withcon:&outputConfig];
    [self dumpGraph];

    if (!(outFmtContext->oformat->flags & AVFMT_NOFILE))
    {
        ret = avio_open(&outFmtContext->pb, output_filename, AVIO_FLAG_WRITE);
        if (ret < 0)
        {
            return -1;
        }
    }

    //写文件头
    ret = avformat_write_header(outFmtContext, nullptr);
    if (ret < 0)
    {
        return -1;
    }

    AVFrame *inputFrame = av_frame_alloc();
    AVFrame *bgmFrame = av_frame_alloc();
    AVFrame *mixFrame = av_frame_alloc();

    do
    {
        AVPacket packet{ nullptr };
        av_init_packet(&packet);
        ret = av_read_frame(inFmtContext, &packet);
        if (ret == AVERROR_EOF)
        {
            break;
        }
        else if (ret < 0)
        {
            break;
        }

        if (packet.flags & AV_PKT_FLAG_DISCARD) continue;
        if (packet.stream_index == inVideoStream->index)
        {
            packet.stream_index = outVideoStream->index;
            av_packet_rescale_ts(&packet, inVideoStream->time_base, outVideoStream->time_base);
            packet.duration = av_rescale_q(packet.duration, inVideoStream->time_base, outVideoStream->time_base);
            packet.pos = -1;
            ret = av_interleaved_write_frame(outFmtContext, &packet);
        }
        else if (packet.stream_index == inAudioStream->index)
        {
            packet.stream_index = outAudioStream->index;
            av_packet_rescale_ts(&packet, inAudioStream->time_base, outAudioStream->time_base);

            // decode input frame
            ret = avcodec_send_packet(inAudioContext, &packet);
            
            ret = avcodec_receive_frame(inAudioContext, inputFrame);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                continue;
            }
            else if (ret < 0) {
                return -1;
            }

            [self addInput1:inputFrame];
            //添加背景音乐对应的音频帧
        decode:
            int got_bgm = 0;
            while (true) {
                AVPacket bgmPacket{ nullptr };
                av_init_packet(&bgmPacket);
                ret = av_read_frame(bgmFmtContext, &bgmPacket);
                if (ret == AVERROR_EOF) {
                    av_seek_frame(bgmFmtContext, bgmAudioStream->index, 0, 0);
                    continue;
                }
                else if (ret != 0) {
                    break;
                }
                if (bgmPacket.stream_index == bgmAudioStream->index) {
                    avcodec_send_packet(bgmAudioContext, &bgmPacket);
                    ret = avcodec_receive_frame(bgmAudioContext, bgmFrame);
                    if (ret == 0)
                    {
                        got_bgm = 1;
                        break;
                    }
                }
            }

            //读取混合之后的音频帧
            [self addInput2:bgmFrame];
            int got_mix = 0;
            if (got_bgm) {
                ret = [self getFrame:mixFrame];
                got_mix = ret == 0;
            }
            if (!got_mix) {
                goto decode;
            }
            mixFrame->pts = inputFrame->pts;

            av_frame_unref(inputFrame);
            av_frame_unref(bgmFrame);
            avcodec_send_frame(outAudioContext, mixFrame);

            //将混合之后的音频帧写入到文件中
        encode:
            AVPacket mixPacket{ nullptr };
            ret = avcodec_receive_packet(outAudioContext, &mixPacket);
            if (ret == 0)
            {
                mixPacket.stream_index = outAudioStream->index;
                ret = av_interleaved_write_frame(outFmtContext, &mixPacket);
                goto encode;
            }
            else if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                
            }
            else {

                return -1;
            }
        }
    } while (true);

    [self destroy];

    av_write_trailer(outFmtContext);

    if (!(outFmtContext->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&outFmtContext->pb);
    }

    //清理分配之后的数据
    av_frame_free(&inputFrame);
    av_frame_free(&bgmFrame);
    av_frame_free(&mixFrame);

    avformat_free_context(outFmtContext);
    avformat_free_context(inFmtContext);
    avformat_free_context(bgmFmtContext);

    avcodec_free_context(&inAudioContext);
    avcodec_free_context(&inVideoContext);
    avcodec_free_context(&bgmAudioContext);
    avcodec_free_context(&outAudioContext);

    return 0;
}

int openAudioFile(const char *file, AVFormatContext *&formatContext, AVCodecContext *&audioContext,
    AVStream *&audioStream) {
    int ret = 0;
    ret = avformat_open_input(&formatContext, file, nullptr, nullptr);
    if (ret < 0)
    {
        return -1;
    }
    ret = avformat_find_stream_info(formatContext, nullptr);
    if (ret < 0)
    {
        return -1;
    }

    for (int j = 0; j < formatContext->nb_streams; ++j) {
        if (formatContext->streams[j]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audioStream = formatContext->streams[j];
            AVCodec *codec = avcodec_find_decoder(audioStream->codecpar->codec_id);
            audioContext = avcodec_alloc_context3(codec);
            avcodec_parameters_to_context(audioContext, audioStream->codecpar);
            avcodec_open2(audioContext, codec, nullptr);
        }
    }
    if (!audioStream)
    {
        return -1;
    }
    return 0;
}

int openVideoFile(const char *file, AVFormatContext *&formatContext, AVCodecContext *&audioContext,
    AVCodecContext *&videoContext, AVStream *&audioStream, AVStream *&videoStream) {
    int ret = 0;
    ret = avformat_open_input(&formatContext, file, nullptr, nullptr);
    if (ret < 0)
    {
        return -1;
    }
    ret = avformat_find_stream_info(formatContext, nullptr);
    if (ret < 0)
    {
        return -1;
    }

    for (int j = 0; j < formatContext->nb_streams; ++j) {
        if (formatContext->streams[j]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoStream = formatContext->streams[j];
            AVCodec *codec = avcodec_find_decoder(videoStream->codecpar->codec_id);
            videoContext = avcodec_alloc_context3(codec);
            avcodec_parameters_to_context(videoContext, videoStream->codecpar);
            avcodec_open2(videoContext, codec, nullptr);
        }
        else if (formatContext->streams[j]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audioStream = formatContext->streams[j];
            AVCodec *codec = avcodec_find_decoder(audioStream->codecpar->codec_id);
            audioContext = avcodec_alloc_context3(codec);
            avcodec_parameters_to_context(audioContext, audioStream->codecpar);
            avcodec_open2(audioContext, codec, nullptr);
        }
        if (videoStream && audioStream) break;
    }

    if (!videoStream)
    {
        return -1;
    }
    if (!audioContext)
    {
        return -1;
    }

    return 0;
}


+(void)MergeTwo:(NSString *) srcPath1 with:(NSString *)srcPath2 with:(NSString *)dstPath
{
    /** 媒体格式类型：
     *  媒体格式分为流式和非流式。主要区别在于两种文件格式如何嵌入元信息，非流式的元信息通常存储在文件中开头，有时在结尾；而流式的元信息跟
     *  具体音视频数据同步存放的。所以多个流式文件简单串联在一起形成新的文件也能正常播放。而多个非流式文件的合并则可能要重新编解码才可以
     *  如下mpg格式就是流式格式，通过直接依次取出每个文件的AVPacket，然后依次调用av_write_frame()即可实现文件合并
     *  如下mp4格式就是非流式格式，如果采用上面的流程合并则要求各个文件具有相同的编码方式，分辨率，像素格式等等才可以，否则就会失败。因为非流式格式的元信息只能描述一种类型的音
     *  视频数据
    */
    AVFormatContext *in_fmt1 = NULL;
    AVFormatContext *in_fmt2 = NULL;
    AVFormatContext *ou_fmt = NULL;
    int video1_in_index = -1,audio1_in_index = -1;
    int video2_in_index = -1,audio2_in_index = -1;
    int video_ou_index = -1,audio_ou_index = -1;
    int64_t next_video_pts = 0,next_audio_pts = 0;
    
    srcPath1 = [[NSBundle mainBundle] pathForResource:@"flower" ofType:@"MP4"];
    srcPath2 = [[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"];
    dstPath = [self createvideo_file_url:@"mergemp4"];
    
    // 打开要合并的源文件1
    int ret = 0;
    /** 遇到问题：解封装mpg格式视频编码参数始终不正确，提示"[mp3float @ 0x104808800] Header missing"
     *  分析原因：mpg格式对应的demuxer为ff_mpegps_demuxer，它没有.extensions字段(ff_mov_demuxer格式就有)，所以最终它会靠read_probe对应的
     *  方法去分析格式,最终会调用到av_probe_input_format3()中去，该方法又会重新用每个解封装器进行解析为ff_mpegvideo_demuxer，如果没有将该接封装器封装进去则就会出问题
     *  解决方案：要想解封装mpg格式的视频编码参数，必须要同时编译ff_mpegps_demuxer和ff_mpegvideo_demuxer及ff_mpegvideo_parser,ff_mpeg1video_decoder,ff_mp2float_decoder
     */
    if ((ret = avformat_open_input(&in_fmt1,[srcPath1 UTF8String],NULL,NULL)) < 0) {
        return;
    }
    if (avformat_find_stream_info(in_fmt1, NULL) < 0) {
        return;
    }
    // 将源文件1音视频索引信息找出来
    for (int i=0; i<in_fmt1->nb_streams; i++) {
        AVStream *stream = in_fmt1->streams[i];
        if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO && video1_in_index == -1) {
            video1_in_index = i;
        }
        if (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO && audio1_in_index == -1) {
            audio1_in_index = i;
        }
    }
    
    // 打开要合并的源文件2
    if (avformat_open_input(&in_fmt2,[srcPath2 UTF8String],NULL,NULL) < 0) {
        return;
    }
    if (avformat_find_stream_info(in_fmt2, NULL) < 0) {
        return;
    }
    // 将源文件2音视频索引信息找出来
    for (int i=0; i<in_fmt2->nb_streams; i++) {
        AVStream *stream = in_fmt2->streams[i];
        if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO && video2_in_index == -1) {
            video2_in_index = i;
        }
        if (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO && audio2_in_index == -1) {
            audio2_in_index = i;
        }
    }
    
    // 打开最终要封装的文件
    if (avformat_alloc_output_context2(&ou_fmt, NULL, NULL, [dstPath UTF8String]) < 0) {
        return;
    }
    
    // 为封装的文件添加视频流信息;由于假设两个文件的视频流具有相同的编码方式，这里就是简单的流拷贝
    for (int i=0;i<1;i++) {
        if (video1_in_index != -1) {
            AVStream *stream = avformat_new_stream(ou_fmt,NULL);
            video_ou_index = stream->index;
            
            // 由于是流拷贝方式
            AVStream *srcstream = in_fmt1->streams[video1_in_index];
            if (avcodec_parameters_copy(stream->codecpar, srcstream->codecpar) < 0) {
                return;
            }
            
            // codec_id和codec_tag共同决定了一种编码方式在容器里面的码流格式，所以如果源文件与目的文件的码流格式不一致，那么就需要将目的文件
            // 的code_tag 设置为0，当调用avformat_write_header()函数后会自动将两者保持一致
            unsigned int src_tag = srcstream->codecpar->codec_tag;
            if (av_codec_get_id(ou_fmt->oformat->codec_tag, src_tag) != stream->codecpar->codec_id) {
                stream->codecpar->codec_tag = 0;
            }
            break;
        }
        if (video2_in_index != -1) { // 只要任何一个文件有视频流都创建视频流
            AVStream *stream = avformat_new_stream(ou_fmt,NULL);
            video_ou_index = stream->index;
            
            // 由于是流拷贝方式
            AVStream *srcstream = in_fmt2->streams[video2_in_index];
            if (avcodec_parameters_copy(stream->codecpar,srcstream->codecpar) < 0) {
                return;
            }
            
            unsigned int src_tag = srcstream->codecpar->codec_tag;
            if (av_codec_get_id(ou_fmt->oformat->codec_tag,src_tag) != stream->codecpar->codec_id) {
                stream->codecpar->codec_tag = 0;
            }
        }
    }
    
    // 为封装的文件添加流信息;由于假设两个文件的视频流具有相同的编码方式，这里就是简单的流拷贝
    for (int i=0;i<1;i++) {
        if (audio1_in_index != -1) {
            AVStream *dststream = avformat_new_stream(ou_fmt,NULL);
            AVStream *srcstream = in_fmt1->streams[audio1_in_index];
            if (avcodec_parameters_copy(dststream->codecpar,srcstream->codecpar) < 0) {
                return;
            }
            audio_ou_index = dststream->index;
            break;
        }
        
        if (audio2_in_index != -1) {
            AVStream *dststream = avformat_new_stream(ou_fmt, NULL);
            AVStream *srcstream = in_fmt2->streams[audio1_in_index];
            if (avcodec_parameters_copy(dststream->codecpar,srcstream->codecpar) < 0) {
                return;
            }
            audio_ou_index = dststream->index;
        }
    }
    
    // 打开输出上下文
    if (!(ou_fmt->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&ou_fmt->pb, [dstPath UTF8String],AVIO_FLAG_WRITE) < 0) {
            return;
        }
    }
    
    /** 遇到问题：写入mpg容器时提示"mpeg1video files have exactly one stream"
     *  分析原因：编译mpg的封装器错了，之前写的--enable-muxer=mpeg1video实际上应该是--enable-muxer=mpeg1system
     *  解决方案：编译mpg的封装器换成--enable-muxer=mpeg1system
     */
    // 写入文件头
    if (avformat_write_header(ou_fmt, NULL) < 0) {
        return;
    }
    
    // 进行流拷贝；源文件1
    AVPacket *in_pkt1 = av_packet_alloc();
    while(av_read_frame(in_fmt1,in_pkt1) >=0) {
        
        // 视频流
        if (in_pkt1->stream_index == video1_in_index) {
            
            AVStream *srcstream = in_fmt1->streams[in_pkt1->stream_index];
            AVStream *dststream = ou_fmt->streams[video_ou_index];
            // 由于源文件和目的文件的时间基可能不一样，所以这里要将时间戳进行转换
            next_video_pts = MAX(in_pkt1->pts + in_pkt1->duration,next_video_pts);
            av_packet_rescale_ts(in_pkt1, srcstream->time_base, dststream->time_base);
            // 更正目标流的索引
            in_pkt1->stream_index = video_ou_index;
            
           
        }
        
        // 音频流
        if (in_pkt1->stream_index == audio1_in_index) {
            AVStream *srcstream = in_fmt1->streams[in_pkt1->stream_index];
            AVStream *dststream = ou_fmt->streams[audio_ou_index];
            next_audio_pts = MAX(in_pkt1->pts + in_pkt1->duration,next_audio_pts);
            // 由于源文件和目的文件的时间基可能不一样，所以这里要将时间戳进行转换
            av_packet_rescale_ts(in_pkt1, srcstream->time_base, dststream->time_base);
            // 更正目标流的索引
            in_pkt1->stream_index = audio_ou_index;
            
        }
        
        // 向封装器中写入数据
        if((ret = av_write_frame(ou_fmt, in_pkt1)) < 0) {

            return;;
        }
    }
    
    // 进行流拷贝；源文件1
    while(true) {
        AVPacket *in_pkt2 = av_packet_alloc();
        if(av_read_frame(in_fmt2,in_pkt2) <0 ) break;
        /** 遇到问题：写入数据是提示"[mp4 @ 0x10100ba00] Application provided invalid, non monotonically increasing dts to muxer in stream 1: 4046848 >= 0"
         *  分析原因：因为是两个源文件进行合并，对于每一个源文件来说，它的第一个AVPacket的pts都是0开始的
         *  解决方案：所以第二个源文件的pts,dts,duration就应该加上前面源文件的duration最大值
         */
        // 视频流
        if (in_pkt2->stream_index == video2_in_index) {
            
            AVStream *srcstream = in_fmt2->streams[in_pkt2->stream_index];
            AVStream *dststream = ou_fmt->streams[video_ou_index];
            if (next_video_pts > 0) {
                AVStream *srcstream2 = in_fmt1->streams[video1_in_index];
                in_pkt2->pts = av_rescale_q(in_pkt2->pts, srcstream->time_base, srcstream2->time_base) + next_video_pts;
                in_pkt2->dts = av_rescale_q(in_pkt2->dts, srcstream->time_base, srcstream2->time_base) + next_video_pts;
                in_pkt2->duration = av_rescale_q(in_pkt2->duration, srcstream->time_base, srcstream2->time_base);
                // 由于源文件和目的文件的时间基可能不一样，所以这里要将时间戳进行转换
                av_packet_rescale_ts(in_pkt2, srcstream2->time_base, dststream->time_base);
            } else {
                // 由于源文件和目的文件的时间基可能不一样，所以这里要将时间戳进行转换
                av_packet_rescale_ts(in_pkt2, srcstream->time_base, dststream->time_base);
            }
            // 更正目标流的索引
            in_pkt2->stream_index = video_ou_index;
        }
        
        // 音频流
        if (in_pkt2->stream_index == audio2_in_index) {
            if (in_pkt2->pts == AV_NOPTS_VALUE) {
                in_pkt2->pts = in_pkt2->dts;
            }
            if (in_pkt2->dts == AV_NOPTS_VALUE) {
                in_pkt2->dts = in_pkt2->pts;
            }
            AVStream *srcstream = in_fmt2->streams[in_pkt2->stream_index];
            AVStream *dststream = ou_fmt->streams[audio_ou_index];
            if (next_audio_pts > 0) {
                AVStream *srcstream2 = in_fmt1->streams[audio1_in_index];
                in_pkt2->pts = av_rescale_q(in_pkt2->pts, srcstream->time_base, srcstream2->time_base) + next_audio_pts;
                in_pkt2->dts = av_rescale_q(in_pkt2->dts, srcstream->time_base, srcstream2->time_base) + next_audio_pts;
                in_pkt2->duration = av_rescale_q(in_pkt2->duration, srcstream->time_base, srcstream2->time_base);
                // 由于源文件和目的文件的时间基可能不一样，所以这里要将时间戳进行转换
                av_packet_rescale_ts(in_pkt2, srcstream2->time_base, dststream->time_base);
            } else {
                // 由于源文件和目的文件的时间基可能不一样，所以这里要将时间戳进行转换
                av_packet_rescale_ts(in_pkt2, srcstream->time_base, dststream->time_base);
            }
            // 更正目标流的索引
            in_pkt2->stream_index = audio_ou_index;
        }
        
        // 向封装器中写入数据
        if(av_write_frame(ou_fmt, in_pkt2) < 0) {

            return;
        }
        
        av_packet_unref(in_pkt2);
    }
    
    // 写入文件尾部信息
    av_write_trailer(ou_fmt);
}

@end
