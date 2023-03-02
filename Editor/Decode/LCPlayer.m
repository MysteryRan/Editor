//
//  LCPlayer.m
//  Editor
//
//  Created by zouran on 2023/1/31.
//

#import "LCPlayer.h"
#import "GPUImage.h"
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

#import <pthread.h>
#import "EditorVideoScale.h"
#import "EditorConvertUtil.h"


#if LIBAVCODEC_VERSION_INT < AV_VERSION_INT(55,28,1)
#define av_frame_alloc avcodec_alloc_frame
#define av_frame_free avcodec_free_frame
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

#define DEFAULT_AV_SYNC_TYPE AV_SYNC_EXTERNAL_MASTER //AV_SYNC_VIDEO_MASTER

typedef struct VideoPicture {
  AVFrame *bmp;
  int width, height; /* source height & width */
  int allocated;
  double pts;
} VideoPicture;

typedef struct PacketQueue {
  AVPacketList *first_pkt, *last_pkt;
  int nb_packets;
  int size;
//  SDL_mutex *mutex;
  pthread_mutex_t mutex;
//  SDL_cond *cond;
  pthread_cond_t cond;
} PacketQueue;

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
    
    pthread_mutex_t pictq_mutex;
    
    pthread_cond_t pictq_cond;

  int             quit;
} VideoState;


enum {
  AV_SYNC_AUDIO_MASTER,
  AV_SYNC_VIDEO_MASTER,
  AV_SYNC_EXTERNAL_MASTER,
};



@interface LCPlayer() {
    VideoState *global_video_state;

    pthread_mutex_t text_mutex;

    bool selfPasued;
}

@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (nonatomic, strong) EditorVideoScale *videoScale;

@property (nonatomic, assign) BOOL pasued;

@property (nonatomic, copy)NSString *titttt;

@end

@implementation LCPlayer

void packet_queue_init(PacketQueue *q) {
  memset(q, 0, sizeof(PacketQueue));
//  q->mutex = SDL_CreateMutex();
//  q->cond = SDL_CreateCond();
    
    pthread_mutex_init(&(q->mutex),NULL);
    pthread_cond_init(&(q->cond),NULL);
}

- (int)packet_queue_put:(PacketQueue *)q withPkt:(AVPacket *)pkt {
    AVPacketList *pkt1;
    if(av_packet_make_refcounted(pkt) < 0) {
      return -1;
    }
    pkt1 = av_malloc(sizeof(AVPacketList));
    if (!pkt1)
      return -1;
    pkt1->pkt = *pkt;
    pkt1->next = NULL;
    
      pthread_mutex_lock(&q->mutex);

    if (!q->last_pkt)
      q->first_pkt = pkt1;
    else
      q->last_pkt->next = pkt1;
    q->last_pkt = pkt1;
    q->nb_packets++;
    q->size += pkt1->pkt.size;
      pthread_cond_signal(&(q->cond));
      pthread_mutex_unlock(&(q->mutex));
    return 0;
}

/*
int packet_queue_put(PacketQueue *q, AVPacket *pkt) {

  AVPacketList *pkt1;
  if(av_packet_make_refcounted(pkt) < 0) {
    return -1;
  }
  pkt1 = av_malloc(sizeof(AVPacketList));
  if (!pkt1)
    return -1;
  pkt1->pkt = *pkt;
  pkt1->next = NULL;
  
//  SDL_LockMutex(q->mutex);
    pthread_mutex_lock(&q->mutex);

  if (!q->last_pkt)
    q->first_pkt = pkt1;
  else
    q->last_pkt->next = pkt1;
  q->last_pkt = pkt1;
  q->nb_packets++;
  q->size += pkt1->pkt.size;
//  SDL_CondSignal(q->cond);
    pthread_cond_signal(&(q->cond));
//  SDL_UnlockMutex(q->mutex);
    pthread_mutex_unlock(&(q->mutex));
  return 0;
}
 */

