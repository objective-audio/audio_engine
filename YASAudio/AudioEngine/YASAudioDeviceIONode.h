//
//  YASAudioDeviceIONode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import "YASAudioNode.h"

@class YASAudioDevice, YASAudioGraph;

@interface YASAudioDeviceIONode : YASAudioNode

@property (nonatomic, strong) YASAudioDevice *audioDevice;
@property (nonatomic, strong) NSSet *outputChannelRoutes;
@property (nonatomic, strong) NSSet *inputChannelRoutes;

- (instancetype)initWithAudioDevice:(YASAudioDevice *)audioDevice;

@end

@interface YASAudioDeviceIONode (YASInternal)

- (void)addAudioDeviceIOToGraph:(YASAudioGraph *)graph;
- (void)removeAudioDeviceIOFromGraph;

@end

#endif
