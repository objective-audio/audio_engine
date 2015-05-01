//
//  YASAudioUnitMixerNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitNode.h"

@interface YASAudioUnitMixerNode : YASAudioUnitNode

- (instancetype)init;

- (void)setOutputVolume:(Float32)volume forBus:(NSNumber *)bus;
- (Float32)outputVolumeForBus:(NSNumber *)bus;
- (void)setOutputPan:(Float32)pan forBus:(NSNumber *)bus;
- (Float32)outputPanForBus:(NSNumber *)bus;

- (void)setInputVolume:(Float32)volume forBus:(NSNumber *)bus;
- (Float32)inputVolumeForBus:(NSNumber *)bus;
- (void)setInputPan:(Float32)pan forBus:(NSNumber *)bus;
- (Float32)inputPanForBus:(NSNumber *)bus;
- (void)setInputEnabled:(BOOL)enabled forBus:(NSNumber *)bus;
- (BOOL)isInputEnabledForBus:(NSNumber *)bus;

@end
