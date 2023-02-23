//
//  MediaSegment.h
//  Editor
//
//  Created by zouran on 2022/12/19.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "EditorVideo.h"
#import "MediaTimeRange.h"

NS_ASSUME_NONNULL_BEGIN
@interface MediaSegment : NSObject

//source 自己本身
@property(nonatomic, strong)MediaTimeRange *target_timerange;
@property(nonatomic, strong)MediaTimeRange *source_timerange;
@property(nonatomic, copy)NSString *material_id;

- (EditorVideo *)segmentFindVideo;

- (CMTimeRange)getAVFoundationTargetTimeRange;

@end

NS_ASSUME_NONNULL_END
