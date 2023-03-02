//
//  MediaFloat.h
//  Editor
//
//  Created by zouran on 2023/3/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaFloat : NSObject

@property(nonatomic, assign)float x;
@property(nonatomic, assign)float y;

- (instancetype)initWithXValue:(float)x andYValue:(float)y;

@end

NS_ASSUME_NONNULL_END
