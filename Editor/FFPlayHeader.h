//
//  FFPlayHeader.h
//  Editor
//
//  Created by zouran on 2022/12/16.
//

#ifndef FFPlayHeader_h
#define FFPlayHeader_h

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
    
#ifdef __cplusplus
};
#endif

#define SDL_AUDIO_BUFFER_SIZE 1024
#define MAX_AUDIO_FRAME_SIZE 192000 //channels(2) * data_size(2) * sample_rate(48000)

#define MAX_AUDIOQ_SIZE (5 * 16 * 1024)
#define MAX_VIDEOQ_SIZE (5 * 256 * 1024)

#define AV_SYNC_THRESHOLD 0.01
#define AV_NOSYNC_THRESHOLD 10.0

#define SAMPLE_CORRECTION_PERCENT_MAX 10
#define AUDIO_DIFF_AVG_NB 20

#define FF_REFRESH_EVENT (SDL_USEREVENT)
#define FF_QUIT_EVENT (SDL_USEREVENT + 1)

#define VIDEO_PICTURE_QUEUE_SIZE 1

#define DEFAULT_AV_SYNC_TYPE AV_SYNC_AUDIO_MASTER //AV_SYNC_VIDEO_MASTER

typedef struct PacketQueue {
  AVPacketList *first_pkt, *last_pkt;
  int nb_packets;
  int size;
//  SDL_mutex *mutex;
//  SDL_cond *cond;
  pthread_mutex_t mutex;
  NSCondition *cond;
} PacketQueue;


typedef struct VideoPicture {
  AVPicture *bmp;
  int width, height; /* source height & width */
  int allocated;
  double pts;
} VideoPicture;

typedef struct VideoState {

  //multi-media file
  char            filename[1024];
  AVFormatContext *pFormatCtx;
  int             videoStream, audioStream;

  //sync
  int             av_sync_type;
  double          external_clock; /* external clock base */
  int64_t         external_clock_time;

  double          audio_diff_cum; /* used for AV difference average computation */
  double          audio_diff_avg_coef;
  double          audio_diff_threshold;
  int             audio_diff_avg_count;

  double          audio_clock;
  double          frame_timer;
  double          frame_last_pts;
  double          frame_last_delay;

  double          video_clock; ///<pts of last decoded frame / predicted pts of next decoded frame
  double          video_current_pts; ///<current displayed pts (different from video_clock if frame fifos are used)
  int64_t         video_current_pts_time;  ///<time (av_gettime) at which we updated video_current_pts - used to have running video pts

  //audio
  AVStream        *audio_st;
  AVCodecContext  *audio_ctx;
  PacketQueue     audioq;
  uint8_t         audio_buf[(MAX_AUDIO_FRAME_SIZE * 3) / 2];
  unsigned int    audio_buf_size;
  unsigned int    audio_buf_index;
  AVFrame         audio_frame;
  AVPacket        audio_pkt;
  uint8_t         *audio_pkt_data;
  int             audio_pkt_size;
  int             audio_hw_buf_size;

  //video
  AVStream        *video_st;
  AVCodecContext  *video_ctx;
  PacketQueue     videoq;
  struct SwsContext *video_sws_ctx;
  struct SwrContext *audio_swr_ctx;

  VideoPicture    pictq[VIDEO_PICTURE_QUEUE_SIZE];
  int             pictq_size, pictq_rindex, pictq_windex;
//  SDL_mutex       *pictq_mutex;
//  SDL_cond        *pictq_cond;
    pthread_mutex_t pictq_mutex;
    NSCondition *pictq_cond;
  
//  SDL_Thread      *parse_tid;
//  SDL_Thread      *video_tid;

  int             quit;
} VideoState;

//SDL_mutex    *text_mutex;
//SDL_Window   *win = NULL;
//SDL_Renderer *renderer;
//SDL_Texture  *texture;

enum {
  AV_SYNC_AUDIO_MASTER,
  AV_SYNC_VIDEO_MASTER,
  AV_SYNC_EXTERNAL_MASTER,
};







#endif /* FFPlayHeader_h */
