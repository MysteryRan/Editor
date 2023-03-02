//
//  RanVideoSegmentView.m
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/18.
//

#import "RanVideoSegmentView.h"
#import "VideoThumbnailView.h"
#import "Masonry.h"
#import "MediaSegment.h"

@interface RanVideoSegmentView()

@property (nonatomic, strong)UIView *contentContainerView;
@property (nonatomic, strong)VideoThumbnailView *thumbnailView;
@property (nonatomic, strong) MASConstraint *leftc;

@end

@implementation RanVideoSegmentView

- (void)updateDataIfNeed {
    [self.thumbnailView updateDataIfNeed];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.thumbnailView = [VideoThumbnailView new];
        [self addSubview:self.thumbnailView];
        [self.thumbnailView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(segmentClick)];
        [self addGestureRecognizer:tap];
        
        self.clipsToBounds = YES;
        self.layer.masksToBounds = YES;
    }
    return self;
}

- (void)segmentClick {
    UIBezierPath *trianglePath = [UIBezierPath bezierPath];
    UIView *triangleView = [UIView new];
    triangleView.backgroundColor = [UIColor redColor];
    [self addSubview:triangleView];
    [triangleView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.top.bottom.equalTo(self);
        make.width.mas_equalTo(30);//转场时长
    }];
    CGPoint point = CGPointZero;
    [trianglePath moveToPoint:CGPointMake(30, 0)];
    [trianglePath addLineToPoint:CGPointMake(30, 50)];
    [trianglePath addLineToPoint:CGPointMake(0, 50)];
    [trianglePath closePath];
    [[UIColor redColor] setFill];
    [trianglePath fill];
        CAShapeLayer *shaperLayer = [CAShapeLayer layer];
        shaperLayer.path = trianglePath.CGPath;
        triangleView.layer.mask = shaperLayer;
    [self.superview bringSubviewToFront:self];
    if (_delegate && [_delegate respondsToSelector:@selector(videoSegmentViewClick:)]) {
        [_delegate videoSegmentViewClick:self];
    }
}

- (CGSize)createContentWidth {
    CGFloat timeScale = 1000000;
    CGFloat timeRule = (CGFloat)[UIScreen mainScreen].bounds.size.width / (8 * timeScale);
    if (self.segment == nil) {
        return CGSizeMake(500, 50);
    } else {
        return CGSizeMake(self.segment.source_timerange.duration * timeRule, 50);
    }
}

- (CGSize)intrinsicContentSize {
//    NSLog(@"contentwidth -> %lld",self.segment.source.duration.value / self.segment.source.duration.timescale);
    return [self createContentWidth];
}

- (void)setSegment:(MediaSegment *)segment {
    _segment = segment;
    
    self.thumbnailView.path = [segment segmentFindVideo].path;
    [self invalidateIntrinsicContentSize];
}


@end
