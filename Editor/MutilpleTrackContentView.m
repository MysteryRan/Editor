//
//  MutilpleTrackContentView.m
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/9.
//

#import "MutilpleTrackContentView.h"
#import "RanMultipleTrackCollectionView.h"
#import "MutilpleTrackCollectionViewFlowLayout.h"
#import "MediaTrackCell.h"
#import "EditorData.h"
#import "Masonry.h"

@interface MutilpleTrackContentView()<UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout,UIGestureRecognizerDelegate,MutilpleTrackCollectionViewFlowLayoutDelegate>

@property (nonatomic, strong)RanMultipleTrackCollectionView *collectionView;

@property (nonatomic, strong)MediaTrackCell *pointCell;
//@property (nonatomic, strong)MediaTrackClipView *clipView;
@property (nonatomic, strong)MediaTrackCell *selectedCell;
//@property (nonatomic, strong)VideoClipModel *selectedClipModel;
@property (nonatomic, assign)NSIndexPath *selectedIndexPath;

@end

static NSString *CollectionCellIdentifier = @"cell";

@implementation MutilpleTrackContentView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.dataSource = [NSMutableArray arrayWithCapacity:0];
        
//        [self initLongPressGesture];
    }
    return self;
}

//- (void)layoutSubviews {
//    [super layoutSubviews];
    
//    [self initData];
//}

- (void)reloadTracksData {
    [self initSubviews:CGRectZero];
    [self initData];
}

- (void)initData {
    EditorData *data = [EditorData sharedInstance];
    
    for (int i = 0; i < data.tracks.count; i ++) {
        MediaTrack *track = data.tracks[i];
        if (track.type == MediaTrackTypeEffect) {
            [self.dataSource addObject:track.segments];
        }
    }
    
    [self.collectionView reloadData];
    
    
    
//    NSMutableArray *firstTrack =  [NSMutableArray arrayWithCapacity:0];
//    VideoClipModel *baseModel = [VideoClipModel new];
//    baseModel.inpoint = 0;
//    baseModel.duration = 50;
//    baseModel.outpoint = baseModel.inpoint + baseModel.duration;
//    [firstTrack addObject:baseModel];
//
//    VideoClipModel *baseModel1 = [VideoClipModel new];
//    baseModel1.inpoint = 60;
//    baseModel1.duration = 100;
//    baseModel1.outpoint = baseModel1.inpoint + baseModel1.duration;
//    [firstTrack addObject:baseModel1];
//
//    VideoClipModel *baseModel2 = [VideoClipModel new];
//    baseModel2.inpoint = 320;
//    baseModel2.duration = 150;
//    baseModel2.outpoint = baseModel2.inpoint + baseModel2.duration;
//    [firstTrack addObject:baseModel2];
//
//    [self.dataSource addObject:firstTrack];
//
//    VideoClipModel *baseModel3 = [VideoClipModel new];
//    baseModel3.inpoint = 330;
//    baseModel3.duration = 200;
//    baseModel3.outpoint = baseModel3.inpoint + baseModel3.duration;
//    [self.dataSource addObject:baseModel3];
}

