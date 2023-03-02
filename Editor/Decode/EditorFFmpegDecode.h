//
//  EditorFFmpegDecode.h
//  Editor
//
//  Created by zouran on 2022/12/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol EditorFFmpegDecodeDelegate <NSObject>

@optional
- (void)reveiveFrameToRenderer:(CVPixelBufferRef)img;

@end

@interface EditorFFmpegDecode : NSObject

@property (nonatomic, weak)id <EditorFFmpegDecodeDelegate> delegate;

- (void)appendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut;

@end

NS_ASSUME_NONNULL_END
