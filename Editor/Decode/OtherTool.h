//
//  OtherTool.h
//  ffmpegDemo
//
//  Created by zouran on 2022/11/22.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OtherTool : NSObject

+(CVPixelBufferRef)convertPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
