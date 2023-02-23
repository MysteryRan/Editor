//
//  EditorMainTrackReader.m
//  Editor
//
//  Created by zouran on 2022/12/20.
//

#import "EditorMainTrackReader.h"
#import "MediaSegment.h"
#import "EditorData.h"
#import "MediaInfo.h"
#import "FFMpegTool.h"
#import "EditorFFmpegDecode.h"

#import "EditorffmpegReader.h"

@interface EditorMainTrackReader()<EditorFFmpegDecodeDelegate> {
    
    BOOL audioEncodingIsFinished, videoEncodingIsFinished;
    GPUImageMovieWriter *synchronizedMovieWriter;
    AVAssetReader *reader;
    AVPlayerItemVideoOutput *playerItemOutput;
    CADisplayLink *displayLink;
    CMTime previousFrameTime, processingFrameTime;
    CFAbsoluteTime previousActualFrameTime;
    BOOL keepLooping;
    
    GLuint luminanceTexture, chrominanceTexture;
    
    GLProgram *yuvConversionProgram;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    const GLfloat *_preferredConversion;
    
    BOOL isFullYUVRange;
    
    int imageBufferWidth, imageBufferHeight;
    
    dispatch_source_t video_render_timer;
    dispatch_queue_t video_render_dispatch_queue;
}

@property (nonatomic, strong) EditorFFmpegDecode *ffmpegDecode;

@property (nonatomic, strong) EditorFFmpegDecode *secondffmpegDecode;

@property (nonatomic, strong) GPUImageView *preView;

@property (nonatomic, strong) GPUImageTwoInputFilter *transitionFilter;

@property (nonatomic, strong) EditorffmpegReader *ffmpegReader;

@property (nonatomic, strong) EditorffmpegReader *secondffmpegReader;

@end

@implementation EditorMainTrackReader

- (void)recieveGPUImageView:(GPUImageView *)pre {
    self.preView = pre;
}

