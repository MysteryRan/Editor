//
//  GuidelineView.m
//  Editor
//
//  Created by zouran on 2023/3/2.
//

#import "GuidelineView.h"

@interface GuidelineView()

@property (strong, nonatomic) UIButton *leftTop;
@property (strong, nonatomic) UIButton *rightTop;
@property (strong, nonatomic) UIButton *leftBottom;
@property (assign, nonatomic) CGPoint leftTopPoint;
@property (assign, nonatomic) CGPoint rightTopPoint;
@property (assign, nonatomic) CGPoint rightBottompPoint;
@property (assign, nonatomic) CGPoint leftBottomPoint;
@property (assign, nonatomic) BOOL isInRect;
@property (assign, nonatomic) BOOL isTouchUpInsideStatus;//用于标识是否是点击

@property (assign, nonatomic) BOOL isHiddenRotation;//

@property (nonatomic, assign) NSTimeInterval begin; //开始按下的时间
@property (nonatomic, assign) NSTimeInterval end; //结束按下的时间
@property (nonatomic, assign) CGPoint beginPoint; //开始按下的点
@property (nonatomic, assign) CGPoint endPoint; //结束按下的点

@property (nonatomic, assign) BOOL rollout; //是否划出屏幕

@property (nonatomic, assign) BOOL isMoved;//是否是移动控件
@property (nonatomic, assign) BOOL isRotating;//是否是旋转控件
@property (nonatomic, assign) BOOL isHorizontalCenter;//水平居中
@property (nonatomic, assign) BOOL isVerticalCenter;//垂直居中
@property (nonatomic, assign) BOOL isRotatingCenter;//旋转

@end

@implementation GuidelineView

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    self.isTouchUpInsideStatus = YES;
    self.rollout = NO;
    self.isMoved = NO;
    self.begin = [NSDate date].timeIntervalSince1970*1000;
    NSUInteger toucheNum = [[event allTouches] count];//有几个手指触摸屏幕
    if ( toucheNum > 2 ) {
        return;//多个手指不执行旋转
    }else if (toucheNum == 2) {
        self.isRotating = YES;
        // 双指缩放
        NSArray *touchesArray = [event.allTouches allObjects];
        CGPoint currentPointOne = [[touchesArray objectAtIndex:0] locationInView:self];
        CGPoint currentPointTwo = [[touchesArray objectAtIndex:1] locationInView:self];
//        if (self.delegate && [self.delegate respondsToSelector:@selector(rectView:rotationBeganPoint:center:)]) {
//            [self.delegate rectView:self rotationBeganPoint:CGPointMake(currentPointOne.x - currentPointTwo.x, currentPointOne.y - currentPointTwo.y) center:[self getCenter]];
//        }
        return ;
    }
    
    //self.tranformView，你想旋转的视图
//    if (![touch.view isEqual:self]) {
//        return;
//    }
    
    CGPoint currentPoint = [touch locationInView:touch.view];//当前手指的坐标
    self.beginPoint = currentPoint;
//    if ([self.delegate respondsToSelector:@selector(rectView:touchBeganPoint:)]) {
//        [self.delegate rectView:self touchBeganPoint:currentPoint];
//    }
    
    
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    self.isTouchUpInsideStatus = NO;
    UITouch *touch = [touches anyObject];
    
//    if (self.rollout) {
//        return;
//    }
    
    NSUInteger toucheNum = [[event allTouches] count];//有几个手指触摸屏幕
    if ( toucheNum > 2 ) {
        return;//多个手指不执行旋转
    }else if (toucheNum == 2) {
        self.isRotating = YES;
        // 双指缩放
        NSArray *touchesArray = [event.allTouches allObjects];
        CGPoint currentPointOne = [[touchesArray objectAtIndex:0] locationInView:self];
        CGPoint currentPointTwo = [[touchesArray objectAtIndex:1] locationInView:self];
         CGFloat currentDistance = sqrt(pow(currentPointOne.x - currentPointTwo.x, 2.0f) + pow(currentPointOne.y - currentPointTwo.y, 2.0f));
        CGPoint previousPointOne = [[touchesArray objectAtIndex:0] previousLocationInView:touch.view];
        CGPoint previousPointTwo = [[touchesArray objectAtIndex:1] previousLocationInView:touch.view];
        CGFloat previousDistance = sqrt(pow(previousPointOne.x - previousPointTwo.x, 2.0f) + pow(previousPointOne.y - previousPointTwo.y, 2.0f));

        CGFloat angle = atan2f(currentPointTwo.y - currentPointOne.y, currentPointTwo.x - currentPointOne.x) - atan2f(previousPointTwo.y - previousPointOne.y, previousPointTwo.x - previousPointOne.x);
        // 旋转
        if (self.isRotating) {
            if (fabs(angle) < 0.02 && self.isRotatingCenter) {
                angle = 0;
            }
        }

        CGFloat scale = currentDistance / previousDistance;
//        if ([self.delegate respondsToSelector:@selector(rectView:rotate:scale:)]) {
//            [self.delegate rectView:self rotate:-angle*180/M_PI scale:scale];
//        }
        return ;
    }
     self.isMoved = YES;
    //self.tranformView，你想旋转的视图
