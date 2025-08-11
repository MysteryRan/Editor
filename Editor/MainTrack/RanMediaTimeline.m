//
//  RanMediaTimeline.m
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/17.
//

#import "RanMediaTimeline.h"
#import "Masonry.h"
#import "RanMediaTimelineContainer.h"
#import "RanVideoTrackPreview.h"
#import "MediaTimelineRuler.h"
#import "MediaSegment.h"
#import "EditorData.h"
#import "MutilpleTrackContentView.h"

@interface RanMediaTimeline()<UIScrollViewDelegate>

@property (nonatomic, strong) UIView *scrollViewContentView;
@property (nonatomic, strong) RanMediaTimelineContainer *container;

@property (nonatomic, assign) CGFloat timeRule;
@property (nonatomic, strong) MASConstraint *rigthContraint;
@property (nonatomic, strong) MASConstraint *leftContraint;
@property (nonatomic, strong) RanVideoSegmentView *firstSegmentView;
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
    
    [self reloadDa];
}

@end
