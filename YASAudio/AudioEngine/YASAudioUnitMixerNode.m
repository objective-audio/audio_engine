//
//  YASAudioUnitMixerNode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitMixerNode.h"
#import "YASAudioUnit.h"
#import "YASAudioNode+Internal.h"
#import "NSNumber+YASAudio.h"
#import "YASMacros.h"

@interface YASAudioUnitMixerNodeInputInfo : NSObject

@property (nonatomic, assign) Float32 volume;
@property (nonatomic, assign) Float32 pan;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

@end

@implementation YASAudioUnitMixerNodeInputInfo

- (instancetype)init
{
    self = [super init];
    if (self) {
        _volume = 1.0f;
        _pan = 0.0f;
        _enabled = YES;
    }
    return self;
}

@end

#pragma mark -

@interface YASAudioUnitMixerNode ()

@property (nonatomic, strong) NSMutableDictionary *inputInfos;

@end

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

- (void)dealloc
{
    YASRelease(_inputInfos);

    _inputInfos = nil;

    YASSuperDealloc;
}

- (void)prepareParameters
{
    [super prepareParameters];

    UInt32 elementCount = [self.audioUnit elementCountForScope:kAudioUnitScope_Input];
    for (UInt32 element = 0; element < elementCount; element++) {
        NSNumber *bus = @(element);
        YASAudioUnitMixerNodeInputInfo *info = [self _inputInfoForBus:bus];
        [self.audioUnit setParameter:kMultiChannelMixerParam_Volume
                               value:info.volume
                               scope:kAudioUnitScope_Input
                             element:element];
        [self.audioUnit setParameter:kMultiChannelMixerParam_Pan
                               value:info.pan
                               scope:kAudioUnitScope_Input
                             element:element];
        [self.audioUnit setParameter:kMultiChannelMixerParam_Enable
                               value:info.enabled ? 1.0f : 0.0f
                               scope:kAudioUnitScope_Input
                             element:element];
    }
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
    YASAudioUnitMixerNodeInputInfo *info = [self _inputInfoForBus:bus];
    info.volume = volume;
    [self.audioUnit setParameter:kMultiChannelMixerParam_Volume
                           value:volume
                           scope:kAudioUnitScope_Input
                         element:bus.uint32Value];
}

- (Float32)volumeForBus:(NSNumber *)bus
{
    YASAudioUnitMixerNodeInputInfo *info = [self _inputInfoForBus:bus];
    return info.volume;
}

- (void)setPan:(Float32)pan forBus:(NSNumber *)bus
{
    YASAudioUnitMixerNodeInputInfo *info = [self _inputInfoForBus:bus];
    info.pan = pan;
    [self.audioUnit setParameter:kMultiChannelMixerParam_Pan
                           value:pan
                           scope:kAudioUnitScope_Input
                         element:bus.uint32Value];
}

- (Float32)panForBus:(NSNumber *)bus
{
    YASAudioUnitMixerNodeInputInfo *info = [self _inputInfoForBus:bus];
    return info.pan;
}

- (void)setEnabled:(BOOL)enabled forBus:(NSNumber *)bus
{
    YASAudioUnitMixerNodeInputInfo *info = [self _inputInfoForBus:bus];
    info.enabled = enabled;
    [self.audioUnit setParameter:kMultiChannelMixerParam_Enable
                           value:enabled ? 1.0f : 0.0f
                           scope:kAudioUnitScope_Input
                         element:bus.uint32Value];
}

- (BOOL)isEnabledForBus:(NSNumber *)bus
{
    YASAudioUnitMixerNodeInputInfo *info = [self _inputInfoForBus:bus];
    return info.enabled;
}

- (YASAudioUnitMixerNodeInputInfo *)_inputInfoForBus:(NSNumber *)bus
{
    if (!bus) {
        return nil;
    }
    if (!_inputInfos) {
        _inputInfos = [[NSMutableDictionary alloc] initWithCapacity:8];
    }
    YASAudioUnitMixerNodeInputInfo *info = _inputInfos[bus];
    if (!info) {
        info = [[YASAudioUnitMixerNodeInputInfo alloc] init];
        _inputInfos[bus] = info;
        YASRelease(info);
    }
    return info;
}

@end
