//
//  NSString+RanAdditions.m
//  Editor
//
//  Created by zouran on 2022/8/12.
//

#import "NSString+RanAdditions.h"

@implementation NSString (RanAdditions)

+ (NSString *)media_GUIDString {
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge_transfer NSString *)string ;
}

@end
