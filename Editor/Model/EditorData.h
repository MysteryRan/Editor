//
//  EditorData.h
//  ffmpegDemo
//
//  Created by zouran on 2022/11/29.
//

#import <Foundation/Foundation.h>
#import "EditorMaterial.h"
#import "MediaTrack.h"
#import "CanvasConfig.h"
NS_ASSUME_NONNULL_BEGIN

@interface EditorData : NSObject

+ (EditorData *)sharedInstance;

@property (nonatomic, strong)CanvasConfig *canvas_config;
@property (nonatomic, strong)NSMutableArray <MediaTrack *>*tracks;
@property (nonatomic, assign)int fps;
@property (nonatomic, strong)EditorMaterial *materials;
@property (nonatomic, assign)uint32_t duration;
@property (nonatomic, assign)uint32_t create_time;
@property (nonatomic, assign)uint32_t update_time;

@end

NS_ASSUME_NONNULL_END
