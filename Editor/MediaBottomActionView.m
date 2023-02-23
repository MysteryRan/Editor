//
//  MediaBottomActionView.m
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/24.
//

#import "MediaBottomActionView.h"
//#import "MediaBottomActionItemModel.h"
#import "MediaActionItemCell.h"
#import "Masonry.h"
//#import "VideoClipManager.h"
//#import "MediaTimeline.h"
//#import "VideoTrackModel.h"

@interface MediaBottomActionView()<UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray <MediaBottomActionItemModel *>*dataSource;

@end

static NSString *CollectionCellIdentifier = @"CollectionCellIdentifier";

@implementation MediaBottomActionView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.dataSource = [NSMutableArray arrayWithCapacity:0];
        self.backgroundColor = [UIColor blackColor];
        [self initSubviews];
    }
    return self;
}

- (void)initSubviews {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    [self.collectionView registerClass:[MediaActionItemCell class] forCellWithReuseIdentifier:CollectionCellIdentifier];
    self.collectionView.showsVerticalScrollIndicator = FALSE;
    self.collectionView.showsHorizontalScrollIndicator = FALSE;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self addSubview:self.collectionView];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self).inset(20);
        make.left.right.top.equalTo(self);
    }];
}

- (void)reloadDataByType:(MediaBottomType)type {
    NSArray *names = [self typeGetTitle:type];
    NSArray *actions = [self typeGetAction:type];
    for (int i = 0; i < names.count; i ++) {
        MediaBottomActionItemModel *itemModel = [MediaBottomActionItemModel new];
        itemModel.name = names[i];
        itemModel.actionType = [actions[i] intValue];
        [self.dataSource addObject:itemModel];
    }
    [self.collectionView reloadData];
}

- (NSArray *)typeGetTitle:(MediaBottomType)type {
    /*
     kBottomHomeType = 0,
     kBottomVideoClip = 1,
     kBottomStickerType = 2,
     */
    if (type == kBottomHomeType) {
        return @[@"剪辑",@"音频",@"文本",@"贴纸",@"画中画",@"特效",@"素材",@"滤镜",@"比例",@"背景",@"调节"];
    } else if (type == kHomeTypeVideo) {
        return @[@"分割",@"变速",@"音量",@"删除"];
    } else {
        return @[];
    }

}

- (NSArray *)typeGetAction:(MediaBottomType)type {
    if (type == kBottomHomeType) {
        return @[@(kHomeTypeVideo),@(kHomeTypeAudio),@(kHomeTypeText),@(kHomeTypeSticker),@(kHomeTypePip),@(kHomeTypeEffect),@(kHomeTypeResource),@(kHomeTypeFilter),@(kHomeTypeScale),@(kHomeTypeBackground),@(kHomeTypeAdjust)];
    } else if (type == kHomeTypeVideo) {
        return @[@(kVideoTypeCarve),@(kVideoTypeSpeed),@(kVideoTypeVolume),@(kVideoTypeDelete)];
    } else {
        return @[];
    }

}

- (void)bottomReloadData {
    [self.collectionView reloadData];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake([UIScreen mainScreen].bounds.size.width / 6.5, 70);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsZero;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MediaActionItemCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CollectionCellIdentifier forIndexPath:indexPath];
    cell.itemModel = self.dataSource[indexPath.item];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger type = self.dataSource[indexPath.item].actionType;
    if (self.delegate && [self.delegate respondsToSelector:@selector(mediaBottomActionViewClick:)]) {
        [self.delegate mediaBottomActionViewClick:type];
    }

    if (type == kHomeTypeVideo) {

    } else if (type == kVideoTypeCarve) {
//        VideoClipManager *dd = [VideoClipManager new];
//        VideoTrackModel *mainTrack = [[MediaTimeline sharedInstance] getVideoTrackByTrackID:1];
//        [dd carveClip:mainTrack.clips[0] withCarveTime:2000000];
    }
}

-(UIViewController *)findBestViewController:(UIViewController *)vc {
    if (vc.presentedViewController) {
        return [self findBestViewController:vc.presentedViewController];
    } else if ([vc isKindOfClass:[UISplitViewController class]]) {
        UISplitViewController* svc = (UISplitViewController*) vc;
        if (svc.viewControllers.count > 0)
            return [self findBestViewController:svc.viewControllers.lastObject];
        else
            return vc;
    } else if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController* nvc = (UINavigationController*) vc;
        if (nvc.viewControllers.count > 0)
            return [self findBestViewController:nvc.topViewController];
        else
            return vc;
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        UITabBarController* svc = (UITabBarController*) vc;
        if (svc.viewControllers.count > 0)
            return [self findBestViewController:svc.selectedViewController];
        else
            return vc;
    } else {
        return vc;
    }
}
-(UIViewController*) currentViewController {
    UIViewController* viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    return [self findBestViewController:viewController];
}

@end
