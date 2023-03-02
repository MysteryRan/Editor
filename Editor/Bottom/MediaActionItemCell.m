//
//  MediaActionItemCell.m
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/24.
//

#import "MediaActionItemCell.h"
#import "Masonry.h"

@interface MediaActionItemCell()

@property (nonatomic, strong) UIImageView *actionImageView;
@property (nonatomic, strong) UILabel *actionLabel;

@end

@implementation MediaActionItemCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self.contentView addSubview:self.actionImageView];
        [self.contentView addSubview:self.actionLabel];
        [self.actionLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self.contentView).inset(13);
            make.centerX.equalTo(self.contentView);
        }];
        
        self.actionLabel.font = [UIFont fontWithName:@"PingFangSC-Regular" size:10];
        
//        [self.actionImageView mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.bottom.equalTo(self.actionLabel.mas_top);
//            make.centerX.equalTo(self.contentView);
//        }];
    }
    return self;
}

- (void)setItemModel:(MediaBottomActionItemModel *)itemModel {
    _itemModel = itemModel;
    self.actionLabel.text = itemModel.name;
}

//- (void)setAdjustModel:(RanAdjustModel *)adjustModel {
//    _adjustModel = adjustModel;
//    self.actionLabel.text = adjustModel.adjustName;
//}

- (UIImageView *)actionImageView {
    if (!_actionImageView) {
        _actionImageView = [[UIImageView alloc] init];
    }
    return _actionImageView;
}

- (UILabel *)actionLabel {
    if (!_actionLabel) {
        _actionLabel = [UILabel new];
        _actionLabel.textColor = [UIColor whiteColor];
        _actionLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _actionLabel;
}

@end