//    if (![touch.view isEqual:self]) {
//        return;
//    }
    
//    CGPoint center = [self getCenter];
    CGPoint currentPoint = [touch locationInView:touch.view];//当前手指的坐标
    CGPoint previousPoint = [touch previousLocationInView:touch.view];//上一个坐标

    UIView *superView = self.superview;
    CGPoint superPoint = [self convertPoint:currentPoint toView:superView.superview];
    if (!CGRectContainsPoint(superView.superview.bounds, superPoint)) {
        return;
    }
//    if (!CGRectContainsPoint(self.superview.bounds, superPoint)) {
//        self.rollout = YES;
//        return;
//    }
    
    float x = currentPoint.x-previousPoint.x;
    float y = currentPoint.y-previousPoint.y;
//    NSInteger s = 10;//跟边界的距离
//
//    float minx = currentPoint.x;
//    float maxx = currentPoint.x;
//    float miny = currentPoint.y;
//    float maxy = currentPoint.y;
//    //向左滑
//    if (x<0) {
//        if ((minx-s)<=0) {
//            return;
//        }
//    } else {//向右滑
//        if ((maxx+s)>=self.frame.size.width) {
//            return;
//        }
//    }
//    //向上滑
//    if (y<0) {
//        if ((miny-s)<=0) {
//            return;
//        }
//    } else {//向下滑
//        if ((maxy+s)>=self.frame.size.height) {
//            return;
//        }
//    }

 //   if(self.isInRect) {
        /// 移动吸附
        if (self.isMoved) {
            CGFloat centerX = (self.leftTopPoint.x + self.rightBottompPoint.x)/2;
            if (fabs(centerX - self.center.x) < 1) {
                centerX = centerX + x;
                if (fabs(centerX - self.center.x) < 2) {
                    CGFloat offsetX = self.center.x - centerX;
                    currentPoint = CGPointMake(currentPoint.x + offsetX, currentPoint.y);
                }
            }
            CGFloat centerY = (self.leftTopPoint.y + self.rightBottompPoint.y)/2;
            if (fabs(centerY - self.center.y) < 1) {
                centerY = centerY + y;
                if (fabs(centerY - self.center.y) < 2) {
                    CGFloat offsetY = self.center.y - centerY;
                    currentPoint = CGPointMake(currentPoint.x, currentPoint.y + offsetY);
                }
            }
        }
//        if ([self.delegate respondsToSelector:@selector(rectView:currentPoint:previousPoint:)]) {
//            [self.delegate rectView:self currentPoint:currentPoint previousPoint:previousPoint];
//        }
  //  }
    [super touchesMoved:touches withEvent:event];
}


- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSLog(@"touchesEnded");
    self.isInRect = false;
    self.isMoved = NO;
    self.isRotating = NO;
    
    UITouch *touch = [touches anyObject];
    NSUInteger toucheNum = [[event allTouches] count];//有几个手指触摸屏幕
    if ( toucheNum > 2 ) {
        return;//多个手指不执行旋转
    }else if (toucheNum == 2) {
        // 双指缩放
        NSArray *touchesArray = [event.allTouches allObjects];
        CGPoint currentPointOne = [[touchesArray objectAtIndex:0] locationInView:self];
        CGPoint currentPointTwo = [[touchesArray objectAtIndex:1] locationInView:self];
//        if (self.delegate && [self.delegate respondsToSelector:@selector(rectView:rotationEndedPoint:center:)]) {
//            [self.delegate rectView:self rotationEndedPoint:CGPointMake(currentPointOne.x - currentPointTwo.x, currentPointOne.y - currentPointTwo.y) center:[self getCenter]];
//        }
        return ;
    }
