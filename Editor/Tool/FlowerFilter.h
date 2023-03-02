//
//  FlowerFilter.h
//  gpuimagedemo
//
//  Created by zouran on 2022/3/11.
//

#import <GPUImage/GPUImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlowerFilter : GPUImageTwoInputFilter {
    GLint sizeUniform;
}

@end

NS_ASSUME_NONNULL_END