- (int)packet_queue_get:(PacketQueue *)q withPkt:(AVPacket *)pkt withB:(int)block {
    AVPacketList *pkt1;
    int ret;

      pthread_mutex_lock(&(q->mutex));
      
    
    for(;;) {
      
        if(global_video_state->quit) {
        ret = -1;
        break;
      }

      pkt1 = q->first_pkt;
      if (pkt1) {
        q->first_pkt = pkt1->next;
        if (!q->first_pkt)
      q->last_pkt = NULL;
        q->nb_packets--;
        q->size -= pkt1->pkt.size;
        *pkt = pkt1->pkt;
        av_free(pkt1);
        ret = 1;
        break;
      } else if (!block) {
        ret = 0;
        break;
      } else {
          
          pthread_cond_wait(&(q->cond), &(q->mutex));
      }
    }

    pthread_mutex_unlock(&(q->mutex));
    return ret;
}

double get_audio_clock(VideoState *is) {
  double pts;
  int hw_buf_size, bytes_per_sec, n;
  
  pts = is->audio_clock; /* maintained in the audio thread */
  hw_buf_size = is->audio_buf_size - is->audio_buf_index;
  bytes_per_sec = 0;
  n = is->audio_ctx->channels * 2;
  if(is->audio_st) {
    bytes_per_sec = is->audio_ctx->sample_rate * n;
  }
  if(bytes_per_sec) {
    pts -= (double)hw_buf_size / bytes_per_sec;
  }
  return pts;
}
double get_video_clock(VideoState *is) {
  double delta;

  delta = (av_gettime() - is->video_current_pts_time) / 1000000.0;
  return is->video_current_pts + delta;
}
double get_external_clock(VideoState *is) {
  return av_gettime() / 1000000.0;
}

double get_master_clock(VideoState *is) {
  if(is->av_sync_type == AV_SYNC_VIDEO_MASTER) {
    return get_video_clock(is);
  } else if(is->av_sync_type == AV_SYNC_AUDIO_MASTER) {
    return get_audio_clock(is);
  } else {
    return get_external_clock(is);
  }
}


/* Add or subtract samples to get a better sync, return new
   audio buffer size */
int synchronize_audio(VideoState *is, short *samples,
              int samples_size, double pts) {
  int n;
  double ref_clock;

  n = 2 * is->audio_ctx->channels;
  
  if(is->av_sync_type != AV_SYNC_AUDIO_MASTER) {
    double diff, avg_diff;
    int wanted_size, min_size, max_size /*, nb_samples */;
    
    ref_clock = get_master_clock(is);
    diff = get_audio_clock(is) - ref_clock;

    if(diff < AV_NOSYNC_THRESHOLD) {
      // accumulate the diffs
      is->audio_diff_cum = diff + is->audio_diff_avg_coef
    * is->audio_diff_cum;
      if(is->audio_diff_avg_count < AUDIO_DIFF_AVG_NB) {
    is->audio_diff_avg_count++;
      } else {
    avg_diff = is->audio_diff_cum * (1.0 - is->audio_diff_avg_coef);
    if(fabs(avg_diff) >= is->audio_diff_threshold) {
      wanted_size = samples_size + ((int)(diff * is->audio_ctx->sample_rate) * n);
      min_size = samples_size * ((100 - SAMPLE_CORRECTION_PERCENT_MAX) / 100);
      max_size = samples_size * ((100 + SAMPLE_CORRECTION_PERCENT_MAX) / 100);
      if(wanted_size < min_size) {
        wanted_size = min_size;
      } else if (wanted_size > max_size) {
        wanted_size = max_size;
      }
      if(wanted_size < samples_size) {
        /* remove samples */
        samples_size = wanted_size;
      } else if(wanted_size > samples_size) {
        uint8_t *samples_end, *q;
        int nb;

        /* add samples by copying final sample*/
        nb = (samples_size - wanted_size);
        samples_end = (uint8_t *)samples + samples_size - n;
        q = samples_end + n;
        while(nb > 0) {
          memcpy(q, samples_end, n);
          q += n;
          nb -= n;
        }
        samples_size = wanted_size;
      }
    }
      }
    } else {
      /* difference is TOO big; reset diff stuff */
      is->audio_diff_avg_count = 0;
      is->audio_diff_cum = 0;
    }
  }
  return samples_size;
}

