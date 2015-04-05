//
//  YASAudioDelayNode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitDelayNode.h"
#import "YASAudioUnitParameter.h"

@implementation YASAudioUnitDelayNode

- (instancetype)init
{
    const AudioComponentDescription acd = {
        .componentType = kAudioUnitType_Effect,
        .componentSubType = kAudioUnitSubType_Delay,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
    };

    self = [super initWithAudioComponentDescription:&acd];
    if (self) {
    }
    return self;
}

- (NSString *)description
{
    return
        [NSString stringWithFormat:@"<%@: %p> delayTime=%@, feedback=%@, lowPassCutoff=%@, wetDryMix=%@", self.class,
                                   self, @(self.delayTime), @(self.feedback), @(self.lowPassCutoff), @(self.wetDryMix)];
}

- (UInt32)inputBusCount
{
    return 1;
}

- (UInt32)outputBusCount
{
    return 1;
}

- (void)setDelayTime:(Float32)delayTime
{
    [self setGlobalParameter:kDelayParam_DelayTime value:delayTime];
}

- (void)setFeedback:(Float32)feedback
{
    [self setGlobalParameter:kDelayParam_Feedback value:feedback];
}

- (void)setLowPassCutoff:(Float32)lowPassCutoff
{
    [self setGlobalParameter:kDelayParam_LopassCutoff value:lowPassCutoff];
}

- (void)setWetDryMix:(Float32)wetDryMix
{
    [self setGlobalParameter:kDelayParam_WetDryMix value:wetDryMix];
}

@end
