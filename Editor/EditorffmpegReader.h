//
//  EditorffmpegReader.h
//  Editor
//
//  Created by zouran on 2022/12/9.
//

#import <Foundation/Foundation.h>
#import "GPUImage.h"
#import "MediaSegment.h"

NS_ASSUME_NONNULL_BEGIN
@class EditorffmpegReader;
@protocol EditorffmpegReaderDelegate <NSObject>

@optional
- (void)reveiveReader:(EditorffmpegReader *)reader withPts:(uint64_t)time;

@end

@interface EditorffmpegReader : GPUImageOutput

@property (nonatomic, copy) NSString *filePath;

@property (nonatomic, weak)id <EditorffmpegReaderDelegate> delegate;

- (void)readerEnd;

- (void)startEnable:(NSString *)path;

- (int)getMediaInfo:(NSString *)path;

- (GPUImageFilter *)startWith:(MediaSegment *)segment;
- (void)beginProgress:(MediaSegment *)segment;

- (int)remux;

- (void)starPicture:(NSString *)path;

- (int)cut_video:(double)from_seconds end:(double)end_seconds in_f:(const char*) in_filename out_f:(const char*)out_filename;

- (void)appendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut;

- (void)fullAppendClip:(NSString *)filePath trimIn:(uint64_t)trimIn trimOut:(uint64_t)trimOut;

- (void)pic;

- (void)seek;

- (void)stop;

- (void)addselectedFilter;
- (void)deleteSelectedFilter;

@end

NS_ASSUME_NONNULL_END
