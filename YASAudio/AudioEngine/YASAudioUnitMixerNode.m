//
//  YASAudioUnitMixerNode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitMixerNode.h"
#import "YASAudioUnit.h"
#import "YASAudioNode+Internal.h"
#import "NSNumber+YASAudio.h"
#import "YASMacros.h"

@implementation YASAudioUnitMixerNode

- (instancetype)init
{
    const AudioComponentDescription acd = {
        .componentType = kAudioUnitType_Mixer,
        .componentSubType = kAudioUnitSubType_MultiChannelMixer,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
    };

    self = [super initWithAudioComponentDescription:&acd];
    if (self) {
    }
    return self;
}

- (void)updateConnections
{
    @synchronized(self)
    {
        @autoreleasepool
        {
            YASAudioUnit *audioUnit = self.audioUnit;
            NSNumber *maxDestinationBus = [self.inputConnections.allValues valueForKeyPath:@"@max.destinationBus"];
            if (maxDestinationBus) {
                [audioUnit setElementCount:maxDestinationBus.uint32Value + 1 scope:kAudioUnitScope_Input];
            }
        }

        [super updateConnections];
    }
}

- (UInt32)inputBusCount
{
    return UINT32_MAX;
}

- (UInt32)outputBusCount
{
    return 1;
}

- (void)setOutputVolume:(Float32)volume forBus:(NSNumber *)bus
{
    [self setOutputParameter:kMultiChannelMixerParam_Volume value:volume element:bus.uint32Value];
}

- (Float32)outputVolumeForBus:(NSNumber *)bus
{
    return [self outputParameterValue:kMultiChannelMixerParam_Volume element:bus.uint32Value];
}

- (void)setOutputPan:(Float32)pan forBus:(NSNumber *)bus
{
    [self setOutputParameter:kMultiChannelMixerParam_Pan value:pan element:bus.uint32Value];
}

- (Float32)outputPanForBus:(NSNumber *)bus
{
    return [self outputParameterValue:kMultiChannelMixerParam_Pan element:bus.uint32Value];
}

- (void)setInputVolume:(Float32)volume forBus:(NSNumber *)bus
{
    [self setInputParameter:kMultiChannelMixerParam_Volume value:volume element:bus.uint32Value];
}

- (Float32)inputVolumeForBus:(NSNumber *)bus
{
    return [self inputParameterValue:kMultiChannelMixerParam_Volume element:bus.uint32Value];
}

- (void)setInputPan:(Float32)pan forBus:(NSNumber *)bus
{
    [self setInputParameter:kMultiChannelMixerParam_Pan value:pan element:bus.uint32Value];
}

- (Float32)inputPanForBus:(NSNumber *)bus
{
    return [self inputParameterValue:kMultiChannelMixerParam_Pan element:bus.uint32Value];
}

- (void)setInputEnabled:(BOOL)enabled forBus:(NSNumber *)bus
{
    [self setInputParameter:kMultiChannelMixerParam_Enable value:enabled ? 1.0f : 0.0f element:bus.uint32Value];
}

- (BOOL)isInputEnabledForBus:(NSNumber *)bus
{
    return [self inputParameterValue:kMultiChannelMixerParam_Enable element:bus.uint32Value] != 0.0;
}

@end