- (void)begin {
//    [self yuvConversionSetup];
//    [self setupTimer];
    uint64_t start = 0;
    
    NSString *path1 = [[NSBundle mainBundle] pathForResource:@"flower" ofType:@"MP4"];
    NSString *path2 = [[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"];
    NSString *path3 = [[NSBundle mainBundle] pathForResource:@"sea" ofType:@"mp4"];
    NSString *path4 = [[NSBundle mainBundle] pathForResource:@"sample" ofType:@"mp4"];
    
    NSArray *array = @[path1,path2];
    
//    if ([FFMpegTool exportAblumPhoto:[ass.URL.absoluteString UTF8String] toPath:[u UTF8String]] == 0) {
    // 主轨
    MediaTrack *mainTrack = [[MediaTrack alloc] init];
    mainTrack.type = MediaTrackTypeVideo;
    for (int i = 0; i < array.count; i ++) {
        NSString *videoPath = array[i];
        MediaInfo *info = [FFMpegTool openStreamFunc:videoPath];
        EditorVideo *video = [[EditorVideo alloc] init];
        video.path = videoPath;
        video.width = info.width;
        video.height = info.height;
        video.media_id = [NSString media_GUIDString];
        
        EditorTransition *transition = [[EditorTransition alloc] init];
        transition.type = @"transition";
        transition.duration = 2000000;
        transition.path = [[NSBundle mainBundle] pathForResource:@"Heart" ofType:@"fsh"];
        
        MediaSegment *segment = [[MediaSegment alloc] init];
        segment.source_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:0 timeRangeDuration:info.duration];
        segment.target_timerange = [[MediaTimeRange alloc] initWithTimeRangeStart:start timeRangeDuration:segment.source_timerange.duration];
        
        [mainTrack.segments addObject:segment];
    }
    
    MediaSegment *segment = mainTrack.segments[0];
//    self.ffmpegDecode = [[EditorFFmpegDecode alloc] init];
//    self.ffmpegDecode.delegate = self;
//
//    self.secondffmpegDecode = [[EditorFFmpegDecode alloc] init];
//    self.secondffmpegDecode.delegate = self;
//
//    [self.ffmpegDecode appendClip:[[NSBundle mainBundle] pathForResource:@"ii" ofType:@"MP4"] trimIn:segment.source_timerange.start trimOut:segment.source_timerange.start + segment.source_timerange.duration];
    
    
    self.ffmpegReader = [[EditorffmpegReader alloc] init];
    [self.ffmpegReader startWith:segment];
    [self.ffmpegReader addTarget:self.preView];
    
}

- (void)setupResource {
    
}

- (void)setupTimer {
    double fps = 30.0;
    uint64_t av_time_base = 1000000;
    __block float time = 0;
    if(self->video_render_timer) {
        dispatch_source_cancel(self->video_render_timer);
    }
    self->video_render_dispatch_queue = dispatch_queue_create("render queue", DISPATCH_QUEUE_CONCURRENT);
    self->video_render_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, video_render_dispatch_queue);
    float duration = 1.0 / fps * av_time_base;
    dispatch_source_set_timer(self->video_render_timer, DISPATCH_TIME_NOW, (1.0 / fps) * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(self->video_render_timer, ^{
//        dispatch_async(dispatch_get_main_queue(), ^{
            if (time == 0) {
                
                
            }
            uint64_t current_time = round(time);
            [self trackControlWithTime:current_time];
//            [self StickerControlWithTime:current_time];
            time = time + duration;
        
//        if (time > self.secondSegment.target_timerange.start + self.secondSegment.target_timerange.duration) {
//
//            dispatch_suspend(self->video_render_timer);
//        }
//        });

    });
    dispatch_resume(self->video_render_timer);
}

- (void)trackControlWithTime:(uint64_t)time {
    
    double fps = 30.0;
    uint64_t av_time_base = 1000000;
    float perFrame = 1.0 / fps * av_time_base;
    
    // 每秒长度 / 总长度 = 每秒时间 / 总时间
    dispatch_async(dispatch_get_main_queue(), ^{
        
    });
    
    
    uint64_t distance = time - (8000000);
    
    // 刚转场
    if (distance <= perFrame && distance > 0) {
        // 前一个
        [self removeTarget:self.targets.lastObject];
        // 开始解码下一个了
        // 后一个
        
        // 有转场
//        if (tran_duration > 0) {
            //初始化转场
//            self.transitionFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromFilePath:[[NSBundle mainBundle] pathForResource:@"Heart" ofType:@"fsh"]];
//            [self.ffmpegDecode addTarget:self.transitionFilter];
//            [self.nextFilter addTarget:self.transitionFilter];
//
//            [self.transitionFilter addTarget:self.gpuPreView];
//        } else {
//            [self.nextFilter addTarget:self.gpuPreView];
//        }
    }
    // 转场中
//    if (tran_duration > 0) {
//        if (time >= self.secondSegment.target_timerange.start && time <= self.secondSegment.target_timerange.start + tran_duration) {
//            uint64_t dur_time = (time - self.secondSegment.target_timerange.start);
//            double percent = dur_time / (tran_duration * 1.0);
//            [self.transitionFilter setFloat:percent forUniformName:@"maintime"];
//        }
//
//        // 转场后
//        distance = time - (self.secondSegment.target_timerange.start + tran_duration);
//        if (distance <= perFrame && distance > 0) {
//            [self.currentFilter removeAllTargets];
//            [self.nextFilter removeAllTargets];
//            [self.transitionFilter removeAllTargets];
//            [self.nextFilter addTarget:self.gpuPreView];
//        }
//    }
    
    
    
}

- (void)reveiveFrameToRenderer:(CVPixelBufferRef)img {
    __unsafe_unretained EditorMainTrackReader *weakSelf = self;
    runSynchronouslyOnVideoProcessingQueue(^{
        [weakSelf processMovieFrame:img withSampleTime:kCMTimeZero];
        CVPixelBufferRelease(img);
    });
}

- (double)sizeFitCanvansSize:(CGSize)canvansSize sourceSize:(CGSize)sourceSize {
    // 以窄边为基准
    /*
     720p  1080p
     */
    double transfrom = 0.0;
    
    uint64_t canvansWidth = canvansSize.width;
    uint64_t canvansHeight = canvansSize.height;
    double canvansRadius = canvansWidth / (canvansHeight * 1.0);
    
    uint64_t sourceWidth = sourceSize.width;
    uint64_t sourceHeight = sourceSize.height;
    double sourceRadius = sourceWidth / (sourceHeight * 1.0);
    
    if (canvansRadius > sourceRadius) {
        // 高铺满 缩放宽
        uint64_t newHeight = canvansHeight;
        uint64_t newWidth = sourceRadius * newHeight;
        transfrom = newWidth / (canvansWidth * 1.0);
        
        return transfrom;
    } else {
        uint64_t newWidth = canvansWidth;
        uint64_t newHeight = newWidth / sourceRadius;
        transfrom = newHeight / (canvansHeight * 1.0);
        return transfrom;
    }
    return 1.0;
}

- (GPUImageFilter *)setNormalTransform:(GPUImageOutput *)sourceFilter withVideoSize:(CGSize)videoSize {
    GPUImageTransformFilter *transForm = [[GPUImageTransformFilter alloc] init];
    
    CanvasConfig *config = [EditorData sharedInstance].canvas_config;
    
    CGSize canvansSize = CGSizeMake(config.width, config.height);
    
    double cgaffineTransform = [self sizeFitCanvansSize:canvansSize sourceSize:CGSizeMake(videoSize.width, videoSize.height)];
    
    uint64_t canvansWidth = canvansSize.width;
    uint64_t canvansHeight = canvansSize.height;
    double canvansRadius = canvansWidth / (canvansHeight * 1.0);
    
    CGSize sourceSize = CGSizeMake(videoSize.width, videoSize.height);
    uint64_t sourceWidth = sourceSize.width;
    uint64_t sourceHeight = sourceSize.height;
    double sourceRadius = sourceWidth / (sourceHeight * 1.0);
    
    if (canvansRadius > sourceRadius) {
        transForm.affineTransform = CGAffineTransformMakeScale(cgaffineTransform, 1.0);
    } else {
        transForm.affineTransform = CGAffineTransformMakeScale(1.0, cgaffineTransform);
    }
    
    [sourceFilter addTarget:transForm];
    return transForm;
}

- (void)yuvConversionSetup {
    if ([GPUImageContext supportsFastTextureUpload])
    {
        runSynchronouslyOnVideoProcessingQueue(^{
            [GPUImageContext useImageProcessingContext];

            _preferredConversion = kColorConversion709;
            isFullYUVRange       = YES;
            yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];

            if (!yuvConversionProgram.initialized)
            {
                [yuvConversionProgram addAttribute:@"position"];
                [yuvConversionProgram addAttribute:@"inputTextureCoordinate"];

                if (![yuvConversionProgram link])
                {
                    NSString *progLog = [yuvConversionProgram programLog];
                    NSLog(@"Program link log: %@", progLog);
                    NSString *fragLog = [yuvConversionProgram fragmentShaderLog];
                    NSLog(@"Fragment shader compile log: %@", fragLog);
                    NSString *vertLog = [yuvConversionProgram vertexShaderLog];
                    NSLog(@"Vertex shader compile log: %@", vertLog);
                    yuvConversionProgram = nil;
                    NSAssert(NO, @"Filter shader link failed");
                }
            }

            yuvConversionPositionAttribute = [yuvConversionProgram attributeIndex:@"position"];
            yuvConversionTextureCoordinateAttribute = [yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
            yuvConversionLuminanceTextureUniform = [yuvConversionProgram uniformIndex:@"luminanceTexture"];
            yuvConversionChrominanceTextureUniform = [yuvConversionProgram uniformIndex:@"chrominanceTexture"];
            yuvConversionMatrixUniform = [yuvConversionProgram uniformIndex:@"colorConversionMatrix"];

            [GPUImageContext setActiveShaderProgram:yuvConversionProgram];

            glEnableVertexAttribArray(yuvConversionPositionAttribute);
            glEnableVertexAttribArray(yuvConversionTextureCoordinateAttribute);
        });
    }
}

#pragma mark -
#pragma mark Movie processing

- (void)enableSynchronizedEncodingUsingMovieWriter:(GPUImageMovieWriter *)movieWriter;
{
    synchronizedMovieWriter = movieWriter;
    movieWriter.encodingLiveVideo = NO;
}

- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer;
{
//    CMTimeGetSeconds
//    CMTimeSubtract
    
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(movieSampleBuffer);
    CVImageBufferRef movieFrame = CMSampleBufferGetImageBuffer(movieSampleBuffer);

//    processingFrameTime = currentSampleTime;
    [self processMovieFrame:movieFrame withSampleTime:currentSampleTime];
}

- (void)processMovieFrame:(CVPixelBufferRef)movieFrame withSampleTime:(CMTime)currentSampleTime
{
    int bufferHeight = (int) CVPixelBufferGetHeight(movieFrame);
    int bufferWidth = (int) CVPixelBufferGetWidth(movieFrame);

    CFTypeRef colorAttachments = CVBufferGetAttachment(movieFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL)
    {
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo)
        {
            if (isFullYUVRange)
            {
                _preferredConversion = kColorConversion601FullRange;
            }
            else
            {
                _preferredConversion = kColorConversion601;
            }
        }
        else
        {
            _preferredConversion = kColorConversion709;
        }
    }
    else
    {
        if (isFullYUVRange)
        {
            _preferredConversion = kColorConversion601FullRange;
        }
        else
        {
            _preferredConversion = kColorConversion601;
        }

    }
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();

    // Fix issue 1580
    [GPUImageContext useImageProcessingContext];
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        CVOpenGLESTextureRef luminanceTextureRef = NULL;
        CVOpenGLESTextureRef chrominanceTextureRef = NULL;

        //        if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
        if (CVPixelBufferGetPlaneCount(movieFrame) > 0) // Check for YUV planar inputs to do RGB conversion
        {

            if ( (imageBufferWidth != bufferWidth) && (imageBufferHeight != bufferHeight) )
            {
                imageBufferWidth = bufferWidth;
                imageBufferHeight = bufferHeight;
            }

            CVReturn err;
            // Y-plane
            glActiveTexture(GL_TEXTURE4);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            }
            else
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }

            luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, luminanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

            // UV-plane
            glActiveTexture(GL_TEXTURE5);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            }
            else
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }

            chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

