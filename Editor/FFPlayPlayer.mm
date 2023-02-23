//
//  FFPlayPlayer.m
//  Editor
//
//  Created by zouran on 2022/12/16.
//

#import "FFPlayPlayer.h"
#import "FFPlayHeader.h"
#import <pthread.h>
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
    
#ifdef __cplusplus
};
#endif


@interface FFPlayPlayer() {
    pthread_mutex_t self_mutex;
}
@end

@implementation FFPlayPlayer

- (void)begin {
    VideoState      *is;
    pthread_mutex_init(&self_mutex, NULL);
    is = (VideoState *)av_mallocz(sizeof(VideoState));
    const char* filePath = [[[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"] UTF8String];
    strlcpy(is->filename, filePath, sizeof(is->filename));
    
    pthread_mutex_init(&is->pictq_mutex, NULL);
    is->pictq_cond = [[NSCondition alloc] init];
    
    is->av_sync_type = DEFAULT_AV_SYNC_TYPE;
    // 开线程
    dispatch_queue_t queue2 = dispatch_queue_create("123", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue2, ^{
        demux_thread(is);
    });
    
    for(;;) {

      
//        video_refresh_timer(is);
      
    }
    
}

int demux_thread(void *arg) {

  int err_code;
  char errors[1024] = {0,};

  VideoState *is = (VideoState *)arg;
  AVFormatContext *pFormatCtx;
  AVPacket pkt1, *packet = &pkt1;

  int video_index = -1;
  int audio_index = -1;
  int i;

  is->videoStream=-1;
  is->audioStream=-1;

//  global_video_state = is;
    pFormatCtx = avformat_alloc_context();
  /* open input file, and allocate format context */
  if ((err_code=avformat_open_input(&pFormatCtx, is->filename, NULL, NULL)) < 0) {
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
    stream_component_open(is, audio_index);
  }
  if(video_index >= 0) {
    stream_component_open(is, video_index);
  }

  if(is->videoStream < 0 || is->audioStream < 0) {
    fprintf(stderr, "%s: could not open codecs\n", is->filename);
    goto fail;
  }

  for(;;) {
//      NSLog(@"demux_thread for");
    if(is->quit) {
      break;
    }
    // seek stuff goes here
    if(is->audioq.size > MAX_AUDIOQ_SIZE ||
       is->videoq.size > MAX_VIDEOQ_SIZE) {
//      SDL_Delay(10);
//      continue;
    }
    if(av_read_frame(is->pFormatCtx, packet) < 0) {
      if(is->pFormatCtx->pb->error == 0) {
//    SDL_Delay(100); /* no error; wait for user input */
    continue;
      } else {
    break;
      }
    }
    // Is this a packet from the video stream?
    if(packet->stream_index == is->videoStream) {
        NSLog(@"video packet_queue_put");
      packet_queue_put(&is->videoq, packet);
    } else if(packet->stream_index == is->audioStream) {
      packet_queue_put(&is->audioq, packet);
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
//    SDL_Event event;
//    event.type = FF_QUIT_EVENT;
//    event.user.data1 = is;
//    SDL_PushEvent(&event);
  }
  return 1;
}

int packet_queue_put(PacketQueue *q, AVPacket *pkt) {

  AVPacketList *pkt1;
  if(av_dup_packet(pkt) < 0) {
    return -1;
  }
  pkt1 = (AVPacketList *)av_malloc(sizeof(AVPacketList));
  if (!pkt1)
    return -1;
  pkt1->pkt = *pkt;
  pkt1->next = NULL;
  
//  SDL_LockMutex(q->mutex);
//    pthread_mutex_lock(&(q->mutex));

  if (!q->last_pkt)
    q->first_pkt = pkt1;
  else
    q->last_pkt->next = pkt1;
  q->last_pkt = pkt1;
  q->nb_packets++;
  q->size += pkt1->pkt.size;
//  SDL_CondSignal(q->cond);
    
//    dispatch_queue_t queue = dispatch_get_main_queue();
//    dispatch_async(queue, ^{
//        [q->cond signal];
//    });
  
//  SDL_UnlockMutex(q->mutex);
//    pthread_mutex_unlock(&(q->mutex));
  return 1;
}

int stream_component_open(VideoState *is, int stream_index) {

  AVFormatContext *pFormatCtx = is->pFormatCtx;
  AVCodecContext *codecCtx = NULL;
  AVCodec *codec = NULL;
//  SDL_AudioSpec wanted_spec, spec;

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

      // Set audio settings from codec info
//      wanted_spec.freq = codecCtx->sample_rate;
//      wanted_spec.format = AUDIO_S16SYS;
//      wanted_spec.channels = 2;//codecCtx->channels;
//      wanted_spec.silence = 0;
//      wanted_spec.samples = SDL_AUDIO_BUFFER_SIZE;
//      wanted_spec.callback = audio_callback;
//      wanted_spec.userdata = is;
//
//      fprintf(stderr, "wanted spec: channels:%d, sample_fmt:%d, sample_rate:%d \n",
//            2, AUDIO_S16SYS, codecCtx->sample_rate);
//
//      if(SDL_OpenAudio(&wanted_spec, &spec) < 0) {
//          fprintf(stderr, "SDL_OpenAudio: %s\n", SDL_GetError());
//          return -1;
//      }
//      is->audio_hw_buf_size = spec.size;
  }

  if(avcodec_open2(codecCtx, codec, NULL) < 0) {
    fprintf(stderr, "Unsupported codec!\n");
    return -1;
  }

    switch(codecCtx->codec_type) {
        case AVMEDIA_TYPE_AUDIO:
        {
            is->audioStream = stream_index;
            is->audio_st = pFormatCtx->streams[stream_index];
            is->audio_ctx = codecCtx;
            is->audio_buf_size = 0;
            is->audio_buf_index = 0;
            memset(&is->audio_pkt, 0, sizeof(is->audio_pkt));
            packet_queue_init(&is->audioq);
            
            //Out Audio Param
            uint64_t out_channel_layout=AV_CH_LAYOUT_STEREO;
            
            //AAC:1024  MP3:1152
            int out_nb_samples= is->audio_ctx->frame_size;
            //AVSampleFormat out_sample_fmt = AV_SAMPLE_FMT_S16;
            
            int out_sample_rate=is->audio_ctx->sample_rate;
            int out_channels=av_get_channel_layout_nb_channels(out_channel_layout);
            //Out Buffer Size
            /*
             int out_buffer_size=av_samples_get_buffer_size(NULL,
             out_channels,
             out_nb_samples,
             AV_SAMPLE_FMT_S16,
             1);
             */
            
            //uint8_t *out_buffer=(uint8_t *)av_malloc(MAX_AUDIO_FRAME_SIZE*2);
            int64_t in_channel_layout=av_get_default_channel_layout(is->audio_ctx->channels);
            
            struct SwrContext *audio_convert_ctx;
            audio_convert_ctx = swr_alloc();
            swr_alloc_set_opts(audio_convert_ctx,
                               out_channel_layout,
                               AV_SAMPLE_FMT_S16,
                               out_sample_rate,
                               in_channel_layout,
                               is->audio_ctx->sample_fmt,
                               is->audio_ctx->sample_rate,
                               0,
                               NULL);
            fprintf(stderr, "swr opts: out_channel_layout:%lld, out_sample_fmt:%d, out_sample_rate:%d, in_channel_layout:%lld, in_sample_fmt:%d, in_sample_rate:%d",
                    out_channel_layout, AV_SAMPLE_FMT_S16, out_sample_rate, in_channel_layout, is->audio_ctx->sample_fmt, is->audio_ctx->sample_rate);
            swr_init(audio_convert_ctx);
            
            is->audio_swr_ctx = audio_convert_ctx;
            
            //    SDL_PauseAudio(0);
            break;
        }
        case AVMEDIA_TYPE_VIDEO:
        {
            is->videoStream = stream_index;
            is->video_st = pFormatCtx->streams[stream_index];
            is->video_ctx = codecCtx;
            
            is->frame_timer = (double)av_gettime() / 1000000.0;
            is->frame_last_delay = 40e-3;
            is->video_current_pts_time = av_gettime();
            
            packet_queue_init(&is->videoq);
            is->video_sws_ctx = sws_getContext(is->video_ctx->width, is->video_ctx->height,
                                               is->video_ctx->pix_fmt, is->video_ctx->width,
                                               is->video_ctx->height, AV_PIX_FMT_YUV420P,
                                               SWS_BILINEAR, NULL, NULL, NULL
                                               );
            
            dispatch_queue_t queue2 = dispatch_queue_create("123456", DISPATCH_QUEUE_CONCURRENT);
            dispatch_async(queue2, ^{
                decode_video_thread(is);
            });
            
            break;
        }
        default:
            break;
    }
    return 1;
}

int decode_video_thread(void *arg) {
  VideoState *is = (VideoState *)arg;
  AVPacket pkt1, *packet = &pkt1;
  int frameFinished = 0;
  AVFrame *pFrame;
  double pts;

  pFrame = av_frame_alloc();

    while (av_read_frame(is->pFormatCtx,packet)>=0) {
      NSLog(@"decode_video_thread get");
      
    if(packet_queue_get(&is->videoq, packet, 1) < 0) {
      // means we quit getting packets
      break;
    }
    pts = 0;

    // Decode video frame
//    avcodec_decode_video2(is->video_ctx, pFrame, &frameFinished, packet);
      
      avcodec_send_packet(is->video_ctx, packet);
      int video_decode_result = avcodec_receive_frame(is->video_ctx, pFrame);
      if (video_decode_result == 0) {
          
          if((pts = pFrame->pts) != AV_NOPTS_VALUE) {
              
          } else {
            pts = 0;
          }
          pts *= av_q2d(is->video_st->time_base);
            
            NSLog(@"pts------%f",pts);

          // Did we get a video frame?
//          if(frameFinished) {
//            pts = synchronize_video(is, pFrame, pts);
//            if(queue_picture(is, pFrame, pts) < 0) {
//          break;
//            }
//          }
      } else {
          NSLog(@"avcodec_receive_frame error-----");
      }

    
    av_packet_unref(packet);
  }
  av_frame_free(&pFrame);
  return 1;
}

void alloc_picture(void *userdata) {

  int ret;

  VideoState *is = (VideoState *)userdata;
  VideoPicture *vp;

  vp = &is->pictq[is->pictq_windex];
  if(vp->bmp) {

    // we already have one make another, bigger/smaller
    avpicture_free(vp->bmp);
    free(vp->bmp);

    vp->bmp = NULL;
  }

  // Allocate a place to put our YUV image on that screen
//  SDL_LockMutex(text_mutex);

  vp->bmp = (AVPicture*)malloc(sizeof(AVPicture));
  ret = avpicture_alloc(vp->bmp, AV_PIX_FMT_YUV420P, is->video_ctx->width, is->video_ctx->height);
  if (ret < 0) {
      fprintf(stderr, "Could not allocate temporary picture: %s\n", av_err2str(ret));
  }

//  SDL_UnlockMutex(text_mutex);

  vp->width = is->video_ctx->width;
  vp->height = is->video_ctx->height;
  vp->allocated = 1;

}

int queue_picture(VideoState *is, AVFrame *pFrame, double pts) {

  VideoPicture *vp;

  /* wait until we have space for a new pic */
//  SDL_LockMutex(is->pictq_mutex);
    pthread_mutex_lock(&(is->pictq_mutex));
  while(is->pictq_size >= VIDEO_PICTURE_QUEUE_SIZE &&
    !is->quit) {
//    SDL_CondWait(is->pictq_cond, is->pictq_mutex);
//      [is->pictq_cond wait];
  }
//  SDL_UnlockMutex(is->pictq_mutex);
    pthread_mutex_unlock(&(is->pictq_mutex));

  if(is->quit)
    return -1;

  // windex is set to 0 initially
  vp = &is->pictq[is->pictq_windex];

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
    sws_scale(is->video_sws_ctx, (uint8_t const * const *)pFrame->data,
          pFrame->linesize, 0, is->video_ctx->height,
          vp->bmp->data, vp->bmp->linesize);
   
    /* now we inform our display thread that we have a pic ready */
    if(++is->pictq_windex == VIDEO_PICTURE_QUEUE_SIZE) {
      is->pictq_windex = 0;
    }

//    SDL_LockMutex(is->pictq_mutex);
      pthread_mutex_lock(&(is->pictq_mutex));
    is->pictq_size++;
//    SDL_UnlockMutex(is->pictq_mutex);
      pthread_mutex_unlock(&(is->pictq_mutex));
  }
  return 1;
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

void packet_queue_init(PacketQueue *q) {
  memset(q, 0, sizeof(PacketQueue));
//  q->mutex = SDL_CreateMutex();
//    pthread_mutex_t
//  q->cond = SDL_CreateCond();
    
    pthread_mutex_init(&q->mutex, NULL);
    q->cond = [[NSCondition alloc] init];
}

int packet_queue_get(PacketQueue *q, AVPacket *pkt, int block)
{
    NSLog(@"main thread %d",[NSThread isMainThread]);
  AVPacketList *pkt1;
  int ret;

//  SDL_LockMutex(q->mutex);
    pthread_mutex_lock(&(q->mutex));
  
  for(;;) {
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
//      SDL_CondWait(q->cond, q->mutex);
//        [q->cond wait];
    }
  }
//  SDL_UnlockMutex(q->mutex);
    pthread_mutex_unlock(&(q->mutex));
  return ret;
}

void video_refresh_timer(void *userdata) {

  VideoState *is = (VideoState *)userdata;
  VideoPicture *vp;
  double actual_delay, delay, sync_threshold, ref_clock, diff;
  
  if(is->video_st) {
    if(is->pictq_size == 0) {
//      schedule_refresh(is, 1);
      //fprintf(stderr, "no picture in the queue!!!\n");
    } else {
      //fprintf(stderr, "get picture from queue!!!\n");
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
//      schedule_refresh(is, (int)(actual_delay * 1000 + 0.5));
      
      /* show the picture! */
      video_display(is);
      
      /* update queue for next picture! */
      if(++is->pictq_rindex == VIDEO_PICTURE_QUEUE_SIZE) {
    is->pictq_rindex = 0;
      }
//      SDL_LockMutex(is->pictq_mutex);
        pthread_mutex_lock(&(is->pictq_mutex));
      is->pictq_size--;
//      SDL_CondSignal(is->pictq_cond);
//      SDL_UnlockMutex(is->pictq_mutex);
        pthread_mutex_unlock(&(is->pictq_mutex));
    }
  } else {
//    schedule_refresh(is, 100);
  }
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

void video_display(VideoState *is) {

  
  VideoPicture *vp;
  float aspect_ratio;
  int w, h, x, y;
  int i;
    
    

  vp = &is->pictq[is->pictq_rindex];
  if(vp->bmp) {

    

  }
}

@end
