//
//  MediaBottomActionView.h
//  RanMediaTimeline
//
//  Created by zouran on 2021/12/24.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MediaBottomType) {
    kBottomHomeType = 0,
    kBottomVideoClip = 1,
    kBottomStickerType = 2,
};

typedef NS_ENUM(NSInteger, MediaBottomHomeAction) {
    kHomeTypeVideo = 1000,
    kHomeTypeAudio = 1001,
    kHomeTypeText = 1002,
    kHomeTypeSticker = 1003,
    kHomeTypePip = 1004,
    kHomeTypeEffect = 1005,
    kHomeTypeResource = 1006,
    kHomeTypeFilter = 1007,
    kHomeTypeScale = 1008,
    kHomeTypeBackground = 1009,
    kHomeTypeAdjust = 1010,
};

typedef NS_ENUM(NSInteger, MediaBottomVideoClipAction) {
    kVideoTypeCarve = 2000,
    kVideoTypeSpeed = 2001,
    kVideoTypeVolume = 2002,
    kVideoTypeDelete = 2003,
};

@protocol MediaBottomActionViewDelegate <NSObject>

@optional

- (void)mediaBottomActionViewClick:(MediaBottomHomeAction)type;

@end

@interface MediaBottomActionView : UIView

@property (nonatomic, weak) id <MediaBottomActionViewDelegate> delegate;
- (void)reloadDataByType:(MediaBottomType)type;
- (void)bottomReloadData;

@end

NS_ASSUME_NONNULL_END
