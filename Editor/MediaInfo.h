//
//  MediaInfo.h
//  ffmpegDemo
//
//  Created by zouran on 2022/11/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaInfo : NSObject

@property(nonatomic, assign)uint64_t width;
@property(nonatomic, assign)uint64_t height;
@property(nonatomic, assign)uint64_t duration;

@end

NS_ASSUME_NONNULL_END
