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

- (void)setVolume:(Float32)volume forBus:(NSNumber *)bus
{
    [self setInputParameter:kMultiChannelMixerParam_Volume value:volume element:bus.uint32Value];
}

- (Float32)volumeForBus:(NSNumber *)bus
{
    return [self inputParameterValue:kMultiChannelMixerParam_Volume element:bus.uint32Value];
}

- (void)setPan:(Float32)pan forBus:(NSNumber *)bus
{
    [self setInputParameter:kMultiChannelMixerParam_Pan value:pan element:bus.uint32Value];
}

- (Float32)panForBus:(NSNumber *)bus
{
    return [self inputParameterValue:kMultiChannelMixerParam_Pan element:bus.uint32Value];
}

- (void)setEnabled:(BOOL)enabled forBus:(NSNumber *)bus
{
    [self setInputParameter:kMultiChannelMixerParam_Enable value:enabled ? 1.0f : 0.0f element:bus.uint32Value];
}

- (BOOL)isEnabledForBus:(NSNumber *)bus
{
    return [self inputParameterValue:kMultiChannelMixerParam_Enable element:bus.uint32Value] != 0.0;
}

@end
