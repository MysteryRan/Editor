//
//  EditorSticker.h
//  Editor
//
//  Created by zouran on 2022/12/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EditorSticker : NSObject

@property (nonatomic, copy) NSString *filename;
@property (nonatomic, assign) BOOL trimmed;
@property (nonatomic, assign) BOOL rotated;
@property (nonatomic, assign) CGRect frame;

- (instancetype)initWithDictionaty:(NSDictionary *)dic;

@end

NS_ASSUME_NONNULL_END
