//
//  MediaChooseListCell.m
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/7.
//

#import "MediaChooseListCell.h"
#import "Masonry.h"

@interface MediaChooseListCell ()



@end

@implementation MediaChooseListCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubViews];
    }
    return self;
}

- (void)setupSubViews {
    self.assetImageView = [UIImageView new];
    [self.contentView addSubview:self.assetImageView];
    [self.assetImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView);
        make.top.equalTo(self.contentView).offset(10);
        make.right.equalTo(self.contentView).inset(10);
        make.bottom.equalTo(self.contentView);
    }];
    
    UIButton *deleteButton = [UIButton new];
    [self.contentView addSubview:deleteButton];
    [deleteButton setImage:[UIImage imageNamed:@"album_delete"] forState:UIControlStateNormal];
    [deleteButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.top.equalTo(self.contentView);
        make.width.height.mas_equalTo(18);
    }];
    [deleteButton addTarget:self action:@selector(itemDeleteClick) forControlEvents:UIControlEventTouchUpInside];
}

- (void)itemDeleteClick {
    if (_didDeleteImage) {
        _didDeleteImage(self.index);
    }
}

- (UIImageView *)assetImageView {
    if (!_assetImageView) {
        _assetImageView = [[UIImageView alloc] init];
        _assetImageView.contentMode = UIViewContentModeScaleAspectFill;
    }
    return _assetImageView;
}

@end
