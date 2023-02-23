//
//  RanSegmentClipView.m
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/18.
//

#import "RanSegmentClipView.h"
#import "Masonry.h"

@interface RanSegmentClipView()<UIGestureRecognizerDelegate>


@property (nonatomic, strong) UIView *topLine;
@property (nonatomic, strong) UIView *bottomLine;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UIPanGestureRecognizer *rightPanGesture;

@end

@implementation RanSegmentClipView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.topLine];
        [self addSubview:self.bottomLine];
        [self addSubview:self.leftControl];
        [self addSubview:self.rightControl];
        
        [self.topLine mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.top.right.equalTo(self);
            make.height.mas_equalTo(1.5);
        }];
        
        [self.bottomLine mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.bottom.right.equalTo(self);
            make.height.mas_equalTo(1.5);
        }];
        
        [self.leftControl mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.top.bottom.equalTo(self);
            make.width.mas_equalTo(21);
        }];
        
        [self.rightControl mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.top.right.equalTo(self);
            make.width.mas_equalTo(21);
        }];
        
        UIPanGestureRecognizer *leftPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(leftControlHandleMove:)];
        leftPanGesture.delegate = self;
        [leftPanGesture setMinimumNumberOfTouches:1];
        [leftPanGesture setMaximumNumberOfTouches:2];
        [self.leftControl addGestureRecognizer:leftPanGesture];
        
        self.rightPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rightControlHandleMove:)];
        self.rightPanGesture.delegate = self;
        [self.rightPanGesture setMinimumNumberOfTouches:1];
        [self.rightPanGesture setMaximumNumberOfTouches:2];
        [self.rightControl addGestureRecognizer:self.rightPanGesture];
        
        self.clipsToBounds = YES;
        
    }
    return self;
}

-(void)createTimer{
    
    //初始化
    //_timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
         //执行操作
    //}];
    if (self.timer == nil) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(timerStart:) userInfo:nil repeats:YES];
        
        //加入runloop循环池
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
        
        //开启定时器
        [self.timer fire];
    }
}

- (void)timerStart:(NSTimer *)timer {
    CGPoint point2 = [self.rightPanGesture locationInView:[UIApplication sharedApplication].windows[0]];
    if (point2.x > [UIScreen mainScreen].bounds.size.width / 4.0 * 3) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(rightScroll:)]) {
            CGFloat width = self.frame.size.width;
            CGFloat newWidth = width += 1;
            NSLog(@"newwidth %f--%f",newWidth,self.frame.origin.x);
            self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, newWidth, self.frame.size.height);
            [self.delegate rightScroll:self.frame];
        }
        
//        if (self.delegate && [self.delegate respondsToSelector:@selector(rightControlView:withRect:)]) {
//            [self.delegate rightControlView:self.rightPanGesture withRect:self.frame];
//        }
    } else {
        if (self.timer) {
            [self.timer invalidate];
            self.timer = nil;
        }
    }
}

- (void)rightControlHandleMove:(UIPanGestureRecognizer *)gesture {
    
    CGPoint point = [gesture locationInView:self.superview];
    CGRect frame = self.frame;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.frame = frame;
        // 开定时器
//        [self createTimer];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint point2 = [gesture locationInView:[UIApplication sharedApplication].windows[0]];
//        if (point2.x > [UIScreen mainScreen].bounds.size.width / 4.0 * 3) {
//            [self createTimer];
//            return;
//        }
        
        
        CGFloat x = point.x;
        
        if ((x - frame.origin.x) < 20 + 2 * 21) {
            x = 20 + 2 * 21 + frame.origin.x;
            NSLog(@"right 最小");
            return;
        }
        
        CGFloat maxRight = self.rightLimit > 0 ? self.rightLimit : CGFLOAT_MAX;
        
        if (x > maxRight) {
            x = maxRight;
            NSLog(@"right 最大");
            return;
        }
        
        frame = CGRectMake(frame.origin.x, frame.origin.y, x - frame.origin.x, frame.size.height);
        self.frame = frame;
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        
        if (self.timer) {
            [self.timer invalidate];
            self.timer = nil;
        }
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(rightControlView:withWidthChange:withRect:)]) {
        [self.delegate rightControlView:gesture withWidthChange:0 withRect:self.frame];
    }
}

- (void)leftControlHandleMove:(UIPanGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.superview];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        
    }
    if (gesture.state == UIGestureRecognizerStateChanged) {
        CGRect frame = self.frame;
        CGFloat minX = self.leftLimit;
        CGFloat maxLeftWidth = self.maxWidth > 0 ? self.maxWidth : 20 + 2 * 21;
        CGFloat maxX = CGRectGetMaxX(frame) - maxLeftWidth;
        CGFloat x = point.x;
        NSLog(@"-----point %f",x);
        if (x < minX) { x = minX;
            NSLog(@"left 到最小");
            return;
        }
//        if (x > maxX) { x = maxX;
//            NSLog(@"left 到最大");
//            return;
//        }
//        if ((frame.origin.x - x + frame.size.width) < 20 + 2 * 21) {
//            x = frame.origin.x - (20 + 2 * 21) + frame.size.width;
//        }
        frame = CGRectMake(x, frame.origin.y, frame.origin.x - x + frame.size.width, frame.size.height);
        //移动中处理位置 是否有对应的线
        self.frame = frame;
        
        NSLog(@"%@",NSStringFromCGRect(self.frame));
    }
    
    
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(leftControlView:withWidthChange:withRect:)]) {
        [self.delegate leftControlView:gesture withWidthChange:0 withRect:self.frame];
    }
}


- (UIView *)leftControl {
    if (!_leftControl) {
        _leftControl = [UIView new];
        _leftControl.backgroundColor = [UIColor whiteColor];
    }
    return _leftControl;
}

- (UIView *)rightControl {
    if (!_rightControl) {
        _rightControl = [UIView new];
        _rightControl.backgroundColor = [UIColor whiteColor];
    }
    return _rightControl;
}

- (UIView *)topLine {
    if (!_topLine) {
        _topLine = [UIView new];
        _topLine.backgroundColor = [UIColor whiteColor];
    }
    return _topLine;
}

- (UIView *)bottomLine {
    if (!_bottomLine) {
        _bottomLine = [UIView new];
        _bottomLine.backgroundColor = [UIColor whiteColor];
    }
    return _bottomLine;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer.view == self.leftControl || gestureRecognizer.view == self.rightControl) {
        return NO;
    } else {
        return YES;
    }
}


@end
