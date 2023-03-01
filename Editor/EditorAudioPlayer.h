//
//  EditorAudioPlayer.h
//  Editor
//
//  Created by zouran on 2022/12/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MediaTrack;
@interface EditorAudioPlayer : NSObject

- (instancetype)initWithMediaTrack:(MediaTrack *)mainTrack;

- (void)play;

- (void)audioexport;

@end

NS_ASSUME_NONNULL_END
