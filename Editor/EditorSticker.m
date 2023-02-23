//
//  EditorSticker.m
//  Editor
//
//  Created by zouran on 2022/12/13.
//

#import "EditorSticker.h"

@implementation EditorSticker

- (instancetype)initWithDictionaty:(NSDictionary *)dic {
    if (self == [super init]) {
        self.filename = @"";
        NSDictionary *fr = dic[@"frame"];
        
        self.frame = CGRectMake([fr[@"x"] floatValue], [fr[@"y"] floatValue], [fr[@"w"] floatValue], [fr[@"h"] floatValue]);
    }
    return self;
}

@end
