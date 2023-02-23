//
//  MediaChooseCell.h
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/30.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaChooseCell : UICollectionViewCell

@property (nonatomic, assign) NSInteger index;

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) NSString *representedAssetIdentifier;

@property (nonatomic, strong) UIImage *thumbnailImage;

@property (nonatomic, strong) UIImageView *mediaTypeImageView;

@property (nonatomic, strong) UILabel *durationLabel;

@property (nonatomic, strong) UIImageView *previewImageView;

@property (nonatomic, strong) UILabel *selectionIndexLabel;

@property (nonatomic, assign) BOOL showSelectionIndex;

@property (nonatomic, copy, nullable) void (^didTapPreview)(NSInteger);

@property (nonatomic, copy, nullable) void (^didChooseImage)(NSInteger);

@property (nonatomic, assign) BOOL imageSelected;

@end

NS_ASSUME_NONNULL_END
