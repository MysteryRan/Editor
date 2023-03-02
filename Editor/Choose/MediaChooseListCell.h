//
//  MediaChooseListCell.h
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/7.
//

#import <UIKit/UIKit.h>
#import "MediaChooseCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface MediaChooseListCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *assetImageView;

@property (nonatomic, assign) NSInteger index;

@property (nonatomic, strong) NSString *representedAssetIdentifier;

@property (nonatomic, strong) UIImage *thumbnailImage;

@property (nonatomic, strong) UIImageView *mediaTypeImageView;

@property (nonatomic, strong) UILabel *durationLabel;

@property (nonatomic, strong) UIImageView *previewImageView;

@property (nonatomic, strong) UILabel *selectionIndexLabel;

@property (nonatomic, copy, nullable) void (^didDeleteImage)(NSInteger);

@end

NS_ASSUME_NONNULL_END
