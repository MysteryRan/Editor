//
//  UIImage+BundleImage.m
//  MCPhotoPicker
//
//  Created by Chunyu Li on 2021/5/20.
//

#import "UIImage+BundleImage.h"

@implementation NSBundle (CurrentBundle)



@end

@implementation UIImage (BundleImage)

+ (UIImage *)mcBundleImageNamed:(NSString *)name {
    if (name == nil) return nil;
    if (@available(iOS 13.0, *)) {
        return [UIImage imageNamed:name inBundle:[NSBundle mainBundle] withConfiguration:nil];
    } else {
        return [UIImage imageNamed:name inBundle:[NSBundle mainBundle] compatibleWithTraitCollection:nil];
    }
}

@end
