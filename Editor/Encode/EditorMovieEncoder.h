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

- (instancetype)initWithOutputURL:(NSURL *)outputURL
                            width:(int)width
                           height:(int)height
                              fps:(int)fps;

- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)finishEncoding;

@end

NS_ASSUME_NONNULL_END
