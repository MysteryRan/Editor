//
//  UICollectionView+Extensions.m
//  MCPhotoPicker
//
//  Created by Chunyu Li on 2021/5/18.
//

#import "UICollectionView+Extensions.h"

@implementation UICollectionView (Extensions)

- (NSArray<NSIndexPath *> *)indexPathsForElementsInRect:(CGRect)rect {
    
    NSArray<UICollectionViewLayoutAttributes *> *attributes = [self.collectionViewLayout layoutAttributesForElementsInRect:rect];
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (UICollectionViewLayoutAttributes *attribute in attributes) {
        [indexPaths addObject:attribute.indexPath];
    }
    return [indexPaths copy];
}

@end