int audio_decode_frame(VideoState *is, uint8_t *audio_buf, int buf_size, double *pts_ptr) {

  int len1, data_size = 0;
  AVPacket *pkt = &is->audio_pkt;
  double pts;
  int n;


  for(;;) {
    while(is->audio_pkt_size > 0) {
      int got_frame = 0;
      len1 = avcodec_decode_audio4(is->audio_ctx, &is->audio_frame, &got_frame, pkt);
      if(len1 < 0) {
    /* if error, skip frame */
    is->audio_pkt_size = 0;
    break;
      }
      data_size = 0;
      if(got_frame) {
        /*
    data_size = av_samples_get_buffer_size(NULL,
                           is->audio_ctx->channels,
                           is->audio_frame.nb_samples,
                           is->audio_ctx->sample_fmt,
                           1);
        */
        data_size = 2 * is->audio_frame.nb_samples * 2;
    assert(data_size <= buf_size);

        swr_convert(is->audio_swr_ctx,
                        &audio_buf,
                        MAX_AUDIO_FRAME_SIZE*3/2,
                        (const uint8_t **)is->audio_frame.data,
                        is->audio_frame.nb_samples);

//        fwrite(audio_buf, 1, data_size, audiofd);
    //memcpy(audio_buf, is->audio_frame.data[0], data_size);
      }
      is->audio_pkt_data += len1;
      is->audio_pkt_size -= len1;
      if(data_size <= 0) {
    /* No data yet, get more frames */
    continue;
      }
      pts = is->audio_clock;
      *pts_ptr = pts;
      n = 2 * is->audio_ctx->channels;
      is->audio_clock += (double)data_size /
    (double)(n * is->audio_ctx->sample_rate);
      /* We have data, return it and come back for more later */
      return data_size;
    }
    if(pkt->data)
      av_free_packet(pkt);

    if(is->quit) {
      return -1;
    }
    /* next packet */
//    if(packet_queue_get(&is->audioq, pkt, 1) < 0) {
//      return -1;
//    }
    is->audio_pkt_data = pkt->data;
    is->audio_pkt_size = pkt->size;
    /* if update, update the audio clock w/pts */
    if(pkt->pts != AV_NOPTS_VALUE) {
      is->audio_clock = av_q2d(is->audio_st->time_base)*pkt->pts;
    }
  }
}

void audio_callback(void *userdata, UInt8 *stream, int len) {

  VideoState *is = (VideoState *)userdata;
  int len1, audio_size;
  double pts;


  while(len > 0) {
    if(is->audio_buf_index >= is->audio_buf_size) {
      /* We have already sent all our data; get more */
      audio_size = audio_decode_frame(is, is->audio_buf, sizeof(is->audio_buf), &pts);
      if(audio_size < 0) {
    /* If error, output silence */
    is->audio_buf_size = 1024 * 2 * 2;
    memset(is->audio_buf, 0, is->audio_buf_size);
      } else {
    audio_size = synchronize_audio(is, (int16_t *)is->audio_buf,
                       audio_size, pts);
    is->audio_buf_size = audio_size;
      }
      is->audio_buf_index = 0;
    }
    len1 = is->audio_buf_size - is->audio_buf_index;
    if(len1 > len)
      len1 = len;
  }
}

