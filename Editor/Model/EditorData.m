//
//  EditorData.m
//  ffmpegDemo
//
//  Created by zouran on 2022/11/29.
//

#import "EditorData.h"
#import "NSObject+YYModel.h"

static EditorData *sharedInstance = nil;
static dispatch_once_t onceToken;

@implementation EditorData

+ (EditorData *)sharedInstance {
    if (nil != sharedInstance) {
        return sharedInstance;
    }
    dispatch_once(&onceToken, ^{
        sharedInstance = [[EditorData alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.tracks = [NSMutableArray arrayWithCapacity:0];
        self.materials = [[EditorMaterial alloc] init];
    }
    return self;
}

+ (NSDictionary *)modelContainerPropertyGenericClass {
    return @{@"tracks": [MediaTrack class],
    };
}

@end
