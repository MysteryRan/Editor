//
//  FFMpegTool.h
//  ffmpegDemo
//
//  Created by zouran on 2022/11/25.
//

#import <Foundation/Foundation.h>
// FFmpeg Header File
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

#import "MediaInfo.h"

#define STREAM_DURATION   10.0
#define STREAM_FRAME_RATE 25 /* 25 images/s */
#define STREAM_PIX_FMT    AV_PIX_FMT_YUV420P /* default pix_fmt */

#define SCALE_FLAGS SWS_BICUBIC



NS_ASSUME_NONNULL_BEGIN
@interface FFMpegTool : NSObject

+ (int)exportAblumPhoto:(const char *)fromPath toPath:(const char *)path;

+ (MediaInfo *)openStreamFunc:(NSString *)path;


+ (void)copytest;

+ (int)replaceAudio;

+ (void)mutilAudio;
+ (int)addnormaladd;

int
rrmain(int argc, char **argv);

-(int)add_bgm_to_video:(const char *)output_filename with:(const char *)input_filename with:(const char *)bgm_filename with:(float)bgm_volume;

+(void)MergeTwo:(NSString *) srcPath1 with:(NSString *)srcPath2 with:(NSString *)dstPath;

- (int)otherexport:(NSString *)in_filename oo:(NSString *)out_filename;

+ (int)hevcexport:(const char *)in_filename toPath:(const char *)out_filename;

@end

NS_ASSUME_NONNULL_END
