//
//  MediaChooseListView.h
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/30.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaChooseListView : UIView

@property (nonatomic, copy, nullable) void (^didRefreshDataSource)(NSInteger);

- (void)showWithSelectedImages:(NSMutableArray *)images;

@end

NS_ASSUME_NONNULL_END
