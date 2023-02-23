//
//  EditorConvertUtil.h
//  Editor
//
//  Created by zouran on 2022/12/20.
//

#import <Foundation/Foundation.h>

typedef struct AVFrame AVFrame;
NS_ASSUME_NONNULL_BEGIN

@interface EditorConvertUtil : NSObject

+ (CVPixelBufferPoolRef _Nullable)createCVPixelBufferPoolRef:(const int)format w:(const int)w h:(const int)h fullRange:(const bool)fullRange;

+ (CVPixelBufferRef _Nullable)pixelBufferFromAVFrame:(AVFrame*)frame opt:(CVPixelBufferPoolRef _Nullable)poolRef;


@end

NS_ASSUME_NONNULL_END
