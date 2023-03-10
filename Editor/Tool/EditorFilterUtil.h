//
//  EditorFilterUtil.h
//  Editor
//
//  Created by zouran on 2023/3/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct AVFrame AVFrame;
typedef struct AVFilter AVFilter;

@interface EditorFilterUtil : NSObject

// 音量滤镜  变为原来的多少倍
+ (AVFrame *)fromFrame:(AVFrame *)frame volumeAdjust:(double)volumeMul;

// 速度滤镜  变为原来的多少倍
+ (AVFrame *)fromFrame:(AVFrame *)frame speedAdjust:(double)speedMul;

@end

NS_ASSUME_NONNULL_END
