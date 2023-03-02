//
//  EditorMovieEncoder.h
//  Editor
//
//  Created by zouran on 2023/2/28.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EditorMovieEncoder : NSObject

- (instancetype)initWithVideoConfiguration;

- (void)encoding:(CVPixelBufferRef)pixelBuffer timestamp:(CGFloat)timestamp;

- (void)teardown;

@end

NS_ASSUME_NONNULL_END
