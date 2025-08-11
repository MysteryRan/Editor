//
//  GPUImageTwoInputTransitonFilter.h
//  Editor
//
//  Created by zouran on 08/08/2025.
//

#import <GPUImage/GPUImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface GPUImageTwoInputTransitonFilter : GPUImageFilter
{
    GPUImageFramebuffer *secondInputFramebuffer;

    GLint filterSecondTextureCoordinateAttribute;
    GLint filterInputTextureUniform2;
    GPUImageRotationMode inputRotation2;
    CMTime firstFrameTime, secondFrameTime;
    
    BOOL hasSetFirstTexture, hasReceivedFirstFrame, hasReceivedSecondFrame, firstFrameWasVideo, secondFrameWasVideo;
    BOOL firstFrameCheckDisabled, secondFrameCheckDisabled;
}

@property (nonatomic,assign)BOOL renderLast;

- (void)disableFirstFrameCheck;
- (void)disableSecondFrameCheck;

@end

NS_ASSUME_NONNULL_END
