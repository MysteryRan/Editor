//
//  MediaChooseListView.m
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/30.
//

#import "MediaChooseListView.h"
#import "MediaChooseListCell.h"
#import "Masonry.h"
#import <Photos/Photos.h>

@interface MediaChooseListView()<UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *dataSource;
@property (nonatomic, strong) PHCachingImageManager *cachingImageManager;

@end

static NSString *CollectionCellIdentifier = @"cell";

@implementation MediaChooseListView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setUpSubviews];
    }
    return self;
}

- (void)setUpSubviews {
    
    UIEdgeInsets bottomEdge;
    bottomEdge = UIEdgeInsetsZero;
    
    if (@available(iOS 11.0, *)) {
        bottomEdge =  [[[UIApplication sharedApplication] windows] objectAtIndex:0].safeAreaInsets;
    }
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    [self.collectionView registerClass:[MediaChooseListCell class] forCellWithReuseIdentifier:CollectionCellIdentifier];
    self.collectionView.backgroundColor = [UIColor blackColor];
    self.collectionView.showsVerticalScrollIndicator = FALSE;
    self.collectionView.showsHorizontalScrollIndicator = FALSE;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self addSubview:self.collectionView];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self);
        make.left.right.equalTo(self);
        make.bottom.equalTo(self);
    }];
}

- (void)showWithSelectedImages:(NSMutableArray *)images {
    self.dataSource = images;
    [UIView performWithoutAnimation:^{
        [self.collectionView reloadData];
    }];
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:images.count - 1 inSection:0] atScrollPosition:(UICollectionViewScrollPositionLeft) animated:YES];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = (self.frame.size.width - 4 * 10) / 4.0;
    CGFloat height = width;
    return CGSizeMake(width, height);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0, 10, 0, 10);
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return  self.dataSource.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = [self.dataSource objectAtIndex:indexPath.item];
    MediaChooseListCell *listCell = [collectionView dequeueReusableCellWithReuseIdentifier:CollectionCellIdentifier forIndexPath:indexPath];
    listCell.representedAssetIdentifier = asset.localIdentifier;
    listCell.index = indexPath.item;
    [self.cachingImageManager requestImageForAsset:asset
                                        targetSize:CGSizeMake(asset.pixelWidth / 2, asset.pixelHeight / 2)
                                       contentMode:PHImageContentModeAspectFill
                                           options:nil
                                     resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        if ([listCell.representedAssetIdentifier isEqualToString:asset.localIdentifier] && result != nil) {
            listCell.assetImageView.image = result;
        }
    }];
    
    __weak typeof(self)weakSelf = self;
    listCell.didDeleteImage = ^(NSInteger index) {
        [weakSelf.dataSource removeObjectAtIndex:index];
        [weakSelf.collectionView reloadData];
        if (weakSelf.didRefreshDataSource) {
            weakSelf.didRefreshDataSource(0);
        }
    };
    
    return listCell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

}


// MARK: - Lazy

- (PHCachingImageManager *)cachingImageManager {
    if (!_cachingImageManager) {
        _cachingImageManager = [[PHCachingImageManager alloc] init];
    }
    return _cachingImageManager;
}

@end