- (void)scheduleRefresh:(int)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delay / 1000.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self videoRefreshTimer];
    });
}
- (void)videoDisplay {
    if (selfPasued) {
        return;
    }
    VideoPicture *vp;

    vp = &global_video_state->pictq[global_video_state->pictq_rindex];
    if(vp->bmp) {
//        NSLog(@"video pts %lld",vp->bmp->pts);
        AVFrame *outP = nil;
        if (self.videoScale) {
            if (![self.videoScale rescaleFrame:vp->bmp out:&outP]) {
                return;
            }
        }

        runSynchronouslyOnVideoProcessingQueue(^{
            CVPixelBufferRef buf = [self pixelBufferFromAVFrame:outP];
            
            
            double tsff = av_q2d(self->global_video_state->video_st->time_base) * vp->bmp->pts;
            int64_t ttssee = tsff * AV_TIME_BASE;
            
            CMSampleTimingInfo sampleTime = {
                .presentationTimeStamp  = CMTimeMake(ttssee, 1),
                .decodeTimeStamp        = CMTimeMake(ttssee, 1),
            };
            
            CMSampleBufferRef samplebuffer = [self createSampleBufferFromPixelbuffer:buf
                                                                            videoRotate:0
                                                                             timingInfo:sampleTime];
            
            CVPixelBufferRelease(buf);
            if (self.delegate && [self.delegate respondsToSelector:@selector(reveiveFrameToRenderer:)] && samplebuffer) {
                [self.delegate reveiveFrameToRenderer:samplebuffer];
            }
        });
    }
}

- (CMSampleBufferRef)createSampleBufferFromPixelbuffer:(CVImageBufferRef)pixelBuffer videoRotate:(int)videoRotate timingInfo:(CMSampleTimingInfo)timingInfo {
    if (!pixelBuffer) {
        return NULL;
    }
    
    CVPixelBufferRef final_pixelbuffer = pixelBuffer;
    CMSampleBufferRef samplebuffer = NULL;
    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, final_pixelbuffer, &videoInfo);
    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, final_pixelbuffer, true, NULL, NULL, videoInfo, &timingInfo, &samplebuffer);
    
    if (videoInfo != NULL) {
        CFRelease(videoInfo);
    }
    
    if (samplebuffer == NULL || status != noErr) {
        return NULL;
    }
    
    return samplebuffer;
}
      
void alloc_picture(void *userdata) {
    int ret = 0;
    VideoState *is = (VideoState *)userdata;
    VideoPicture *vp;
    vp = &is->pictq[is->pictq_windex];
    vp->width = is->video_ctx->width;
    vp->height = is->video_ctx->height;
    vp->allocated = 1;
}

int queue_picture(VideoState *is, AVFrame *pFrame, double pts) {

    VideoPicture *vp;

  /* wait until we have space for a new pic */
//  SDL_LockMutex(is->pictq_mutex);
    pthread_mutex_lock(&(is->pictq_mutex));
//    NSLog(@"ooo count %d",is->pictq_size);
  while(is->pictq_size >= VIDEO_PICTURE_QUEUE_SIZE &&
    !is->quit) {
//      NSLog(@"while");
//    SDL_CondWait(is->pictq_cond, is->pictq_mutex);
      pthread_cond_wait(&(is->pictq_cond), &(is->pictq_mutex));
  }
//  SDL_UnlockMutex(is->pictq_mutex);
    pthread_mutex_unlock(&(is->pictq_mutex));

  if(is->quit)
    return -1;

  // windex is set to 0 initially
  vp = &is->pictq[is->pictq_windex];
    vp->bmp = pFrame;

  /* allocate or resize the buffer! */
  if(!vp->bmp ||
     vp->width != is->video_ctx->width ||
     vp->height != is->video_ctx->height) {

    vp->allocated = 0;
    alloc_picture(is);
    if(is->quit) {
      return -1;
    }
  }
  
  /* We have a place to put our picture on the queue */
  if(vp->bmp) {

    vp->pts = pts;
    
    // Convert the image into YUV format that SDL uses
//    sws_scale(is->video_sws_ctx, (uint8_t const * const *)pFrame->data,
//          pFrame->linesize, 0, is->video_ctx->height,
//          vp->bmp->data, vp->bmp->linesize);
   
    /* now we inform our display thread that we have a pic ready */
    if(++is->pictq_windex == VIDEO_PICTURE_QUEUE_SIZE) {
      is->pictq_windex = 0;
    }

      pthread_mutex_lock(&(is->pictq_mutex));
      
    is->pictq_size++;
      pthread_mutex_unlock(&(is->pictq_mutex));

  }
  return 0;
}

