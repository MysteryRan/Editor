//
//  RanMediaTimeline.m
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/17.
//

#import "RanMediaTimeline.h"
#import "Masonry.h"
#import "RanMediaTimelineContainer.h"
#import "RanVideoSegmentView.h"
#import "RanSegmentClipView.h"
#import "RanVideoTrackPreview.h"
#import "MediaTimelineRuler.h"
#import "MediaSegment.h"
#import "EditorData.h"
#import "MutilpleTrackContentView.h"

@interface RanMediaTimeline()<UIScrollViewDelegate,VideoSegmentViewDelegate>

@property (nonatomic, strong) UIView *scrollViewContentView;
@property (nonatomic, strong) RanMediaTimelineContainer *container;

@property (nonatomic, assign) CGFloat timeRule;
@property (nonatomic, strong) MASConstraint *rigthContraint;
@property (nonatomic, strong) MASConstraint *leftContraint;
@property (nonatomic, strong) RanVideoSegmentView *firstSegmentView;
@property (nonatomic, strong) RanSegmentClipView *segmentClipView;
@property (nonatomic, strong) RanVideoTrackPreview *trackPreView;
@property (nonatomic, strong) MediaTimelineRuler *ruler;

@property (nonatomic, strong) MutilpleTrackContentView *trackContentView;


@end

@implementation RanMediaTimeline

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        uint64_t timeScale = 1000000;
        self.backgroundColor = [UIColor blackColor];
        self.timeRule = (CGFloat)[UIScreen mainScreen].bounds.size.width / (8 * timeScale);
        self.clipsViews = [NSMutableArray arrayWithCapacity:0];
        [self initSubViews];
    }
    return self;
}

- (void)reloadDa {
    UIEdgeInsets bottomEdge;
    if (@available(iOS 11.0, *)) {
        bottomEdge = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
    }
    bottomEdge = UIEdgeInsetsZero;
    
    self.trackContentView = [[MutilpleTrackContentView alloc] initWithFrame:CGRectZero];
    [self.container addSubview:self.trackContentView];
    [self.trackContentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.trackPreView);
        make.top.equalTo(self.trackPreView.mas_bottom);
        make.bottom.equalTo(self.container).offset(-bottomEdge.bottom-90);
    }];
    [self.trackContentView reloadTracksData];
}

- (void)initSubViews {
    
    self.showsVerticalScrollIndicator = NO;
    self.showsHorizontalScrollIndicator = NO;
    CGFloat mainOffset = [UIScreen mainScreen].bounds.size.width / 2.0;
    self.delegate = self;

    self.scrollViewContentView = [UIView new];
    self.scrollViewContentView.backgroundColor = [UIColor blackColor];
    [self addSubview:self.scrollViewContentView];
    [self.scrollViewContentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.bottom.equalTo(self);
        make.height.equalTo(self);
    }];
    
    self.container = [RanMediaTimelineContainer new];
    [self.scrollViewContentView addSubview:self.container];
    [self.container mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.scrollViewContentView);
        make.bottom.equalTo(self.scrollViewContentView);
        make.left.equalTo(self.scrollViewContentView);
        make.right.equalTo(self.scrollViewContentView);
    }];
    
    self.trackPreView = [RanVideoTrackPreview new];
    [self.container addSubview:self.trackPreView];
    
    self.ruler = [[MediaTimelineRuler alloc] init];
    [self.container addSubview:self.ruler];
    [self.ruler mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.trackPreView);
        make.top.equalTo(self.container.mas_top);
        make.height.mas_equalTo(24);
    }];
    

    [self.trackPreView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.container).offset(mainOffset);
        make.top.equalTo(self.ruler.mas_bottom).offset(5);
        make.height.mas_equalTo(76);
        make.right.equalTo(self.container).inset(mainOffset);
    }];
    
//    [self reloadDa];
}

- (void)insertRangeView:(RanVideoSegmentView *)view atIndex:(NSInteger)index {
    if (!view.superview) {
        [self.trackPreView addSubview:view];
    }
    if (!view.delegate) {
        view.delegate = self;
    }
    if (index == 0) {
        [view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.trackPreView).offset(15);
            make.height.mas_equalTo(50);
            _rigthContraint = make.right.equalTo(self.trackPreView);
            _leftContraint = make.left.equalTo(self.trackPreView);
        }];
        self.firstSegmentView = view;
        


