//
//  EditorAudioMixEngine.h
//  Editor
//
//  Created by zouran on 2022/12/14.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EditorAudioMixEngine : NSObject

@property (nonatomic, strong) AVURLAsset *videoAsset;
@property (nonatomic, strong) AVURLAsset *musicAsset;
@property (nonatomic, assign) CMTimeRange videoTimeRange;

- (void)buildCompositionObjectsForPlayback;
- (AVPlayerItem *)playerItem;

- (void)setVideoVolume:(CGFloat)volume;
- (void)setMusicVolume:(CGFloat)volume;

- (void)exportAtPath:(NSString *)outputPath completion:(void (^)(BOOL success))completion;


@end

NS_ASSUME_NONNULL_END
