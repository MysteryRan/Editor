//
//  MutilpleTrackCollectionViewFlowLayout.m
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/9.
//

#import "MutilpleTrackCollectionViewFlowLayout.h"
#import "MutilpleTrackContentView.h"
//#import "VideoClipModel.h"
#import "MediaSegment.h"

@interface MutilpleTrackCollectionViewFlowLayout()

@property (nonatomic, strong) NSMutableArray<UICollectionViewLayoutAttributes *> *itemAttributes;
@property (nonatomic) CGFloat xOffset;
@property (nonatomic) CGFloat yOffset;
@property (nonatomic) NSInteger perLineCount;

@end

@implementation MutilpleTrackCollectionViewFlowLayout

- (void)prepareLayout {
    [super prepareLayout];
    
    self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    self.itemAttributes = [NSMutableArray array];
    self.xOffset = 0;
    self.yOffset = 0;
    
    NSInteger secCount = [self.collectionView numberOfSections];
    if (secCount <= 0) return;
    NSInteger itemCount = [self.collectionView numberOfItemsInSection:0];
    UIEdgeInsets sectionInsets = [self.delegate collectionView:self.collectionView layout:self insetForSectionAtIndex:0];
    
//    NSLog(@"%@",self.dataSource);
  
    self.xOffset = sectionInsets.left;
    self.yOffset = sectionInsets.top;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    CGSize size = [self.delegate collectionView:self.collectionView layout:self sizeForItemAtIndexPath:indexPath];
    NSInteger count = floor (self.collectionView.bounds.size.width - sectionInsets.left - sectionInsets.right + self.minimumInteritemSpacing) / (size.width + self.minimumInteritemSpacing);
    
    for (int i = 0; i < secCount; i++) {
        NSMutableArray *data = self.dataSource[i];
        NSInteger itemCount = [self.collectionView numberOfItemsInSection:i];
        self.yOffset += sectionInsets.top * (i + 1) + (i * 34);
        for (int j = 0; j < itemCount; j ++) {
            UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForRow:j inSection:i]];
            CGSize itemSize = [self.delegate collectionView:self.collectionView layout:self sizeForItemAtIndexPath:[NSIndexPath indexPathForRow:j inSection:i]];
            
            MediaSegment *segment = data[j];
            MediaSegment *lastSegment;
            if (j >= 1) {
                lastSegment = data[j - 1];
            }
            uint64_t timeScale = 1000000;
            CGFloat timeRule = (CGFloat)[UIScreen mainScreen].bounds.size.width / (8 * timeScale);
            self.xOffset = segment.target_timerange.start * timeRule;
            NSLog(@"---yoffset%f",self.yOffset);
            attributes.frame = CGRectMake(self.xOffset, self.yOffset, itemSize.width, itemSize.height);
            [self.itemAttributes addObject:attributes];
            self.yOffset = sectionInsets.top;
        }
    }
    
//    NSMutableArray *yOffsetArray = [NSMutableArray arrayWithCapacity:self.perLineCount];
//    for (int i = 0; i < 4;i++) {
//        CGSize itemSize = [self.delegate collectionView:self.collectionView layout:self sizeForItemAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
////        if (self.xOffset + sectionInsets.right + itemSize.width <= self.collectionView.bounds.size.width) {
//            UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
////            if (yOffsetArray.count == self.perLineCount) {
////                 self.yOffset = [[yOffsetArray objectAtIndex:(i % self.perLineCount)] floatValue] + self.minimumLineSpacing;
////            }
//            if (i == 0) {
//                self.xOffset = 10;
//            } else if (i == 1) {
////                CGSize itemSize = [self.delegate collectionView:self.collectionView layout:self sizeForItemAtIndexPath:[NSIndexPath indexPathForRow:i - 1 inSection:0]];
//                self.xOffset = 20 + self.xOffset;
//            } else if (i == 2) {
////                CGSize itemSize = [self.delegate collectionView:self.collectionView layout:self sizeForItemAtIndexPath:[NSIndexPath indexPathForRow:i - 1 inSection:0]];
//                self.xOffset = 30 + self.xOffset;
//            } else if (i == 3) {
////                CGSize itemSize = [self.delegate collectionView:self.collectionView layout:self sizeForItemAtIndexPath:[NSIndexPath indexPathForRow:i - 1 inSection:0]];
//                self.xOffset = 40 + self.xOffset;
//            }

//            attributes.frame = CGRectMake(self.xOffset, 0, itemSize.width, itemSize.height);
//            [self.itemAttributes addObject:attributes];
//            self.xOffset += itemSize.width;

//            self.xOffset = self.xOffset + itemSize.width + self.minimumInteritemSpacing;
//            if (yOffsetArray.count < self.perLineCount) {
//                [yOffsetArray addObject:@(self.yOffset + itemSize.height)];
//            } else {
//                [yOffsetArray replaceObjectAtIndex:(i % self.perLineCount) withObject:@(self.yOffset + itemSize.height)];
//            }
//        } else {
//            self.xOffset = sectionInsets.left;
//            self.yOffset = [[yOffsetArray objectAtIndex:(i % self.perLineCount)] floatValue] + self.minimumLineSpacing;
//            UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
//            attributes.frame = CGRectMake(self.xOffset, self.yOffset, itemSize.width, itemSize.height);
//            [self.itemAttributes addObject:attributes];
//            self.xOffset = self.xOffset + itemSize.width + self.minimumInteritemSpacing;
//            self.yOffset = self.yOffset + itemSize.height;
//            [yOffsetArray replaceObjectAtIndex:(i % self.perLineCount) withObject:@(self.yOffset)];
//        }
//    }
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    return self.itemAttributes;
}

- (CGSize)collectionViewContentSize {
//    MediaSegment *lastSegment;
//    for (int i = 0; i < self.dataSource.count; i ++) {
//        NSMutableArray *tracks = self.dataSource[i];
//        if (i == 0) {
//            lastSegment = tracks.lastObject;
//        }
//        MediaSegment *currentSegment = tracks.lastObject;
//        if (currentSegment.target_timerange.start + currentSegment.target_timerange.duration > (lastSegment.target_timerange.start + lastSegment.target_timerange.duration)) {
//            lastSegment = currentSegment;
//        }
//    }
//
//    uint64_t timeScale = 1000000;
//    CGFloat timeRule = (CGFloat)[UIScreen mainScreen].bounds.size.width / (8 * timeScale);
//    CGFloat content = (lastSegment.target_timerange.start + lastSegment.target_timerange.duration) * timeRule;
    return CGSizeMake(self.collectionView.frame.size.width, self.dataSource.count * 40 + 3 * (self.dataSource.count));
}

//-(CGRect)rectForIndex:(int) index {
    //Here you should calculate the sizes of all the cells
    // The ones before the selected one , the selected one, and the ones after the selected
//    if (index<selected) {
//       //Regular calculating
//        frame=CGRectMake(0, height * index, width, height);
//    } else if (index>selected) {
//      //here the tricky part is the origin you ( assuming one is seleceted) you calculate the accumulated height of index-1 regular cells and 1 selected cell
//        frame=CGRectMake(0, (height* (selected-1) + sizeOfSelectedCell) +height * (index-selected), width, height);
//    } else {
//        frame=CGRectMake(0, (height* (index-selected)) , width, selectedHeight);
//    }
//    return frame;
//}


@end
