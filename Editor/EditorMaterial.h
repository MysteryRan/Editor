//
//  EditorMaterial.h
//  ffmpegDemo
//
//  Created by zouran on 2022/11/30.
//

#import <Foundation/Foundation.h>
#import "EditorVideo.h"
#import "EditorTransition.h"

NS_ASSUME_NONNULL_BEGIN

@interface EditorMaterial : NSObject

@property(nonatomic, strong)NSMutableArray <EditorVideo *>*videos;
@property(nonatomic, strong)NSMutableArray <EditorTransition *>*transitions;

@end

NS_ASSUME_NONNULL_END