//            UIView *leftRedView = [UIView new];
//            leftRedView.backgroundColor = [UIColor redColor];
//            [self.scrollViewContentView addSubview:leftRedView];
//            [leftRedView mas_makeConstraints:^(MASConstraintMaker *make) {
//                make.right.equalTo(clipView.mas_left).inset(50);
//                make.centerY.equalTo(self);
//                make.width.height.mas_equalTo(50);
//            }];
    } else {
        if (index >= self.clipsViews.count) {
            RanVideoSegmentView *leftView = self.clipsViews.lastObject;
            [_rigthContraint uninstall];
            
            NSInteger tranIndex = index - 1;
            NSMutableArray *transitions = [EditorData sharedInstance].materials.transitions;
            
            CGFloat offset = 0;
            
            if (tranIndex < transitions.count) {
                EditorTransition *transiton = [EditorData sharedInstance].materials.transitions[index - 1];
                offset = transiton.duration * self.timeRule;
            }
            
            [leftView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.right.equalTo(view.mas_left).inset(-offset); //有转场
            }];

            [view mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(self.trackPreView).offset(15);
                make.height.mas_equalTo(50);
                _rigthContraint = make.right.equalTo(self.trackPreView);
            }];
            
            if (offset > 0) {
                UIButton *transitionButton = [UIButton new];
                transitionButton.backgroundColor = [UIColor whiteColor];
                [view.superview addSubview:transitionButton];
                [transitionButton mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.centerY.equalTo(view);
                    make.size.mas_equalTo(CGSizeMake(25, 25));
                    make.centerX.equalTo(view.mas_left).offset(offset*0.5);
                }];
            }
        } else if (index == 0) {
            RanVideoSegmentView *rightView = self.clipsViews.firstObject;
            [_rigthContraint uninstall];

            [view mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.trackPreView);
                make.top.equalTo(self.trackPreView).offset(15);
                make.height.mas_equalTo(50);
                make.right.equalTo(rightView);
            }];
        } else {
            NSLog(@"left  right");
//            RanVideoSegmentView *leftView = self.clipsViews[index - 1];
//            RanVideoSegmentView *rightView = self.clipsViews[index];
//
//            [leftView mas_updateConstraints:^(MASConstraintMaker *make) {
//
//            }];
//
//            [rightView mas_updateConstraints:^(MASConstraintMaker *make) {
//                make.right.equalTo(view.mas_left).offset(30);
//            }];
//
//            [view mas_makeConstraints:^(MASConstraintMaker *make) {
//                make.top.bottom.equalTo(self.trackPreView);
//                make.right.equalTo(rightView.mas_left).offset(30);
//            }];

        }
    }
    [self.clipsViews insertObject:view atIndex:index];
}

- (void)removeTrackClipView {
    [self.segmentClipView removeFromSuperview];
}

- (RanVideoSegmentView *)createSegmentView:(VideoClipModel *)clipModel {
    uint64_t timeScale = 1000000;
    RanVideoSegmentView *clipView = [RanVideoSegmentView new];
//    clipModel.trimIn = 2000000;
    clipView.delegate = self;
    [self.trackPreView addSubview:clipView];
    return clipView;
}

- (void)addContentMutilTracks {
    
}

- (void)initSubviewsWithSegments:(NSMutableArray *)segments {
    for (int i = 0; i < segments.count; i ++) {
        MediaSegment *segment = segments[i];
        RanVideoSegmentView *clipView = [RanVideoSegmentView new];
        clipView.segment = segment;
        clipView.delegate = self;
        if (i > 0) {
            // 假设转场时长为1s 一半为0.5s
            NSInteger tranIndex = i - 1;
            NSMutableArray *transitions = [EditorData sharedInstance].materials.transitions;
            
            uint64_t transition_time = 0;
            
            if (tranIndex < transitions.count) {
                EditorTransition *transiton = [EditorData sharedInstance].materials.transitions[tranIndex];
                transition_time = transiton.duration;
            }
            
            CGFloat triangleWidth = self.timeRule * transition_time;
            CGFloat showWidth = self.timeRule * segment.source_timerange.duration;
            CGFloat triangleHeight = 50;
            clipView.backgroundColor = [UIColor greenColor];
            UIBezierPath *trianglePath = [[UIBezierPath alloc] init];
            [trianglePath moveToPoint:CGPointMake(15, triangleHeight)];
            [trianglePath addLineToPoint:CGPointMake(triangleWidth, 0)];
            [trianglePath addLineToPoint:CGPointMake(showWidth, 0)];
            [trianglePath addLineToPoint:CGPointMake(showWidth, triangleHeight)];
            [trianglePath closePath];
            CAShapeLayer *shaperLayer = [CAShapeLayer layer];
            shaperLayer.path = trianglePath.CGPath;
            clipView.layer.mask = shaperLayer;
        }
        [self insertRangeView:clipView atIndex:i];
    }
}

