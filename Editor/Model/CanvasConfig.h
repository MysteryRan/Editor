//
//  CanvasConfig.h
//  Editor
//
//  Created by zouran on 2022/12/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *CanvasRatioStr NS_STRING_ENUM;

FOUNDATION_EXPORT CanvasRatioStr const CanvasRatioOriginal;
FOUNDATION_EXPORT CanvasRatioStr const CanvasRatio1v1;

/*
VCNvEditMode16v9 = 0,
VCNvEditMode1v1,
VCNvEditMode9v16,
VCNvEditMode3v4,
VCNvEditMode4v3,
VCNvEditMode6v7,;
 */

@interface CanvasConfig : NSObject

@property(nonatomic, assign)uint64_t height;
@property(nonatomic, copy)CanvasRatioStr ratio;
@property(nonatomic, assign)uint64_t width;

@end

NS_ASSUME_NONNULL_END
