//
//  MR0x31FFMpegMovie.h
//  FFmpegTutorial-iOS
//
//  Created by zouran on 2022/10/26.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <GPUImage/GPUImage.h>

NS_ASSUME_NONNULL_BEGIN

@class MR0x31FFMpegMovie;
@protocol MR0x31FFMpegMovieDelegate <NSObject>

@optional

- (void)currenFFMpegtMovie:(MR0x31FFMpegMovie *)currentMovie time:(uint64_t)currentTime;

- (void)currenFFMpegtMovie:(MR0x31FFMpegMovie *)currentMovie decodeFinished:(BOOL)finished;

- (void)currenFFMpegtMovie:(MR0x31FFMpegMovie *)currentMovie decodeFinished:(BOOL)finished time:(uint64_t)currentTime;

@end

@interface MR0x31FFMpegMovie : GPUImageOutput

@property(nonatomic,weak)id <MR0x31FFMpegMovieDelegate> delegate;

@property (nonatomic, copy) NSString *filePath;

- (void)startEnable:(NSString *)path;

- (int)getMediaInfo:(NSString *)path;

- (int)remux;

- (void)starPicture:(NSString *)path;

- (int)cut_video:(double)from_seconds end:(double)end_seconds in_f:(const char*) in_filename out_f:(const char*)out_filename;

- (void)appendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut;

- (void)fullAppendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut;

@end

NS_ASSUME_NONNULL_END
