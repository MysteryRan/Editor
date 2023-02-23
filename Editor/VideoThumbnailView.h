//
//  VideoThumbnailView.h
//  Editor
//
//  Created by zouran on 2022/5/12.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoThumbnailView : UIView

@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSOperationQueue *loadImageQueue;
@property (nonatomic) CGSize imageSize;
@property (nonatomic) NSInteger preloadCount;

- (void)updateDataIfNeed;

@end

NS_ASSUME_NONNULL_END
