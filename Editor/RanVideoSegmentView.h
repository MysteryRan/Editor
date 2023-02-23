//
//  RanVideoSegmentView.h
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class RanVideoSegmentView,MediaSegment;

@protocol VideoSegmentViewDelegate <NSObject>

@optional

- (void)videoSegmentViewClick:(RanVideoSegmentView *)segmentView;

@end


@interface RanVideoSegmentView : UIView

@property (nonatomic, strong) MediaSegment *segment;
@property (nonatomic, weak) id <VideoSegmentViewDelegate> delegate;

- (void)updateDataIfNeed;

@end

NS_ASSUME_NONNULL_END
