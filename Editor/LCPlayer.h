//
//  LCPlayer.h
//  Editor
//
//  Created by zouran on 2023/1/31.
//

#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
#include <libavutil/frame.h>
    
#ifdef __cplusplus
};
#endif
#import "EditorFFmpegDecode.h"

NS_ASSUME_NONNULL_BEGIN

@interface LCPlayer : NSObject

@property (nonatomic, weak)id <EditorFFmpegDecodeDelegate> delegate;

- (int)maintest;

- (void)appendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut;

- (AVFrame *)getRefresh;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
