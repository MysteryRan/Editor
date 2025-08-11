//
//  MediaClip.h
//  Editor
//
//  Created by zouran on 2023/3/2.
//

#import <Foundation/Foundation.h>
#import "MediaFloat.h"

NS_ASSUME_NONNULL_BEGIN

@interface MediaClip : NSObject

@property (nonatomic, strong)MediaFloat *scale;
@property (nonatomic, strong)MediaFloat *transform;
@property (nonatomic, assign)float rotation;

@property (nonatomic, assign) int64_t trimIn;             //!< \if ENGLISH Clip triming in point (in microseconds). \else 片段裁剪入点(单位微秒)\endif

@property (nonatomic, assign) int64_t trimOut;            //!< \if ENGLISH Clip triming out point (in microseconds). \else 片段裁剪出点(单位微秒) \endif

@property (nonatomic, assign) int64_t inPoint;            //!< \if ENGLISH The in point of the clip on the timeline (in microseconds). \else 片段在时间线上的入点(单位微秒) \endif

@property (nonatomic, assign) int64_t outPoint;           //!< \if ENGLISH The out point of the clip on the timeline (in microseconds). \else 片段在时间线上的出点(单位微秒) \endif

@property (nonatomic, assign) unsigned int index;         //!< \if ENGLISH The index of the clip on the track. \else 片段在轨道上的索引 \endif

@property (nonatomic, assign) NSString *filePath;     

@end

NS_ASSUME_NONNULL_END
