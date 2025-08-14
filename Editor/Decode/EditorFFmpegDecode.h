//
//  EditorFFmpegDecode.h
//  Editor
//
//  Created by zouran on 2022/12/20.
//

#import <Foundation/Foundation.h>
#import <GPUImage/GPUImage.h>

NS_ASSUME_NONNULL_BEGIN
@class EditorFFmpegDecode;
@protocol EditorFFmpegDecodeDelegate <NSObject>

@optional
- (void)reveiveFrameToRenderer:(CVPixelBufferRef)img;
- (void)clipCurrentTime:(int64_t)current withDecode:(EditorFFmpegDecode *)deocde;

@end

@interface EditorFFmpegDecode : GPUImageMovie

@property (nonatomic,assign) int64_t trimIn;
@property (nonatomic,assign) int64_t trimOut;
@property (nonatomic,assign) int64_t inPoint;
@property (nonatomic,assign) int64_t outPoint;
@property (nonatomic,copy) NSString *filePath;
@property (nonatomic,assign) BOOL printTime;

@property(nonatomic,weak)id<EditorFFmpegDecodeDelegate> decodeDelegate;
- (void)appendClipClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut;
- (void)appendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut;
- (void)appendPhotoClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut;
- (void)beginDecode;

@end

NS_ASSUME_NONNULL_END