//    //self.tranformView，你想旋转的视图
//    if (![touch.view isEqual:self]) {
//        return;
//    }
    CGPoint currentPoint = [touch locationInView:touch.view];//当前手指的坐标
    
//    if ([self.delegate respondsToSelector:@selector(rectView:touchesEnded:)]) {
//        [self.delegate rectView:self touchesEnded:currentPoint];
//    }
    self.end = [NSDate date].timeIntervalSince1970*1000;
    NSLog(@"按压时间：%f",self.end-self.begin);
    self.endPoint = currentPoint;
    float offset = [self offsetStartPoint:self.beginPoint endPoint:self.endPoint];
    /*
    单独isTouchUpInsideStatus来判断在iphone8上iOS12系统上，单击屏幕会出发touchmove，可能是硬件传感器过于灵敏导致的也可能是系统差异，所以改为通过移动偏移量和按压时间来判断
    */
    if (/*self.isTouchUpInsideStatus && */offset < 3 && (self.begin-self.end)<150) {
        //只是点击事件
        NSLog(@"只是点击事件:%d",self.isTouchUpInsideStatus);
//        if ([self.delegate respondsToSelector:@selector(rectView:touchUpInside:)]) {
//            [self.delegate rectView:self touchUpInside:currentPoint];
//        }
    } else {
//        if ([self.delegate respondsToSelector:@selector(rectView:touchesNotJustTouchEnded:)]) {
//            [self.delegate rectView:self touchesNotJustTouchEnded:currentPoint];
//        }
    }
    [self setNeedsDisplay];
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    NSLog(@"touchesCancelled");
    self.isInRect = false;
    self.isMoved = NO;
    self.isRotating = NO;
    
    UITouch *touch = [touches anyObject];
    NSUInteger toucheNum = [[event allTouches] count];//有几个手指触摸屏幕
    if (toucheNum == 2) {
        // 双指缩放
        NSArray *touchesArray = [event.allTouches allObjects];
        CGPoint currentPointOne = [[touchesArray objectAtIndex:0] locationInView:self];
        CGPoint currentPointTwo = [[touchesArray objectAtIndex:1] locationInView:self];
//        if (self.delegate && [self.delegate respondsToSelector:@selector(rectView:rotationEndedPoint:center:)]) {
//            [self.delegate rectView:self rotationEndedPoint:CGPointMake(currentPointOne.x - currentPointTwo.x, currentPointOne.y - currentPointTwo.y) center:[self getCenter]];
//        }
        return ;
    }else if ( toucheNum > 1 ) {
        return;//多个手指不执行旋转
    }
    //self.tranformView，你想旋转的视图
//    if (![touch.view isEqual:self]) {
//        return;
//    }
    CGPoint currentPoint = [touch locationInView:touch.view];//当前手指的坐标
    
//    if ([self.delegate respondsToSelector:@selector(rectView:touchesEnded:)]) {
//        [self.delegate rectView:self touchesEnded:currentPoint];
//    }
    
    self.end = [NSDate date].timeIntervalSince1970*1000;
    NSLog(@"按压时间：%f",self.end-self.begin);
    self.endPoint = currentPoint;
    float offset = [self offsetStartPoint:self.beginPoint endPoint:self.endPoint];
    if (/*self.isTouchUpInsideStatus && */offset < 3 && (self.begin-self.end)<150) {
        //只是点击事件
        NSLog(@"只是点击事件:%d",self.isTouchUpInsideStatus);
//        if ([self.delegate respondsToSelector:@selector(rectView:touchUpInside:)]) {
//            [self.delegate rectView:self touchUpInside:currentPoint];
//        }
    }
    [self setNeedsDisplay];
    [super touchesCancelled:touches withEvent:event];
}


- (float)offsetStartPoint:(CGPoint)startPoint endPoint:(CGPoint)endPoint {
    CGFloat offset = sqrtf(powf(startPoint.y - endPoint.y, 2)+powf(startPoint.x - endPoint.x, 2));
    return offset;
}

@end
