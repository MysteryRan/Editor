//
//  RanMediaTimeline.h
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/17.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MediaVideoClipView,VideoClipModel,RanVideoSegmentView;

@protocol RanMediaTimelineViewDelegate <NSObject>

@optional

- (void)ranMediaTimelineDidScroll:(CGFloat)offset;

- (void)ranMediaTimelineDidSelectedSegmentView:(RanVideoSegmentView *)segmentView;

@end

@interface RanMediaTimeline : UIScrollView
 
@property (nonatomic, weak) id <RanMediaTimelineViewDelegate> mediaDelegate;
@property (nonatomic, strong) NSMutableArray *clipsViews;
@property (nonatomic, strong) VideoClipModel *selectedClipModel;
@property (nonatomic, strong) RanVideoSegmentView *selectedSegmentView;

- (void)insertRangeView:(RanVideoSegmentView *)view atIndex:(NSInteger)index;
- (void)removeRangeViewAtIndex:(NSInteger)index animated:(BOOL)animated completion:(void(^)(void))completion;
- (void)removeCurrentActivedRangeViewCompletion:(void(^)(void))completion;

- (void)displayRangeViewsIfNeed;

- (void)thumbnailViewChangeTrimOut:(uint64_t)newTrimout;
- (void)thumbnailViewSpeedUp:(float)speed;

- (void)removeTrackClipView;
- (void)outClick:(RanVideoSegmentView *)segmentView;

- (void)initSubviewsWithSegments:(NSMutableArray *)segments;

- (void)reloadDa;

@end

NS_ASSUME_NONNULL_END