double synchronize_video(VideoState *is, AVFrame *src_frame, double pts) {

  double frame_delay;

  if(pts != 0) {
    /* if we have pts, set video clock to it */
    is->video_clock = pts;
  } else {
    /* if we aren't given a pts, set it to the clock */
    pts = is->video_clock;
  }
  /* update the video clock */
  frame_delay = av_q2d(is->video_ctx->time_base);
  /* if we are repeating a frame, adjust clock accordingly */
  frame_delay += src_frame->repeat_pict * (frame_delay * 0.5);
  is->video_clock += frame_delay;
  return pts;
}

- (void)decodeVideoThread:(VideoState *)arg {
    VideoState *is = (VideoState *)arg;
    AVPacket pkt1, *packet = &pkt1;
    int frameFinished;
    AVFrame *pFrame;
    double pts;

    pFrame = av_frame_alloc();

    for(;;) {
        if (selfPasued) {
            
        } else {
            
            if([self packet_queue_get:&is->videoq withPkt:packet withB:1] < 0) {
              // means we quit getting packets
              break;
            }
            pts = 0;

            // Decode video frame
        //    avcodec_decode_video2(is->video_ctx, pFrame, &frameFinished, packet);
              
              
              if (avcodec_send_packet(is->video_ctx,packet) != 0){
                         
                     }

              int framew = avcodec_receive_frame(is->video_ctx,pFrame);
                    
              

            if((pts = pFrame->best_effort_timestamp) != AV_NOPTS_VALUE) {
                
            } else {
              pts = 0;
            }
            pts *= av_q2d(is->video_st->time_base);
            
            if (pts > 3) {
//                return;
            }

              if (framew == 0){
                  pts = synchronize_video(is, pFrame, pts);
//                    NSLog(@"video pts %f",pts);
                    if(queue_picture(is, pFrame, pts) < 0) {
                        break;
                    }
              }
              
            // Did we get a video frame?
        //    if(frameFinished) {
        //      if (avcodec_receive_frame(is->video_ctx,pFrame) != 0){
        //
        //      }

        //      }
        //    }
              av_packet_unref(packet);
        }
    }
    av_frame_free(&pFrame);
}

- (int)streamComponentOpen:(VideoState *)is index:(int)stream_index {
    AVFormatContext *pFormatCtx = is->pFormatCtx;
    AVCodecContext *codecCtx = NULL;
    AVCodec *codec = NULL;

    if(stream_index < 0 || stream_index >= pFormatCtx->nb_streams) {
      return -1;
    }

    codecCtx = avcodec_alloc_context3(NULL);


    int ret = avcodec_parameters_to_context(codecCtx, pFormatCtx->streams[stream_index]->codecpar);
    if (ret < 0)
      return -1;

    codec = avcodec_find_decoder(codecCtx->codec_id);
    if(!codec) {
      fprintf(stderr, "Unsupported codec!\n");
      return -1;
    }


    if(codecCtx->codec_type == AVMEDIA_TYPE_AUDIO) {

        
    }

    if(avcodec_open2(codecCtx, codec, NULL) < 0) {
      fprintf(stderr, "Unsupported codec!\n");
      return -1;
    }

    switch(codecCtx->codec_type) {
    case AVMEDIA_TYPE_AUDIO:
      is->audioStream = stream_index;
      is->audio_st = pFormatCtx->streams[stream_index];
      is->audio_ctx = codecCtx;
      is->audio_buf_size = 0;
      is->audio_buf_index = 0;
      memset(&is->audio_pkt, 0, sizeof(is->audio_pkt));
      packet_queue_init(&is->audioq);

      //Out Audio Param
      break;
    case AVMEDIA_TYPE_VIDEO:
      is->videoStream = stream_index;
      is->video_st = pFormatCtx->streams[stream_index];
      is->video_ctx = codecCtx;
            
        self.videoScale = [self createVideoScaleIfNeed:codecCtx];

            
      is->frame_timer = (double)av_gettime() / 1000000.0;
      is->frame_last_delay = 40e-3;
      is->video_current_pts_time = av_gettime();

      packet_queue_init(&is->videoq);
  //    is->video_sws_ctx = sws_getContext(is->video_ctx->width, is->video_ctx->height,
  //                 is->video_ctx->pix_fmt, is->video_ctx->width,
  //                 is->video_ctx->height, AV_PIX_FMT_YUV420P,
  //                 SWS_BILINEAR, NULL, NULL, NULL
  //                 );
  //    is->video_tid = SDL_CreateThread(decode_video_thread, "decode_video_thread", is);
            
//            pthread_t decodeThread;
//            pthread_create(&decodeThread, NULL, decode_video_thread, is);
            
//            decode_video_thread(is);
        {
            dispatch_queue_t queue = dispatch_queue_create("decode",DISPATCH_QUEUE_SERIAL);
            dispatch_async(queue, ^{
                [self decodeVideoThread:is];
            });
        }
            
      break;
    default:
      break;
    }
      
      return 0;
}

