//
//  EditorVideoEffect.h
//  Editor
//
//  Created by zouran on 2023/2/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EditorVideoEffect : NSObject

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *effect_id;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *relation_id;

@end

NS_ASSUME_NONNULL_END
