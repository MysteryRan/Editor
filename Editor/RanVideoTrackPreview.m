//
//  RanVideoTrackPreview.m
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/17.
//

#import "RanVideoTrackPreview.h"
#import "Masonry.h"
#import "RanVideoSegmentView.h"

@interface RanVideoTrackPreview()<VideoSegmentViewDelegate>

@property (nonatomic, assign) CGFloat timeRule;
@property (nonatomic, strong) MASConstraint *widthContraint;
@property (nonatomic, strong) MASConstraint *leftContraint;
@property (nonatomic, strong) RanVideoSegmentView *selectedSegmentView;
@property (nonatomic, strong) RanVideoSegmentView *firstSegmentView;

@end

@implementation RanVideoTrackPreview

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        uint64_t timeScale = 1000000;
        self.timeRule = (CGFloat)[UIScreen mainScreen].bounds.size.width / (8 * timeScale);
//        self.segmentClipView = [RanSegmentClipView new];
    }
    return self;
}

//- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
//    
//    return [super pointInside:point withEvent:event];
//}

//- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
////    NSLog(@"red point - %@",NSStringFromCGPoint(point));
//    //
////    NSLog(@"%@",self.subviews);
//
//    for (UIView *f in self.subviews) {
////        NSLog(@"frame %@",NSStringFromCGRect(f.frame));
//        if (CGRectContainsPoint(f.frame, point)) {
////            NSLog(@"red hit");
//            return f;
//        }
//    }
//    return [super hitTest:point withEvent:event];
//}




@end