- (void)videoSegmentViewClick:(RanVideoSegmentView *)segmentView {
    self.selectedSegmentView = segmentView;
    
    [self.trackPreView bringSubviewToFront:segmentView];
    
    if (self.segmentClipView.superview == nil) {
        self.segmentClipView.delegate = self;
        [self.trackPreView addSubview:self.segmentClipView];
    }
    CGFloat leftOffset = 21;
    CGFloat topOffset = 1.5;
    [self.segmentClipView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(segmentView).offset(-21);
        make.right.equalTo(segmentView).offset(21);
        make.top.equalTo(segmentView).offset(-1);
        make.bottom.equalTo(segmentView).offset(1);
    }];
    
//    self.segmentClipView.frame = CGRectMake(segmentView.frame.origin.x-leftOffset,-topOffset, segmentView.frame.size.width+2*leftOffset, segmentView.frame.size.height+2*topOffset);
}

- (void)displayRangeViewsIfNeed {
    NSArray<RanVideoSegmentView *> *visiableRangeViews = [self fetchVisiableRangeViews];
    [visiableRangeViews enumerateObjectsUsingBlock:^(RanVideoSegmentView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj updateDataIfNeed];
    }];
}

- (NSArray<RanVideoSegmentView *> *)fetchVisiableRangeViews {
    NSMutableArray *rangeViews = [NSMutableArray array];
    [self.clipsViews enumerateObjectsUsingBlock:^(RanVideoSegmentView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        CGRect rect = [obj.superview convertRect:obj.frame toView:self];
        BOOL intersects = CGRectIntersectsRect(self.bounds, rect);
        if (intersects) {
            [rangeViews addObject:obj];
        }
    }];
    return rangeViews;
}

- (void)removeRangeViewAtIndex:(NSInteger)index animated:(BOOL)animated completion:(void(^)(void))completion {
    if (index < 0 || index >= self.clipsViews.count) {
        return;
    }
    RanVideoSegmentView *rangeView = self.clipsViews[index];
//    CGFloat contentWidth = rangeView.createContentWidth.width;
    
    void(^completionHandler)(void) = ^{
        [rangeView removeFromSuperview];
        if (self.clipsViews.count > 1) {
            if (index == 0) {
                RanVideoSegmentView *rightRangeView = self.clipsViews[index + 1];
//                [rightRangeView updateLeftConstraint:^NSLayoutConstraint * _Nonnull{
//                    return [rightRangeView.leftAnchor constraintEqualToAnchor:rightRangeView.superview.leftAnchor];
//                }];
                [rightRangeView mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.left.equalTo(rightRangeView.superview.mas_left);
                }];
            } else if (index == self.clipsViews.count - 1) {
                RanVideoSegmentView *leftRangeView = self.clipsViews[index - 1];
//                [leftRangeView updateRightConstraint:^NSLayoutConstraint * _Nonnull{
//                    return [leftRangeView.rightAnchor constraintEqualToAnchor:leftRangeView.superview.rightAnchor];
//                }];
                [leftRangeView mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.right.equalTo(leftRangeView.superview.mas_right);
                }];
            } else {
                RanVideoSegmentView *rightRangeView = self.clipsViews[index + 1];
                RanVideoSegmentView *leftRangeView = self.clipsViews[index - 1];
//                [leftRangeView updateRightConstraint:^NSLayoutConstraint * _Nonnull{
//                    CGFloat offset = (rightRangeView.contentInset.left + leftRangeView.contentInset.right) - (self.rangeViewLeftInset + self.rangeViewRightInset);
//                    return [leftRangeView.rightAnchor constraintEqualToAnchor:rightRangeView.leftAnchor constant:offset];
//                }];
                
                [leftRangeView mas_updateConstraints:^(MASConstraintMaker *make) {
//                    CGFloat offset = (rightRangeView.contentInset.left + leftRangeView.contentInset.right) - (self.rangeViewLeftInset + self.rangeViewRightInset);
//                    CGFloat offset = 0;
                    [leftRangeView mas_updateConstraints:^(MASConstraintMaker *make) {
                        make.right.equalTo(rightRangeView.mas_left);
                    }];
                }];
            }
        }
        
        [self.clipsViews removeObjectAtIndex:index];
        if (completion) {
            completion();
        }
    };
    
    if (animated) {
//        [self.scrollRangeContentView insertSubview:rangeView atIndex:0];
//        [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//            if (self.rangeViews.count > 1) {
//                if (index == 0) {
//                    VIRangeView *rightRangeView = self.rangeViews[index + 1];
//                    [rangeView updateRightConstraint:^NSLayoutConstraint * _Nonnull{
//                        return [rangeView.rightAnchor constraintEqualToAnchor:rightRangeView.leftAnchor constant:(contentWidth + rangeView.contentInset.right + rightRangeView.contentInset.left)];
//                    }];
//                } else if (index == self.rangeViews.count - 1) {
//                    VIRangeView *leftRangeView = self.rangeViews[index - 1];
//                    [leftRangeView updateRightConstraint:^NSLayoutConstraint * _Nonnull{
//                        return [leftRangeView.rightAnchor constraintEqualToAnchor:rangeView.leftAnchor constant:(contentWidth + rangeView.contentInset.left + leftRangeView.contentInset.right)];
//                    }];
//                } else {
//                    VIRangeView *rightRangeView = self.rangeViews[index + 1];
//                    [rangeView updateRightConstraint:^NSLayoutConstraint * _Nonnull{
//                        return [rangeView.rightAnchor constraintEqualToAnchor:rightRangeView.leftAnchor constant:(contentWidth + rangeView.contentInset.right + rightRangeView.contentInset.left)];
//                    }];
//                }
//            }
//
//            rangeView.alpha = 0.0;
//            rangeView.transform = CGAffineTransformMakeScale(0.5, 0.5);
//
//            [self layoutIfNeeded];
//        } completion:^(BOOL finished) {
//            completionHandler();
//        }];
    } else {
        completionHandler();
    }
    
}

