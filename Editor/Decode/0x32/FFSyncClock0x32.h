//
//  FFSyncClock0x32.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/8/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFSyncClock0x32 : NSObject

@property (nonatomic, assign) double pts;
@property (nonatomic, assign) double pts_drift;
@property (nonatomic, assign) double last_update;
@property (nonatomic, assign) double frame_timer;
//每个采样几个字节
@property (nonatomic, assign) int bytesPerSample;
@property (atomic, assign) BOOL eof;
@property (atomic, assign) BOOL paused;

- (void)setClock:(double)pts;
- (double)getClock;

@end

NS_ASSUME_NONNULL_END
