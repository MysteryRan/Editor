//
//  VideoThumbnailView.m
//  Editor
//
//  Created by zouran on 2022/5/12.
//

#import "VideoThumbnailView.h"
#import <AVFoundation/AVFoundation.h>
#import "CachedAssetImageGenerator.h"

@interface VideoThumbnailView()

@property (nonatomic, strong) NSMutableSet<UIImageView *> *reusableImageViews;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIImageView *> *imageViewDic;

@property (nonatomic, strong, readwrite) AVAsset *asset;
@property (nonatomic, strong) CachedAssetImageGenerator *imageGenerator;

@end

@implementation VideoThumbnailView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _reusableImageViews = [NSMutableSet set];
    _imageViewDic = [NSMutableDictionary dictionary];
    _preloadCount = 1;
    _loadImageQueue = [[NSOperationQueue alloc] init];
    _loadImageQueue.maxConcurrentOperationCount = 4;
    

}

- (void)setPath:(NSString *)path {
    _path = path;
    CachedAssetImageGenerator *imageGenerator = [CachedAssetImageGenerator assetImageGeneratorWithAsset:[AVAsset assetWithURL:[NSURL fileURLWithPath:path]]];
    imageGenerator.requestedTimeToleranceBefore = CMTimeMake(600, 600);
    imageGenerator.requestedTimeToleranceAfter = CMTimeMake(600, 600);
    imageGenerator.appliesPreferredTrackTransform = YES;
    _imageGenerator = imageGenerator;
    [self setImageSize:CGSizeMake(50, 50)];
}

- (void)layoutIfNeeded {
    [super layoutIfNeeded];
    if (CGSizeEqualToSize(self.imageSize, CGSizeZero)) {
        self.imageSize = CGSizeMake(self.bounds.size.height, self.bounds.size.height);
    }
    [self updateDataIfNeed];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (CGSizeEqualToSize(self.imageSize, CGSizeZero)) {
        self.imageSize = CGSizeMake(self.bounds.size.height, self.bounds.size.height);
    }
    [self updateDataIfNeed];
}

#pragma mark - Override

- (void)reloadData {
    [self removeImageViewsOutOfRange:NSMakeRange(0, 0)];
    [self updateDataIfNeed];
}

- (void)updateDataIfNeed {
    NSRange visiableRange = [self calculateVisiableRange];
    if (visiableRange.length == 0) {
        return;
    }
    [self removeImageViewsOutOfRange:visiableRange];
    for (NSInteger i = visiableRange.location; i < visiableRange.location + visiableRange.length; i++) {
        [self loadImageViewAtIndex:i];
    }
}

#pragma mark - Logic

- (NSRange)calculateVisiableRange {
    if (self.imageSize.height <= 0) {
        return NSMakeRange(0, 0);
    }
    
//    if (!self.dataSource) {
//        return NSMakeRange(0, 0);
//    }
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (!window) {
        return NSMakeRange(0, 0);
    }
    
    CGRect availableRectInSuperView = CGRectIntersection([self.superview convertRect:self.superview.bounds toView:self], self.bounds);
    CGRect rectInWindow = [self convertRect:availableRectInSuperView toView:window];
    CGRect availableRectInWindow = CGRectIntersection(window.bounds, rectInWindow);
    if (!(availableRectInWindow.size.width > 0 && availableRectInWindow.size.height > 0)) {
        return NSMakeRange(0, 0);
    }
    
    CGRect availableRect = [self convertRect:availableRectInWindow fromView:window];
    CGFloat startOffset = availableRect.origin.x;
    NSInteger startIndexOfImage = startOffset / self.imageSize.width;
    NSInteger endIndexOfImage = ceil((availableRect.size.width + startOffset) / self.imageSize.width);
    
    if (self.preloadCount > 0) {
        startIndexOfImage = startIndexOfImage - self.preloadCount;
        startIndexOfImage = MAX(0, startIndexOfImage);
        endIndexOfImage = endIndexOfImage + self.preloadCount;
        NSInteger maxIndex = [self videoRangeContentViewNumberOfImages];
        endIndexOfImage = MIN(maxIndex, endIndexOfImage);
    }
    
    startIndexOfImage = MIN(startIndexOfImage, endIndexOfImage);
    return NSMakeRange(startIndexOfImage, endIndexOfImage - startIndexOfImage);
}

- (NSInteger)videoRangeContentViewNumberOfImages {
    NSTimeInterval sourceSeconds = CMTimeGetSeconds([AVAsset assetWithURL:[NSURL fileURLWithPath:self.path]].duration);
    return ceil(sourceSeconds / (self.imageSize.width / ([UIScreen mainScreen].bounds.size.width / 8)));
}

- (void)removeImageViewsOutOfRange:(NSRange)range {
    NSMutableArray *outIndexes = [NSMutableArray array];
    [[self.imageViewDic allKeys] enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.integerValue < range.location || obj.integerValue > (range.location + range.length)) {
            [outIndexes addObject:obj];
        }
    }];

    [outIndexes enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        UIImageView *imageView = self.imageViewDic[obj];
        imageView.tag = 0;
        imageView.image = nil;
        [imageView removeFromSuperview];
        [self.imageViewDic removeObjectForKey:obj];
        [self.reusableImageViews addObject:imageView];
    }];
}

