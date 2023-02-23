//
//  EditorConvertUtil.m
//  Editor
//
//  Created by zouran on 2022/12/20.
//

#import "EditorConvertUtil.h"
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
#include "libavutil/timestamp.h"
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/opt.h>
    
#ifdef __cplusplus
};
#endif

@implementation EditorConvertUtil

+ (NSDictionary* _Nullable)_prepareCVPixelBufferAttibutes:(const int)format fullRange:(const bool)fullRange h:(const int)h w:(const int)w
{
    //CoreVideo does not provide support for all of these formats; this list just defines their names.
    int pixelFormatType = 0;
    
    if (format == AV_PIX_FMT_RGB24) {
        pixelFormatType = kCVPixelFormatType_24RGB;
    } else if (format == AV_PIX_FMT_ARGB || format == AV_PIX_FMT_0RGB) {
        pixelFormatType = kCVPixelFormatType_32ARGB;
    } else if (format == AV_PIX_FMT_NV12 || format == AV_PIX_FMT_NV21) {
        pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        //for AV_PIX_FMT_NV21: later will swap VU. we won't modify the avframe data, because the frame can be dispaly again!
    } else if (format == AV_PIX_FMT_BGRA || format == AV_PIX_FMT_BGR0) {
        pixelFormatType = kCVPixelFormatType_32BGRA;
    } else if (format == AV_PIX_FMT_YUV420P) {
        pixelFormatType = fullRange ? kCVPixelFormatType_420YpCbCr8PlanarFullRange : kCVPixelFormatType_420YpCbCr8Planar;
    } else if (format == AV_PIX_FMT_NV16) {
        pixelFormatType = fullRange ? kCVPixelFormatType_422YpCbCr8BiPlanarFullRange : kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange;
    } else if (format == AV_PIX_FMT_UYVY422) {
        pixelFormatType = fullRange ? kCVPixelFormatType_422YpCbCr8FullRange : kCVPixelFormatType_422YpCbCr8;
    } else if (format == AV_PIX_FMT_YUV444P10) {
        pixelFormatType = kCVPixelFormatType_444YpCbCr10;
    } else if (format == AV_PIX_FMT_YUYV422) {
        pixelFormatType = kCVPixelFormatType_422YpCbCr8_yuvs;
    }
    //    RGB555 可以创建出 CVPixelBuffer，但是显示时失败了。
    //    else if (format == AV_PIX_FMT_RGB555BE) {
    //        pixelFormatType = kCVPixelFormatType_16BE555;
    //    } else if (format == AV_PIX_FMT_RGB555LE) {
    //        pixelFormatType = kCVPixelFormatType_16LE555;
    //    }
    else {
        NSAssert(NO,@"unsupported pixel format!");
        return nil;
    }
    
    const int linesize = 32;//FFmpeg 解码数据对齐是32，这里期望CVPixelBuffer也能使用32对齐，但实际来看却是64！
    NSMutableDictionary*attributes = [NSMutableDictionary dictionary];
    [attributes setObject:@(pixelFormatType) forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
    [attributes setObject:[NSNumber numberWithInt:w] forKey: (NSString*)kCVPixelBufferWidthKey];
    [attributes setObject:[NSNumber numberWithInt:h] forKey: (NSString*)kCVPixelBufferHeightKey];
    [attributes setObject:@(linesize) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
    [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
    return attributes;
}

+ (CVPixelBufferPoolRef _Nullable)createCVPixelBufferPoolRef:(const int)format w:(const int)w h:(const int)h fullRange:(const bool)fullRange
{
    NSDictionary * attributes = [self _prepareCVPixelBufferAttibutes:format fullRange:YES h:h w:w];
    if (!attributes) {
        return NULL;
    }
    
    CVPixelBufferPoolRef pixelBufferPool = NULL;
    if (kCVReturnSuccess != CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &pixelBufferPool)){
        NSLog(@"CVPixelBufferPoolCreate Failed");
        return NULL;
    } else {
        return (CVPixelBufferPoolRef)CFAutorelease((const void *)pixelBufferPool);
    }
}

+ (CVPixelBufferRef _Nullable)pixelBufferFromAVFrame:(AVFrame *)frame
                                                 opt:(CVPixelBufferPoolRef)poolRef
{
    if (NULL == frame) {
        return NULL;
    }
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = kCVReturnError;
    
    const int w = frame->width;
    const int h = frame->height;
    const int format = frame->format;
    
    if (poolRef) {
        result = CVPixelBufferPoolCreatePixelBuffer(NULL, poolRef, &pixelBuffer);
    } else {
        //AVCOL_RANGE_MPEG对应tv，AVCOL_RANGE_JPEG对应pc
        //Y′ values are conventionally shifted and scaled to the range [16, 235] (referred to as studio swing or "TV levels") rather than using the full range of [0, 255] (referred to as full swing or "PC levels").
        //https://en.wikipedia.org/wiki/YUV#Numerical_approximations
        
//        const bool fullRange = frame->color_range != AVCOL_RANGE_MPEG;
        const bool fullRange = YES;
        NSDictionary * attributes = [self _prepareCVPixelBufferAttibutes:format fullRange:fullRange h:h w:w];
        if (!attributes) {
            return NULL;
        }
        const int pixelFormatType = [attributes[(NSString*)kCVPixelBufferPixelFormatTypeKey] intValue];
        
        result = CVPixelBufferCreate(kCFAllocatorDefault,
                                     w,
                                     h,
                                     pixelFormatType,
                                     (__bridge CFDictionaryRef)(attributes),
                                     &pixelBuffer);
    }
    
    if (kCVReturnSuccess == result) {
        
        int planes = 1;
        if (CVPixelBufferIsPlanar(pixelBuffer)) {
            planes = (int)CVPixelBufferGetPlaneCount(pixelBuffer);
        }
        
        
        for (int p = 0; p < planes; p++) {
            CVPixelBufferLockBaseAddress(pixelBuffer,p);
            uint8_t *src = frame->data[p];
            uint8_t *dst = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, p);
            int src_linesize = (int)frame->linesize[p];
            int dst_linesize = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, p);
            int height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, p);
            int bytewidth = MIN(src_linesize, dst_linesize);
            av_image_copy_plane(dst, dst_linesize, src, src_linesize, bytewidth, height);
            CVPixelBufferUnlockBaseAddress(pixelBuffer, p);
            /*
            for (; height > 0; height--) {
                bzero(dest, dst_linesize);
                memcpy(dest, src, MIN(src_linesize, dst_linesize));
                src  += src_linesize;
                dest += dst_linesize;
            }
             */
            
            /**
             kCVReturnInvalidPixelFormat
             AV_PIX_FMT_BGR24,
             AV_PIX_FMT_ABGR,
             AV_PIX_FMT_0BGR,
             AV_PIX_FMT_RGBA,
             AV_PIX_FMT_RGB0,
             
             // 可以创建 pixelbuffer，但是构建的 CIImage 是 nil ！
             AV_PIX_FMT_RGB555BE,
             AV_PIX_FMT_RGB555LE,
             
             将FFmpeg解码后的YUV数据塞到CVPixelBuffer中，这里必须注意不能使用以下三种形式，否则将可能导致画面错乱或者绿屏或程序崩溃！
             memcpy(y_dest, y_src, w * h);
             memcpy(y_dest, y_src, aFrame->linesize[0] * h);
             memcpy(y_dest, y_src, CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) * h);
             
             原因是因为FFmpeg解码后的YUV数据的linesize大小是作了字节对齐的，所以视频的w和linesize[0]很可能不相等，同样的 CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) 也是作了字节对齐的，并且对齐大小跟FFmpeg的对齐大小可能也不一样，这就导致了最坏情况下这三个值都不等！我的一个测试视频的宽度是852，FFmpeg解码使用了32字节对齐后linesize【0】是 864，而 CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) 获取到的却是 896，通过计算得出使用的是 64 字节对齐的，所以上面三种 memcpy 的写法都不靠谱！
             【字节对齐】只是为了让CPU拷贝数据速度更快，由于对齐多出来的冗余字节不会用来显示，所以填 0 即可！目前来看FFmpeg使用32个字节做对齐，而CVPixelBuffer即使指定了32却还是使用64个字节做对齐！
             以下代码的意思是：
                按行遍历 CVPixelBuffer 的每一行；
                先把该行全部填 0 ，然后最大限度的将 FFmpeg 解码数据（包括对齐字节）copy 到 CVPixelBuffer 中；
                因为存在上面分析的对齐不相等问题，所以只能一行一行的处理，不能直接使用 memcpy 简单处理！
             
            for (; height > 0; height--) {
                bzero(dest, dst_linesize);
                memcpy(dest, src, MIN(src_linesize, dst_linesize));
                src  += src_linesize;
                dest += dst_linesize;
            }
            
            后来偶然间找到了 av_image_copy_plane 这个方法，其内部实现就是上面的按行 copy。
            */
        }
        return pixelBuffer;
    } else {
        return NULL;
    }
}

@end
