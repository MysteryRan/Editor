//
//  MediaTimelineRuler.m
//  Editor
//
//  Created by zouran on 2022/5/17.
//

#import "MediaTimelineRuler.h"

@implementation MediaTimelineRuler

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.layer.sublayers = nil;
    [self setupTime];
}

- (void)setupTime {
    CGFloat perSec = [UIScreen mainScreen].bounds.size.width / 2.0 / 4000000.0;
    CGFloat time = self.frame.size.width / perSec;
    CGFloat labelCount = ceil(time / 1000000);
    for (int i = 0; i < labelCount + 1; i ++) {
        if (i % 2 == 0) {
            CATextLayer *text = [CATextLayer layer];
            text.string = [self coverSecond:i];
            text.bounds = CGRectMake(0, 0, 28, 13);
            text.fontSize = 10.0;
            text.alignmentMode = kCAAlignmentCenter;
            text.position = CGPointMake(i * 1000000 * perSec, self.frame.size.height / 2.0);
            text.contentsScale = [UIScreen mainScreen].scale;
            text.foregroundColor = [UIColor whiteColor].CGColor;
            [self.layer addSublayer:text];
        } else {
            UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(i * 1000000 * perSec, self.frame.size.height / 2.0) radius:2 startAngle:0 endAngle:M_PI * 2 clockwise:true];
            CAShapeLayer *shaperLayer = [CAShapeLayer layer];
            shaperLayer.frame = CGRectMake(0, 0, 0, 0);
            shaperLayer.lineCap = kCALineCapSquare;
            shaperLayer.path = path.CGPath;
            shaperLayer.lineWidth = 4.0;
            [self.layer addSublayer:shaperLayer];
        }
    }
}

- (NSString *)coverSecond:(CGFloat)seconds {
    NSUInteger minute = (NSUInteger)(seconds / 60);
    NSUInteger second = (NSUInteger)((NSUInteger)seconds % 60);
    return [NSString stringWithFormat:@"%02d:%02d", (int)minute, (int)second];
}

@end