//            if (!allTargetsWantMonochromeData)
//            {
                [self convertYUVToRGBOutput];
//            }

            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
            }
            
            [outputFramebuffer unlock];

            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
            }

            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
            CFRelease(luminanceTextureRef);
            CFRelease(chrominanceTextureRef);
        }
        else
        {
            // TODO: Mesh this with the new framebuffer cache
//            CVPixelBufferLockBaseAddress(movieFrame, 0);
//
//            CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, coreVideoTextureCache, movieFrame, NULL, GL_TEXTURE_2D, GL_RGBA, bufferWidth, bufferHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &texture);
//
//            if (!texture || err) {
//                NSLog(@"Movie CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
//                NSAssert(NO, @"Camera failure");
//                return;
//            }
//
//            outputTexture = CVOpenGLESTextureGetName(texture);
//            //        glBindTexture(CVOpenGLESTextureGetTarget(texture), outputTexture);
//            glBindTexture(GL_TEXTURE_2D, outputTexture);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//
//            for (id<GPUImageInput> currentTarget in targets)
//            {
//                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
//                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
//
//                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
//                [currentTarget setInputTexture:outputTexture atIndex:targetTextureIndex];
//
//                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
//            }
//
//            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
//            CVOpenGLESTextureCacheFlush(coreVideoTextureCache, 0);
//            CFRelease(texture);
//
//            outputTexture = 0;
        }
    }
    else
    {
        // Upload to texture
        CVPixelBufferLockBaseAddress(movieFrame, 0);
        
//        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(bufferWidth, bufferHeight) textureOptions:self.outputTextureOptions onlyTexture:YES];

        glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
        // Using BGRA extension to pull in video frame data directly
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     self.outputTextureOptions.internalFormat,
                     bufferWidth,
                     bufferHeight,
                     0,
                     self.outputTextureOptions.format,
                     self.outputTextureOptions.type,
                     CVPixelBufferGetBaseAddress(movieFrame));
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
        }
        
        [outputFramebuffer unlock];
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
        }
        CVPixelBufferUnlockBaseAddress(movieFrame, 0);
    }
}

- (void)endProcessing;
{
//    keepLooping = NO;
//    [displayLink setPaused:YES];

//    [self readerEnd];
    for (id<GPUImageInput> currentTarget in targets)
    {
        [currentTarget endProcessing];
    }
    
    if (synchronizedMovieWriter != nil)
    {
        [synchronizedMovieWriter setVideoInputReadyCallback:^{return NO;}];
        [synchronizedMovieWriter setAudioInputReadyCallback:^{return NO;}];
    }
    
}

- (void)cancelProcessing
{
    if (reader) {
        [reader cancelReading];
    }
    [self endProcessing];
}

- (void)convertYUVToRGBOutput;
{
    [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(imageBufferWidth, imageBufferHeight) onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };

    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };

    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(yuvConversionLuminanceTextureUniform, 4);

    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(yuvConversionChrominanceTextureUniform, 5);

    glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);

    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (BOOL)audioEncodingIsFinished {
    return audioEncodingIsFinished;
}

- (BOOL)videoEncodingIsFinished {
    return videoEncodingIsFinished;
}

@end
