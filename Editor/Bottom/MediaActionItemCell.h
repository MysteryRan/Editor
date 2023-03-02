//
//  MediaActionItemCell.h
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/24.
//

#import <UIKit/UIKit.h>
#import "MediaBottomActionItemModel.h"
//#import "RanAdjustModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MediaActionItemCell : UICollectionViewCell

@property (nonatomic, strong) MediaBottomActionItemModel *itemModel;

//@property (nonatomic, strong) RanAdjustModel *adjustModel;
 
@end

NS_ASSUME_NONNULL_END
