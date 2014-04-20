//
//  YASSampleGraph.h
//  YASAudioSample
//
//  Created by Yuki Yasoshima on 2014/01/17.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import "YASAudioGraph.h"

@interface YASSampleEffectGraph : YASAudioGraph

+ (instancetype)sampleGraph;

- (void)setMixerVolume:(AudioUnitParameterValue)val atBusIndex:(AudioUnitElement)busIndex;
- (void)setDelayMix:(AudioUnitParameterValue)val;
- (void)setDelayTime:(AudioUnitParameterValue)val;
- (void)setDelayFeedback:(AudioUnitParameterValue)val;

- (void)addMixerConnection;
- (void)removeMixerConnection;
- (void)addDelayConnection;
- (void)removeDelayConnection;

- (void)setupNodes;
- (void)disposeNodes;

- (BOOL)isNodesAvailable;
- (BOOL)isDelayConnected;

@end
