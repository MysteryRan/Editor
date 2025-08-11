//
//  VideoTrack.h
//  Editor
//
//  Created by zouran on 01/08/2025.
//

#import <Foundation/Foundation.h>
#import "MediaTrack.h"
#import "VideoClip.h"
#import "EditorFFmpegDecode.h"

NS_ASSUME_NONNULL_BEGIN


@interface VideoTrack : MediaTrack

@property (nonatomic,weak)id<EditorFFmpegDecodeDelegate> decodeDelegate;
@property (nonatomic,strong)NSMutableArray *clips;

- (EditorFFmpegDecode *)appendClip:(NSString *)filePath trimIn:(int64_t)trimIn trimOut:(int64_t)trimOut;
@end

NS_ASSUME_NONNULL_END
