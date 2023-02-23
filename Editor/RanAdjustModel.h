//
//  RanAdjustModel.h
//  RanMediaTimeline
//
//  Created by zouran on 2022/1/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, AdjustType) {
    KAdjustLight = 0,//亮度
    KAdjustRatio = 1,//对比度
    kAdjustSaturate = 2, // 饱和度
    kAdjustWarm = 3, // 色温
    kAdjustTone = 4,// 色调
};

@interface RanAdjustModel : NSObject

@property (nonatomic, copy) NSString *adjustName;
@property (nonatomic, assign) float adjustValue;
@property (nonatomic, assign) float defaultValue;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, strong) NSArray *limits;

@end

NS_ASSUME_NONNULL_END