- (void)outClick:(RanVideoSegmentView *)segmentView {
    [self videoSegmentViewClick:segmentView];
}


- (void)leftControlView:(UIPanGestureRecognizer *)ges withWidthChange:(CGFloat)widthOffset withRect:(CGRect)rect {
//    CGFloat leftOffset = 21;
//    CGFloat topOffset = 1.5;
//    RanVideoSegmentView *thumbnailView = (RanVideoSegmentView *)self.selectedSegmentView;
//    if (ges.state == UIGestureRecognizerStateBegan) {
//        [_leftContraint uninstall];
//        [self.selectedSegmentView mas_updateConstraints:^(MASConstraintMaker *make) {
//            _leftContraint = make.left.equalTo(self.segmentClipView.mas_left).offset(21);
//        }];
//    } else if (ges.state == UIGestureRecognizerStateChanged) {
//        //宽
//        MediaTrackSegment *segment = thumbnailView.segment;
//        // 改start
//        NSLog(@"final-> %@",NSStringFromCGRect(rect));
//        NSLog(@"...----%f",(rect.size.width - 2 * 21) / self.timeRule);
//        segment.source = CMTimeRangeMake(segment.source.start, CMTimeMake((1000 - 2 * 21) / self.timeRule, thumbnailView.segment.source.duration.timescale));
//        thumbnailView.segment = segment;
//
//    } else if (ges.state == UIGestureRecognizerStateEnded) {
//
//        [_leftContraint uninstall];
//        [self.firstSegmentView mas_updateConstraints:^(MASConstraintMaker *make) {
//            _leftContraint = make.left.equalTo(self.trackPreView);
//        }];
////        [[NSNotificationCenter defaultCenter] postNotificationName:@"Connect" object:nil];
//
//
//    }
}

- (void)rightControlView:(UIPanGestureRecognizer *)ges withWidthChange:(CGFloat)widthOffset withRect:(CGRect)rect {
//    CGFloat leftOffset = 21;
//    CGFloat topOffset = 1.5;
//    RanVideoSegmentView *thumbnailView = (RanVideoSegmentView *)self.selectedSegmentView;
//    if (ges.state == UIGestureRecognizerStateBegan) {
//
//    } else if (ges.state == UIGestureRecognizerStateChanged) {
//        //宽
//        MediaTrackSegment *segment = thumbnailView.segment;
//        NSLog(@"...----%f",rect.size.width - 2 * 21 / self.timeRule);
//        segment.source = CMTimeRangeMake(segment.source.start, CMTimeMake((rect.size.width - 2 * 21) / self.timeRule, thumbnailView.segment.source.duration.timescale));
//        thumbnailView.segment = segment;
//
//    } else if (ges.state == UIGestureRecognizerStateEnded) {
//
//    }
}


- (RanSegmentClipView *)segmentClipView {
    if (!_segmentClipView) {
        _segmentClipView = [RanSegmentClipView new];
    }
    return _segmentClipView;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint converPoint = [self convertPoint:point toView:self.segmentClipView];
    if (CGRectContainsPoint(self.segmentClipView.bounds, converPoint)) {
        if (CGRectContainsPoint(CGRectMake(0, 0, 21, 50), converPoint)) {
            return self.segmentClipView.leftControl;
        } else if (CGRectContainsPoint(CGRectMake(self.segmentClipView.bounds.size.width - 21, 0, 21, 50), converPoint)) {
            return self.segmentClipView.rightControl;
        }
        
    }
    return [super hitTest:point withEvent:event];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self displayRangeViewsIfNeed];
}

- (void)calTotalLength {
    
}

@end
