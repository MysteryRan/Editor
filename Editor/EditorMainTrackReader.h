//
//  EditorMainTrackReader.h
//  Editor
//
//  Created by zouran on 2022/12/20.
//

#import <Foundation/Foundation.h>
#import "GPUImage.h"

NS_ASSUME_NONNULL_BEGIN

@interface EditorMainTrackReader : GPUImageOutput

- (void)recieveGPUImageView:(GPUImageView *)pre;
- (void)setupResource;
- (void)setupTimer;

- (void)begin;

@end

NS_ASSUME_NONNULL_END
