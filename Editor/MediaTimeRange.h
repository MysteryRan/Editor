//
//  MediaTimeRange.h
//  ffmpegDemo
//
//  Created by zouran on 2022/11/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaTimeRange : NSObject

@property(nonatomic, assign, readonly)uint64_t start;
@property(nonatomic, assign, readonly)uint64_t duration;

- (id)initWithTimeRangeStart:(uint64_t)start timeRangeDuration:(uint64_t)duration;

@end

NS_ASSUME_NONNULL_END
