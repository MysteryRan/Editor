//
//  EditorTimeline.h
//  Editor
//
//  Created by zouran on 01/08/2025.
//

#import <Foundation/Foundation.h>
#import "VideoTrack.h"
NS_ASSUME_NONNULL_BEGIN

@interface EditorTimeline : NSObject

+ (EditorTimeline *)sharedInstance;

- (VideoTrack *)appendVideoTrack;

- (VideoTrack *)getVideoTrackByIndex:(unsigned int)trackIndex;


@end

NS_ASSUME_NONNULL_END
