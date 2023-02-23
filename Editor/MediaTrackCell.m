//
//  MediaTrackCell.m
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/9.
//

#import "MediaTrackCell.h"
//#import "VideoClipModel.h"

@interface MediaTrackCell()

@property (nonatomic, strong) UILabel *leftLabel;

@end

@implementation MediaTrackCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIView *bgView = [UIView new];
        bgView.layer.cornerRadius = 2;
        bgView.layer.masksToBounds = YES;
        bgView.backgroundColor = [UIColor orangeColor];
        [self.contentView addSubview:bgView];
        [bgView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.right.bottom.equalTo(self.contentView);
        }];
        
        self.leftLabel = [UILabel new];
        [bgView addSubview:self.leftLabel];
        [self.leftLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(bgView);
            make.left.equalTo(bgView).offset(8);
            make.width.mas_equalTo(14);
            make.height.mas_equalTo(12);
        }];
        self.leftLabel.textColor = [UIColor blackColor];
        self.leftLabel.font = [UIFont fontWithName:@"PingFangSC-Semibold" size:8];
        self.leftLabel.text = @"主";
    }
    return self;
}

//- (void)setBaseModel:(VideoClipModel *)baseModel {
//    _baseModel = baseModel;
////    self.leftLabel.text = [NSString stringWithFormat:@"%lld",baseModel.inpoint];
//}

- (void)panAdjustFrame:(CGRect)rect {
    self.frame = rect;
}


- (void)setSelected:(BOOL)selected {
    
}

@end
