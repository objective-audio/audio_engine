//
//  YASAudioUnitMixerNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitNode.h"

@interface YASAudioUnitMixerNode : YASAudioUnitNode

- (instancetype)init;

- (void)setVolume:(Float32)volume forBus:(NSNumber *)bus;
- (Float32)volumeForBus:(NSNumber *)bus;
- (void)setPan:(Float32)pan forBus:(NSNumber *)bus;
- (Float32)panForBus:(NSNumber *)bus;
- (void)setEnabled:(BOOL)enabled forBus:(NSNumber *)bus;
- (BOOL)isEnabledForBus:(NSNumber *)bus;

@end
