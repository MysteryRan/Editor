//
//  UICollectionView+Extensions.h
//  MCPhotoPicker
//
//  Created by Chunyu Li on 2021/5/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UICollectionView (Extensions)

- (NSArray<NSIndexPath *> *)indexPathsForElementsInRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END
