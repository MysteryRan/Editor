//
//  EditorVideo.h
//  Editor
//
//  Created by zouran on 2022/12/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NSString *MediaTypeStr NS_STRING_ENUM;

FOUNDATION_EXPORT MediaTypeStr const MediaTypeStringVideo;

FOUNDATION_EXPORT MediaTypeStr const FTTypeStringOrange;

@interface EditorVideo : NSObject

@property(nonatomic, copy)NSString *media_id;
@property(nonatomic, copy)NSString *path;
@property(nonatomic, copy)MediaTypeStr type;
@property(nonatomic, assign)uint64_t height;
@property(nonatomic, assign)uint64_t width;

NS_ASSUME_NONNULL_END

@end
