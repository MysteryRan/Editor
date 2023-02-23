//
//  MutilpleTrackCollectionViewFlowLayout.h
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/9.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MutilpleTrackCollectionViewFlowLayoutDelegate <UICollectionViewDelegateFlowLayout>

- (void)recieveData:(NSArray *)dataSouce;

@end

@interface MutilpleTrackCollectionViewFlowLayout : UICollectionViewFlowLayout

@property (nonatomic, strong) NSMutableArray *dataSource;

@property (nonatomic, weak) id<MutilpleTrackCollectionViewFlowLayoutDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
