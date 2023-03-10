//
//  EditorFilterUtil.m
//  Editor
//
//  Created by zouran on 2023/3/10.
//

#import "EditorFilterUtil.h"
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
#include <libavutil/pixdesc.h>
#include "libavutil/timestamp.h"
//#include "libavformat/avformat.h"
//#include "libavcodec/avcodec.h"
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>

//#include <libavutil/channel_layout.h>
#include <libavutil/common.h>
#include <libavutil/frame.h>
#include <libavutil/samplefmt.h>


//#include <channel_layout.h>
    
#ifdef __cplusplus
};
#endif

@interface EditorFilterUtil() {
    
}

@property (nonatomic, strong)NSMutableArray *filters;

@end

@implementation EditorFilterUtil

+ (AVFrame *)fromFrame:(AVFrame *)frame volumeAdjust:(double)volumeMul {
    AVFilterGraph *filter_graph;
    //输出槽
    AVFilterContext *buffersink_ctx;
    //输入缓存1
    AVFilterContext *buffersrc1_ctx;
    
    const AVFilter *buffersrc = avfilter_get_by_name("abuffer");
    const AVFilter *buffersink = avfilter_get_by_name("abuffersink");

    int ret = 0;
    //创建滤镜容器
    filter_graph = avfilter_graph_alloc();
    if (!filter_graph) {
        ret = AVERROR(ENOMEM);
    }

    //声道布局

    //输入缓存1的配置
    NSString *configStr = @"sample_rate=44100:sample_fmt=8:channel_layout=stereo:channels=2:time_base=1/14112000";
    ret = avfilter_graph_create_filter(&buffersrc1_ctx, buffersrc, "in1",
                                       [configStr UTF8String], NULL, filter_graph);
    if (ret < 0)
    {
        
    }

    //创建输出
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
        NULL, NULL, filter_graph);
    if (ret < 0)
    {
        NSLog(@"fail fail");
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
         

    const AVFilter* volumeFilter = avfilter_get_by_name("volumedetect");
    AVFilterContext* volumeFilterCtx = NULL;
    
    configStr = @"";
    
    ret = avfilter_graph_create_filter(&volumeFilterCtx, volumeFilter, "volumedetect", [configStr UTF8String], NULL, filter_graph);
    ret = avfilter_link(buffersrc1_ctx, 0, volumeFilterCtx, 0);
    ret = avfilter_link(volumeFilterCtx, 0, buffersink_ctx, 0);
    ret = avfilter_graph_config(filter_graph, NULL);

    ret = av_buffersrc_add_frame_flags(buffersrc1_ctx, frame, AV_BUFFERSRC_FLAG_KEEP_REF);
    if (ret < 0) {
        
    }
    AVFrame *finalFrame = av_frame_alloc();
    ret = av_buffersink_get_frame(buffersink_ctx, finalFrame);
    if (ret < 0) {
        printf("33333909090 %s",av_err2str(ret));
    }
    return finalFrame;
}

+ (AVFrame *)fromFrame:(AVFrame *)frame speedAdjust:(double)speedMul {
    AVFilterGraph *filter_graph;
    //输出槽
    AVFilterContext *buffersink_ctx;
    //输入缓存1
    AVFilterContext *buffersrc1_ctx;
    
    const AVFilter *buffersrc = avfilter_get_by_name("abuffer");
    const AVFilter *buffersink = avfilter_get_by_name("abuffersink");

    int ret = 0;
    //创建滤镜容器
    filter_graph = avfilter_graph_alloc();
    if (!filter_graph) {
        ret = AVERROR(ENOMEM);
    }

    //声道布局

    //输入缓存1的配置
    NSString *configStr = @"sample_rate=44100:sample_fmt=8:channel_layout=stereo:channels=2:time_base=1/14112000";
    ret = avfilter_graph_create_filter(&buffersrc1_ctx, buffersrc, "in1",
                                       [configStr UTF8String], NULL, filter_graph);
    if (ret < 0)
    {
        
    }

    //创建输出
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
        NULL, NULL, filter_graph);
    if (ret < 0)
    {
        NSLog(@"fail fail");
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
         

    const AVFilter* volumeFilter = avfilter_get_by_name("atempo");
    AVFilterContext* volumeFilterCtx = avfilter_graph_alloc_filter(filter_graph, volumeFilter, "atempo");
    AVDictionary *args = NULL;
    av_dict_set(&args, "tempo", "5.0", 0);
    
    ret = avfilter_link(buffersrc1_ctx, 0, volumeFilterCtx, 0);
    ret = avfilter_link(volumeFilterCtx, 0, buffersink_ctx, 0);
    ret = avfilter_graph_config(filter_graph, NULL);

    ret = av_buffersrc_add_frame_flags(buffersrc1_ctx, frame, AV_BUFFERSRC_FLAG_KEEP_REF);
    AVFrame *finalFrame = av_frame_alloc();
    ret = av_buffersink_get_frame(buffersink_ctx, finalFrame);
    if (ret < 0) {
        printf("33333909090 %s",av_err2str(ret));
        return frame;
    }
    return finalFrame;
}

@end
