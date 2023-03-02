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

@end

NS_ASSUME_NONNULL_END
