//
//  MutilpleTrackContentView.h
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/9.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
//@class VideoClipModel;

@protocol MutilpleTrackContentViewDelegate <NSObject>

@optional

- (void)mutilpleTrackContentViewrightScroll:(CGRect)frame;

@end

@interface MutilpleTrackContentView : UIView

@property (nonatomic, weak) id <MutilpleTrackContentViewDelegate> delegate;
@property (nonatomic, strong)NSMutableArray<NSMutableArray *> *dataSource;

- (void)reloadTracksData;

@end

NS_ASSUME_NONNULL_END