- (void)setImageSize:(CGSize)imageSize {
    _imageSize = imageSize;
    imageSize = CGSizeMake(imageSize.width * UIScreen.mainScreen.scale, imageSize.height * UIScreen.mainScreen.scale);
    AVAssetTrack *track = [[self.imageGenerator.asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (track) {
        CGSize size = CGSizeMake(imageSize.width, imageSize.height);
        if (track) {
            CGSize naturalSize = CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
            naturalSize.width = fabs(naturalSize.width);
            naturalSize.height = fabs(naturalSize.height);
            if (naturalSize.width / imageSize.width > naturalSize.height / imageSize.height) {
                size = CGSizeMake(0, imageSize.height);
            } else {
                size = CGSizeMake(imageSize.width, 0);
            }
        }
        self.imageGenerator.maximumSize = size;
    } else {
        self.imageGenerator.maximumSize = imageSize;
    }
}

- (void)loadImageViewAtIndex:(NSInteger)index {
//    if (!self.dataSource) {
//        return;
//    }
    
    UIImageView *imageView = self.imageViewDic[@(index)];
    
    if (imageView.tag == index && imageView.superview == self && imageView.image) {
        return;
    }
    
//    if (imageView.vi_operation && !imageView.vi_operation.isCancelled) {
//        return;
//    }
    
    if (!imageView) {
        imageView = [self createImageView];
        self.imageViewDic[@(index)] = imageView;
    }
    
    NSInteger previousIndex = imageView.tag;
    imageView.tag = index;
    
    if (previousIndex != index || !imageView.image) {
        [self layoutImageView:imageView atIndex:index];
        // load image data
        if (!imageView.image) {
            BOOL hasCache = NO;
//            if ([self.dataSource respondsToSelector:@selector(videoRangeContent:hasCacheAtIndex:)]) {
                hasCache = [self hasCacheAtIndex:index];
//            }
            if (self.loadImageQueue && !hasCache) {
                NSBlockOperation *loadImageOperation = [[NSBlockOperation alloc] init];
                __weak typeof(loadImageOperation)weakOperation = loadImageOperation;
                __weak typeof(self)weakSelf = self;
                __weak typeof(imageView)weakImageView = imageView;
                [loadImageOperation addExecutionBlock:^{
                    __strong __typeof(weakOperation)strongOperation = weakOperation;
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    __strong __typeof(weakImageView)imageView = weakImageView;
                    if (!strongSelf || !strongOperation) {
                        return;
                    }
                    if (strongOperation.isCancelled) {
                        return;
                    }
                    UIImage *image = [strongSelf imageAtIndex:index preferredSize:strongSelf.imageSize];
                    
                    if (strongOperation.isCancelled) {
                        return;
                    }
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        if (imageView.tag == index) {
                            [UIView transitionWithView:imageView duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                                imageView.image = image;
                            } completion:nil];
                        }
                    }];
                }];
                [self.loadImageQueue addOperation:loadImageOperation];
//                [imageView.vi_operation cancel];
//                [imageView setVi_operation:loadImageOperation];
            } else {
                UIImage *image = [self imageAtIndex:index preferredSize:self.imageSize];
                imageView.image = image;
            }
        }
    }
}

- (BOOL)hasCacheAtIndex:(NSInteger)index {
    CGFloat offset = 50 * index;
    NSTimeInterval second = offset / ([UIScreen mainScreen].bounds.size.width / 8);
    CMTime time = CMTimeMakeWithSeconds(second, 600);
    return [self.imageGenerator hasCacheAtTime:time];
}

- (UIImage *)imageAtIndex:(NSInteger)index preferredSize:(CGSize)size {
    CGFloat offset = 50 * index;
    NSTimeInterval time = offset / ([UIScreen mainScreen].bounds.size.width / 8);
    
    UIImage *image;
    CGImageRef cgimage = [self.imageGenerator copyCGImageAtTime:CMTimeMakeWithSeconds(time, 600) actualTime:nil error:nil];
    if (cgimage) {
        image = [[UIImage alloc] initWithCGImage:cgimage];
    }
    return image;
}

- (UIImageView *)createImageView {
    UIImageView *imageView = [self.reusableImageViews anyObject];
    if (imageView) {
        [self.reusableImageViews removeObject:imageView];
        imageView.tag = -1;
        return imageView;
    }
    
    imageView = [[UIImageView alloc] init];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.tag = -1;
    imageView.clipsToBounds = YES;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    
    return imageView;
}

- (void)layoutImageView:(UIImageView *)imageView atIndex:(NSInteger)index {
    if (imageView.superview != self) {
        [self insertSubview:imageView atIndex:0];
    }
    
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self);
        make.size.mas_equalTo(self.imageSize);
        make.left.equalTo(self).offset(round(index * self.imageSize.width));
    }];
}



@end