- (void)initLongPressGesture {
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    longPress.delegate = self;
    longPress.delaysTouchesBegan = true;
    [self.collectionView addGestureRecognizer:longPress];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    MediaTrackCell *currentCell;
    if (gesture.state == UIGestureRecognizerStateBegan) {
//        [self.clipView removeFromSuperview];
        CGPoint point = [gesture locationInView:self.collectionView];
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
        currentCell = (MediaTrackCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        currentCell.hidden = YES;
        
        self.pointCell = [[MediaTrackCell alloc] initWithFrame:CGRectMake(0, 0, currentCell.frame.size.width, currentCell.frame.size.height)];
//        self.pointCell.baseModel = self.dataSource[indexPath.section][indexPath.item];
        [self.collectionView addSubview:self.pointCell];
        self.pointCell.center = currentCell.center;
        self.pointCell.alpha = 0.5;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint point = [gesture locationInView:self.collectionView];
        self.pointCell.center = point;
//        //是否重叠
//        NSArray<UICollectionViewCell *> *cells = [self.collectionView visibleCells];
//        for (int i = 0; i < cells.count; i ++) {
//            UICollectionViewCell *cell = cells[i];
//            if (cell.hidden == NO) {
//                if (CGRectIntersectsRect(self.pointCell.frame, cell.frame)) {
//                    self.pointCell.backgroundColor = [UIColor blueColor];
//                    break;
//                } else {
//                    self.pointCell.backgroundColor = [UIColor greenColor];
//                }
//            } else {
//                self.pointCell.backgroundColor = [UIColor greenColor];
//            }
//        }
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        [self.pointCell removeFromSuperview];
        self.pointCell = nil;
        [self.collectionView reloadData];
        self.pointCell.alpha = 1;
    }
}

- (void)initSubviews:(CGRect)frame {
    [self contentSet:frame];
}

- (void)contentSet:(CGRect)frame {
    MutilpleTrackCollectionViewFlowLayout *layout = [[MutilpleTrackCollectionViewFlowLayout alloc] init];
    layout.delegate = self;
    layout.dataSource = self.dataSource;
//    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
//    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    self.collectionView = [[RanMultipleTrackCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    [self.collectionView registerClass:[MediaTrackCell class] forCellWithReuseIdentifier:CollectionCellIdentifier];
//    self.collectionView.backgroundColor = [UIColor yellowColor];
    self.collectionView.showsVerticalScrollIndicator = FALSE;
    self.collectionView.showsHorizontalScrollIndicator = FALSE;
//    self.collectionView.bounces = FALSE;
    [self.collectionView setDirectionalLockEnabled:TRUE];
    [self.collectionView  setContentInset:UIEdgeInsetsZero];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self addSubview:self.collectionView];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.dataSource.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.dataSource[section].count;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
//    offset = inpoint - lastoutpoint
    if (section == 0) {
        return 3;
    }
    return 3;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height = 34;
    
    uint64_t timeScale = 1000000;
    CGFloat timeRule = (CGFloat)[UIScreen mainScreen].bounds.size.width / (8 * timeScale);
    
    MediaSegment *segment = self.dataSource[indexPath.section][indexPath.item];
    CGFloat width = segment.target_timerange.duration * timeRule;
    return CGSizeMake(width, height);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MediaTrackCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CollectionCellIdentifier forIndexPath:indexPath];
//    cell.baseModel = self.dataSource[indexPath.section][indexPath.item];
    cell.hidden = NO;
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
//    MediaTrackCell *cell = (MediaTrackCell *)[collectionView cellForItemAtIndexPath:indexPath];
//    [self.clipView removeFromSuperview];
//    self.clipView = [[MediaTrackClipView alloc] initWithFrame:CGRectMake(cell.frame.origin.x - 21, cell.frame.origin.y - 1.5, cell.frame.size.width + 21 * 2, cell.frame.size.height + 1.5 * 2)];
//    self.clipView.delegate = self;
//    NSMutableArray *clips = self.dataSource[indexPath.section];
//    VideoClipModel *nextClipModel;
//    VideoClipModel *lastClipModel;
//    if (indexPath.row + 1 < clips.count) {
//        nextClipModel = clips[indexPath.row + 1];
//    }
//    if (indexPath.row - 1 >= 0) {
//        lastClipModel = clips[indexPath.row - 1];
//    }
//    if (nextClipModel) {
//        self.clipView.rightLimit = nextClipModel.inpoint + 21;
//    } else {
//        self.clipView.rightLimit = MAXFLOAT;
//    }
//    self.clipView.leftLimit = lastClipModel.outpoint - 21;
//    [collectionView addSubview:self.clipView];
//    self.selectedCell = cell;
//    self.selectedIndexPath = indexPath;
//    self.selectedClipModel = self.dataSource[indexPath.section][indexPath.item];
}

- (void)rightScroll:(CGRect)frame {
    if (self.delegate && [self.delegate respondsToSelector:@selector(mutilpleTrackContentViewrightScroll:)]) {
        [self.delegate mutilpleTrackContentViewrightScroll:frame];
    }
}

- (void)leftControlView:(UIPanGestureRecognizer *)ges withRect:(CGRect)rect {
    CGRect newRect = CGRectMake(rect.origin.x, rect.origin.y + 1.5, rect.size.width - 2 * 21, self.selectedCell.frame.size.height);
    [self.selectedCell panAdjustFrame:newRect];
}

- (void)rightControlView:(UIPanGestureRecognizer *)ges withRect:(CGRect)rect {
    CGRect newRect = CGRectMake(self.selectedCell.frame.origin.x, rect.origin.y + 1.5, rect.size.width - 2 * 21, self.selectedCell.frame.size.height);
    [self.selectedCell panAdjustFrame:newRect];
    
    
    if (ges.state == UIGestureRecognizerStateEnded) {
//        self.selectedClipModel.duration =  newRect.size.width;
//        self.selectedClipModel.outpoint = self.selectedClipModel.inpoint + self.selectedClipModel.duration;
        [UIView performWithoutAnimation:^{
            [self.collectionView reloadItemsAtIndexPaths:@[self.selectedIndexPath]];
        }];
        
        self.selectedCell = (MediaTrackCell *)[self.collectionView cellForItemAtIndexPath:self.selectedIndexPath];
    }
}

- (void)recieveData:(NSArray *)dataSouce {
    
}


@end
