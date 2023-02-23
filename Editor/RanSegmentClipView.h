//
//  RanSegmentClipView.h
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class RanSegmentClipView;
@protocol segmentClipDelegate <NSObject>

@optional
- (void)rightControlView:(UIPanGestureRecognizer *)ges withWidthChange:(CGFloat)widthOffset withRect:(CGRect)rect;

- (void)leftControlView:(UIPanGestureRecognizer *)ges withWidthChange:(CGFloat)widthOffset withRect:(CGRect)rect;

- (void)rightScroll:(CGRect)frame;

//- (void)rightControlView:(UIPanGestureRecognizer *)ges withView:(CGRect)rect;

@end

@interface RanSegmentClipView : UIView

@property (nonatomic, weak)id <segmentClipDelegate> delegate;
@property (nonatomic, strong) UIView *insideView;
@property (nonatomic, assign) CGFloat minWidth;
@property (nonatomic, assign) CGFloat maxWidth;
@property (nonatomic, assign) CGFloat leftLimit;
@property (nonatomic, assign) CGFloat rightLimit;
@property (nonatomic, assign) CGFloat beginLimit;
@property (nonatomic, assign) CGFloat endLimit;

@property (nonatomic, strong) UIView *leftControl;
@property (nonatomic, strong) UIView *rightControl;

@end

NS_ASSUME_NONNULL_END
