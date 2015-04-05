//
//  YAS2AudioUnitIONode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitNode.h"

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)
@class YASAudioDevice;
#endif

@interface YASAudioUnitIONode : YASAudioUnitNode

@property (nonatomic, strong) NSArray *outputChannelMap;
@property (nonatomic, strong) NSArray *inputChannelMap;

#if TARGET_OS_IPHONE
@property (nonatomic, strong) NSArray *outputChannelAssignments;
@property (nonatomic, strong) NSArray *inputChannelAssignments;
#elif TARGET_OS_MAC
@property (nonatomic, strong) YASAudioDevice *device;
#endif

@end

@interface YASAudioUnitOutputNode : YASAudioUnitIONode

@end

@interface YASAudioUnitInputNode : YASAudioUnitIONode

@end

@interface NSArray (YASAudioUnitIONode)

- (NSData *)yas_channelMapData;
+ (NSArray *)yas_channelMapArrayWithData:(NSData *)data;

@end