- (void)appendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut {
    VideoState *is;
    is = av_mallocz(sizeof(VideoState));
    
    pthread_mutex_init(&text_mutex,NULL);
    pthread_mutex_init(&(is->pictq_mutex), NULL);
    pthread_cond_init(&(is->pictq_cond), NULL);

    [self scheduleRefresh:40];
    
    is->av_sync_type = DEFAULT_AV_SYNC_TYPE;
    
    dispatch_queue_t queue = dispatch_queue_create("demux",DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        [self demuxThread:is sourcePath:filePath];
    });
    
    dispatch_queue_t queue2 = dispatch_queue_create("videoRefresh",DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue2, ^{
        [self videoRefreshTimer];

    });
}

- (int)maintest {
    VideoState *is;
    is = av_mallocz(sizeof(VideoState));
    
    pthread_mutex_init(&text_mutex,NULL);
    pthread_mutex_init(&(is->pictq_mutex), NULL);
    pthread_cond_init(&(is->pictq_cond), NULL);

    [self scheduleRefresh:40];
    
    is->av_sync_type = DEFAULT_AV_SYNC_TYPE;
    
    dispatch_queue_t queue = dispatch_queue_create("demux",DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue, ^{
        [self demuxThread:is sourcePath:@""];
    });
    
    dispatch_queue_t queue2 = dispatch_queue_create("videoRefresh",DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue2, ^{
        [self videoRefreshTimer];

    });

return 0;

}

- (int)demuxThread:(VideoState *)state sourcePath:(NSString *)path {
    int err_code;
    char errors[1024] = {0,};

    VideoState *is = state;
    AVFormatContext *pFormatCtx =  avformat_alloc_context();
    AVPacket pkt1, *packet = &pkt1;

    int video_index = -1;
    int audio_index = -1;
    int i;

    is->videoStream=-1;
    is->audioStream=-1;
    
//    path = [[NSBundle mainBundle] pathForResource:@"640k" ofType:@"jpg"];

    global_video_state = is;
      
    /* open input file, and allocate format context */
    if ((err_code=avformat_open_input(&pFormatCtx, [path UTF8String], NULL, NULL)) < 0) {
        av_strerror(err_code, errors, 1024);
        fprintf(stderr, "Could not open source file %s, %d(%s)\n", is->filename, err_code, errors);
        return -1;
    }

    is->pFormatCtx = pFormatCtx;
    
    // Retrieve stream information
    if(avformat_find_stream_info(pFormatCtx, NULL)<0)
      return -1; // Couldn't find stream information
    
    // Dump information about file onto standard error
    av_dump_format(pFormatCtx, 0, is->filename, 0);
    
    // Find the first video stream

    for(i=0; i<pFormatCtx->nb_streams; i++) {
      if(pFormatCtx->streams[i]->codecpar->codec_type==AVMEDIA_TYPE_VIDEO &&
         video_index < 0) {
        video_index=i;
      }
      if(pFormatCtx->streams[i]->codecpar->codec_type==AVMEDIA_TYPE_AUDIO &&
         audio_index < 0) {
        audio_index=i;
      }
    }
    if(audio_index >= 0) {
//      stream_component_open(is, audio_index);
        [self streamComponentOpen:is index:audio_index];
    }
    if(video_index >= 0) {
//      stream_component_open(is, video_index);
        [self streamComponentOpen:is index:video_index];
    }

    if(is->videoStream < 0) {
      fprintf(stderr, "%s: could not open codecs\n", is->filename);
      goto fail;
    }

    //creat window from SDL
    


    // main decode loop

    for(;;) {
      if(is->quit) {
        break;
      }
      // seek stuff goes here
      if(is->videoq.size > MAX_VIDEOQ_SIZE) {
  //      SDL_Delay(10);
  //        av_usleep(10);
        continue;
      }
      if(av_read_frame(is->pFormatCtx, packet) < 0) {
        if(is->pFormatCtx->pb->error == 0) {
  //    SDL_Delay(100); /* no error; wait for user input */
  //        av_usleep(100);
            continue;
        } else {
            break;
        }
      }
      // Is this a packet from the video stream?
      if(packet->stream_index == is->videoStream) {
//        packet_queue_put(&is->videoq, packet);
          [self packet_queue_put:&is->videoq withPkt:packet];
      } else if(packet->stream_index == is->audioStream) {
//        packet_queue_put(&is->audioq, packet);
          [self packet_queue_put:&is->audioq withPkt:packet];
      } else {
          av_packet_unref(packet);
      }
    }
    /* all done - wait for it */
    while(!is->quit) {
  //    SDL_Delay(100);
    }

   fail:
    if(1){
      
    }
    return 0;
    
}

