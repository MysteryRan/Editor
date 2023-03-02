//
//  EditorTransition.h
//  ffmpegDemo
//
//  Created by zouran on 2022/12/2.
//

#import <Foundation/Foundation.h>
#import "EditorVideo.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT MediaTypeStr const MediaTypeStringTransition;

@interface EditorTransition : NSObject

@property(nonatomic, copy) NSString *category_id;
@property(nonatomic, assign) uint64_t duration;
@property(nonatomic, copy) NSString *effect_id;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *path;
@property(nonatomic, copy) NSString *resource_id;
@property(nonatomic, copy) MediaTypeStr type;


@end

NS_ASSUME_NONNULL_END
