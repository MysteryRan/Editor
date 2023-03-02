//
//  MediaChooseCell.m
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/30.
//

#import "MediaChooseCell.h"
#import "UIImage+BundleImage.h"
#import <CoreText/CoreText.h>
#import "Masonry.h"


@interface MediaChooseCell()

@property (nonatomic, strong) UIImageView *normalStateImageView;

@end

@implementation MediaChooseCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self.contentView addSubview:self.imageView];
        [self.imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        
        [self.contentView addSubview:self.durationLabel];
        [self.durationLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.contentView).inset(5);
            make.bottom.equalTo(self.contentView).inset(5);
        }];
        
        [self.contentView addSubview:self.previewImageView];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(previewImageViewClick)];
        [self.previewImageView addGestureRecognizer:tap];
        
        self.normalStateImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"album_unselected"]];
        [self.contentView addSubview:self.normalStateImageView];
        [self.normalStateImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.contentView).inset(5);
            make.top.equalTo(self.contentView).offset(5);
            make.width.height.mas_equalTo(18);
        }];
        
        [self.contentView addSubview:self.selectionIndexLabel];
        [self.selectionIndexLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.normalStateImageView);
        }];

        UIView *tapView = [UIView new];
        [self.contentView addSubview:tapView];
        [tapView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.top.equalTo(self.contentView);
            make.height.mas_equalTo(self.contentView).multipliedBy(0.5);
            make.width.mas_equalTo(self.contentView).multipliedBy(0.5);
        }];
        UITapGestureRecognizer *chooseTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(chooseClick)];
        [tapView addGestureRecognizer:chooseTap];
        
        [self.previewImageView setHidden:YES];
    }
    return self;
}

- (void)chooseClick {
    if (_didChooseImage) {
        _didChooseImage(self.index);
    }
}

- (void)previewImageViewClick {
    if (_didTapPreview) {
        _didTapPreview(self.index);
    }
}

- (void)setThumbnailImage:(UIImage *)thumbnailImage {
    _thumbnailImage = thumbnailImage;
    
    self.imageView.image = thumbnailImage;
}

- (void)setImageSelected:(BOOL)imageSelected {
    _imageSelected = imageSelected;
    
    if (imageSelected) {
        self.selectionIndexLabel.hidden = NO;
    } else {
        self.selectionIndexLabel.hidden = YES;
    }
}

// MARK: - Lazy

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
    }
    return _imageView;
}

- (UIImageView *)mediaTypeImageView {
    if (!_mediaTypeImageView) {
        _mediaTypeImageView = [[UIImageView alloc] initWithImage:[UIImage mcBundleImageNamed:@"videocam_material"]];
    }
    return _mediaTypeImageView;
}

- (UILabel *)durationLabel {
    if (!_durationLabel) {
        _durationLabel = UILabel.new;
        _durationLabel.font = [UIFont systemFontOfSize:9];
        _durationLabel.textColor = [UIColor whiteColor];
        
        _durationLabel.text = @"";
    }
    return _durationLabel;
}

- (UIImageView *)previewImageView {
    if (!_previewImageView) {
        _previewImageView = [[UIImageView alloc] init];
        _previewImageView.contentMode = UIViewContentModeCenter;
        _previewImageView.userInteractionEnabled = YES;
        _previewImageView.image = [UIImage mcBundleImageNamed:@"vc_photo_preview"];
    }
    return _previewImageView;
}

- (UILabel *)selectionIndexLabel {
    if (!_selectionIndexLabel) {
        _selectionIndexLabel = [[UILabel alloc] init];
        
        CGFontRef fontRef = [self fontRef];
        NSString *fontName = (NSString *)CFBridgingRelease(CGFontCopyPostScriptName(fontRef));
        UIFont *font = [UIFont fontWithName:fontName size:10];
        
        if (!font) {
            font = [UIFont systemFontOfSize:80 weight:UIFontWeightBold];
        }
                
        _selectionIndexLabel.font = font;
        _selectionIndexLabel.textAlignment = NSTextAlignmentCenter;
        _selectionIndexLabel.textColor = UIColor.whiteColor;
        _selectionIndexLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
        [_selectionIndexLabel setHidden:YES];
    }
    return _selectionIndexLabel;
}

- (CGFontRef)fontRef {
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *fontURL = [bundle URLForResource:@"DIN_Alternate_Bold" withExtension:@"ttf"/*or TTF*/];
    NSData *inData = [NSData dataWithContentsOfURL:fontURL];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)inData);
    CGFontRef font = CGFontCreateWithDataProvider(provider);

    return font;
}


@end
