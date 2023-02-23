//
//  UIImage+Bundle.h
//  MCPhotoPicker
//
//  Created by Chunyu Li on 2021/5/20.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSBundle (CurrentBundle)

+ (NSBundle *)mcCurrentBundle;

@end

@interface UIImage (BundleImage)

+ (nullable UIImage *)mcBundleImageNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
