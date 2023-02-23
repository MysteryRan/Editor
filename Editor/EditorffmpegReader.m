//
//  EditorffmpegReader.m
//  Editor
//
//  Created by zouran on 2022/12/9.
//

#import "EditorffmpegReader.h"
#import "EditorData.h"
#import "EditorFFmpegDecode.h"
#import "LCPlayer.h"
#import "GPUImagePicture+TextureSubimage.h"

@interface EditorffmpegReader()<EditorFFmpegDecodeDelegate> {
    
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
}

@property (nonatomic, strong)EditorFFmpegDecode *ffmpegDecode;

@property (nonatomic, strong) GPUImageFilterPipeline *pipeline;
@property (nonatomic, strong) NSMutableArray *filters;
@property (nonatomic, strong)LCPlayer *lcplayer;

@property (nonatomic, strong) GPUImagePicture *picc;

@end

@implementation EditorffmpegReader

- (void)dealloc {
    NSLog(@"movie delloc");
}

- (void)beginProgress:(MediaSegment *)segment {
    EditorVideo *video = [segment segmentFindVideo];
    [self starPicture:video.path];
}

- (void)stop {
    [self.lcplayer stop];
}

- (GPUImageFilter *)startWith:(MediaSegment *)segment {
    [self yuvConversionSetup];
    EditorVideo *video = [segment segmentFindVideo];
    NSLog(@"width-height---%lld---%lld",video.width,video.height);
    GPUImageFilter *filter = [self setNormalTransform:self withVideoSize:CGSizeMake(video.width, video.height)];
//    self.ffmpegDecode = [[EditorFFmpegDecode alloc] init];
//    self.ffmpegDecode.delegate = self;
//    [self.ffmpegDecode appendClip:video.path trimIn:segment.source_timerange.start trimOut:segment.source_timerange.start + segment.source_timerange.duration];
    
    self.lcplayer = [[LCPlayer alloc] init];
    self.lcplayer.delegate = self;
//    [self.lcplayer maintest];
    [self.lcplayer appendClip:video.path trimIn:segment.source_timerange.start trimOut:segment.source_timerange.start + segment.source_timerange.duration];
    
    
    return filter;
}

- (void)reveiveFrameToRenderer:(CVPixelBufferRef)img {
    __unsafe_unretained EditorffmpegReader *weakSelf = self;
    runSynchronouslyOnVideoProcessingQueue(^{
//        [weakSelf processMovieFrame:img withSampleTime:kCMTimeZero];
        [weakSelf processMovieFrame:img];
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
    
    self.filters = [NSMutableArray arrayWithCapacity:0];
//    [self.filters addObject:transForm];
    
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
        
    self.pipeline = [[GPUImageFilterPipeline alloc] initWithOrderedFilters:self.filters input:sourceFilter output:transForm];
    
    return transForm;
}

- (void)addselectedFilter {
    GPUImageMonochromeFilter *monochromeFilter = [[GPUImageMonochromeFilter alloc] init];
//    [self.pipeline addFilter:monochromeFilter];
    
    
    GPUImagePinchDistortionFilter *crosshairGeneratorFilter = [[GPUImagePinchDistortionFilter alloc] init];
    [self.pipeline addFilter:crosshairGeneratorFilter];
}

/*
- (void)addselectedFilter {
    // 添加单个
//    GPUImageCrosshatchFilter *cross = [[GPUImageCrosshatchFilter alloc] init];
//    [self.pipeline addFilter:cross];
    
    
    // 添加twoinput
    GPUImageTwoInputFilter *ee = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromFilePath: [[NSBundle mainBundle] pathForResource:@"replaceCrop" ofType:@"fsh"]];
    [ee setInteger:200 forUniformName:@"baseTexWidth"];
    [ee setInteger:201 forUniformName:@"baseTexHeight"];
    [ee setSize:CGSizeMake(300.0, 300.0) forUniformName:@"fullBlendTexSize"];
    [ee setInteger:2 forUniformName:@"blendMode"];
    [ee setFloat:1.0 forUniformName:@"alphaFactor"];
    self.picc = [[GPUImagePicture alloc] initWithImage:[UIImage imageNamed:@"clipname_000.png"]];
    [self.pipeline.input addTarget:ee];
    [self.picc addTarget:ee];
    [self.picc processImage];
    
    
    // 假设特效的时长为 3s   特效默认时长为0.6s   重复3次
    ee.frameProcessingCompletionBlock = ^(GPUImageOutput *output, CMTime frametime) {
        NSLog(@"frameProcessingCompletionBlock --time %lld",frametime.value / frametime.timescale);
        
//       0 600000 0 51  11764
//       3000000 51     11764 * 5
        
        int bt = (frametime.value - 5000000) / (11764 * 5);
        NSLog(@"bttbt-----%d",bt);
        NSString *tr = [NSString stringWithFormat:@"clipname_0%.02d.png",(int)bt];
        UIImage *rep = [UIImage imageNamed:tr];
        if (rep) {
            [self.picc replaceTextureWithSubimage:rep];
        }
    };
    
    [self.pipeline addFilter:ee];
    
}
 */

- (void)deleteSelectedFilter {
    [self.pipeline removeFilterAtIndex:0];
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
//    NSLog(@"currentSampleTime value %lld",currentSampleTime.value/currentSampleTime.timescale);
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
