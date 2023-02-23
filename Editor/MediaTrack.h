//
//  MediaTrack.h
//  ffmpegDemo
//
//  Created by zouran on 2022/12/1.
//

#import <Foundation/Foundation.h>
#import "MediaSegment.h"
NS_ASSUME_NONNULL_BEGIN

typedef NSString *MediaTrackType NS_STRING_ENUM;

FOUNDATION_EXPORT MediaTrackType const MediaTrackTypeVideo;
FOUNDATION_EXPORT MediaTrackType const MediaTrackTypeEffect;

@interface MediaTrack : NSObject

@property(nonatomic, strong) NSMutableArray <MediaSegment *>*segments;
@property(nonatomic, copy) MediaTrackType type;

@end

NS_ASSUME_NONNULL_END