- (void)videoRefreshTimer {
    VideoState *is = global_video_state;
    VideoPicture *vp;
    double actual_delay, delay, sync_threshold, ref_clock, diff;
    
    if (!is) {
        return;
    }
    if(is->video_st) {
        if(is->pictq_size == 0) {
            [self scheduleRefresh:1];
        } else {
            vp = &is->pictq[is->pictq_rindex];
            is->video_current_pts = vp->pts;
            is->video_current_pts_time = av_gettime();
            delay = vp->pts - is->frame_last_pts; /* the pts from last time */
            if(delay <= 0 || delay >= 1.0) {
                /* if incorrect delay, use previous one */
                delay = is->frame_last_delay;
            }
            /* save for next time */
            is->frame_last_delay = delay;
            is->frame_last_pts = vp->pts;
            /* update delay to sync to audio if not master source */
            if(is->av_sync_type != AV_SYNC_VIDEO_MASTER) {
                ref_clock = get_master_clock(is);
                diff = vp->pts - ref_clock;
                /* Skip or repeat the frame. Take delay into account
                 FFPlay still doesn't "know if this is the best guess." */
                sync_threshold = (delay > AV_SYNC_THRESHOLD) ? delay : AV_SYNC_THRESHOLD;
                if(fabs(diff) < AV_NOSYNC_THRESHOLD) {
                    if(diff <= -sync_threshold) {
                        delay = 0;
                    } else if(diff >= sync_threshold) {
                        delay = 2 * delay;
                    }
                }
            }
            is->frame_timer += delay;
            /* computer the REAL delay */
            actual_delay = is->frame_timer - (av_gettime() / 1000000.0);
            if(actual_delay < 0.010) {
                /* Really it should skip the picture instead */
                actual_delay = 0.010;
            }
            [self scheduleRefresh:(actual_delay * 1000 + 0.5)];
            /* show the picture! */
            [self videoDisplay];
            /* update queue for next picture! */
            if(++is->pictq_rindex == VIDEO_PICTURE_QUEUE_SIZE) {
                is->pictq_rindex = 0;
            }
            pthread_mutex_lock(&(is->pictq_mutex));
            is->pictq_size--;
            pthread_cond_signal(&(is->pictq_cond));
            pthread_mutex_unlock(&(is->pictq_mutex));
        }
    } else {
        [self scheduleRefresh:100];
    }
}

- (void)stop {
    selfPasued = !selfPasued;
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


@end
