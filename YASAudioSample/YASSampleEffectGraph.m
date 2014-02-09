//
//  YASSampleGraph.m
//  YASAudioSample
//
//  Created by Yuki Yasoshima on 2014/01/17.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import "YASSampleEffectGraph.h"
#import "YASAudio.h"
#import <AVFoundation/AVFoundation.h>

static double const SAMPLE_SAMPLERATE = 44100.0;

@interface YASSampleEffectGraph()
@property (nonatomic, strong) YASAudioNode *mixerNode;
@property (nonatomic, strong) YASAudioNode *delayNode;
@property (nonatomic, strong) YASAudioConnection *mixerToIOConnection;
@property (nonatomic, strong) YASAudioConnection *delayToMixerConnection;
@end

@implementation YASSampleEffectGraph

+ (id)sampleGraph
{
    id sampleGraph = [[self class] graph];
    return sampleGraph;
}

- (void)_setupAudioSession
{
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error]) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
    }
}

- (void)_setupNodes
{
    if (!self.mixerNode) {
        
        AudioStreamBasicDescription format;
        
        YASGetFloat32NonInterleavedStereoFormat(&format, SAMPLE_SAMPLERATE);
        
        self.mixerNode = [self addNodeWithType:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer];
        self.delayNode = [self addNodeWithType:kAudioUnitType_Effect subType:kAudioUnitSubType_Delay];
        
        [self.ioNode setInputFormat:&format busNumber:0];
        
        [_mixerNode setInputFormat:&format busNumber:0];
        [_mixerNode setInputFormat:&format busNumber:1];
        [_mixerNode setOutputFormat:&format busNumber:0];
        
        [_delayNode setInputFormat:&format busNumber:0];
        [_delayNode setOutputFormat:&format busNumber:0];
        
        self.mixerToIOConnection = [self addConnectionWithSourceNode:_mixerNode sourceOutputNumber:0 destNode:self.ioNode destInputNumber:0];
        self.delayToMixerConnection = [self addConnectionWithSourceNode:_delayNode sourceOutputNumber:0 destNode:_mixerNode destInputNumber:1];
        
        [_mixerNode setRenderCallback:0];
        [_delayNode setRenderCallback:0];
        
        __block NSUInteger noiseIndex = 0;
        
        _mixerNode.renderCallbackBlock = ^(YASAudioNodeRenderInfo *renderInfo) {
            if (renderInfo.inBusNumber == 0) {
                YASFillFloat32SinewaveToAudioBufferList(renderInfo.ioData, 30);
            }
        };
        
        _delayNode.renderCallbackBlock = ^(YASAudioNodeRenderInfo *renderInfo) {
            
            if (renderInfo.inBusNumber == 0) {
                if (noiseIndex == 0) {
                    
                    const Float32 gain = YASLinearValueFromDBValue(-10);
                    
                    for (NSInteger i = 0; i < renderInfo.ioData->mNumberBuffers; i++) {
                        Float32 *ptr = renderInfo.ioData->mBuffers[i].mData;
                        const UInt32 channels = renderInfo.ioData->mBuffers[i].mNumberChannels;
                        for (NSInteger j = 0; j < renderInfo.inNumberFrames; j++) {
                            for (NSInteger k = 0; k < channels; k++) {
                                ptr[j * channels + k] = (Float32)random() / LONG_MAX * gain;
                            }
                        }
                    }
                    
                } else {
                    
                    YASClearAudioBufferList(renderInfo.ioData);
                    
                }
                
                noiseIndex = (noiseIndex + 1) % 100;
            }
        };
    }
}

- (void)_disposeNodes
{
    if (self.mixerNode) {
        
        [self removeNode:self.delayNode];
        [self removeNode:self.mixerNode];
        
        self.delayNode = nil;
        self.mixerNode = nil;
        self.delayToMixerConnection = nil;
        self.mixerToIOConnection = nil;
        
    }
}

- (void)dealloc
{
    [_mixerNode release];
    [_delayNode release];
    [_mixerToIOConnection release];
    [_delayToMixerConnection release];
    
    [super dealloc];
}

- (void)setMixerVolume:(AudioUnitParameterValue)val atBusIndex:(AudioUnitElement)busIndex
{
    if (_mixerNode) {
        [_mixerNode setParameter:kMultiChannelMixerParam_Volume value:val scope:kAudioUnitScope_Input element:busIndex];
    }
}

- (void)setDelayMix:(AudioUnitParameterValue)val
{
    if (_delayNode) {
        [_delayNode setParameter:kDelayParam_WetDryMix value:val scope:kAudioUnitScope_Global element:0];
    }
}

- (void)setDelayTime:(AudioUnitParameterValue)val
{
    if (_delayNode) {
        [_delayNode setParameter:kDelayParam_DelayTime value:val scope:kAudioUnitScope_Global element:0];
    }
}

- (void)setDelayFeedback:(AudioUnitParameterValue)val
{
    if (_delayNode) {
        [_delayNode setParameter:kDelayParam_Feedback value:val scope:kAudioUnitScope_Global element:0];
    }
}

- (void)addMixerConnection
{
    if (_mixerNode && !_mixerToIOConnection) {
        self.mixerToIOConnection = [self addConnectionWithSourceNode:_mixerNode sourceOutputNumber:0 destNode:self.ioNode destInputNumber:0];
        [self update];
    }
}

- (void)removeMixerConnection
{
    if (_mixerNode && _mixerToIOConnection) {
        [self removeConnection:_mixerToIOConnection];
        self.mixerToIOConnection = nil;
        [self update];
    }
}

- (void)addDelayConnection
{
    if (_mixerNode && _delayNode && !_delayToMixerConnection) {
        self.delayToMixerConnection = [self addConnectionWithSourceNode:_delayNode sourceOutputNumber:0 destNode:_mixerNode destInputNumber:1];
        [self update];
    }
}

- (void)removeDelayConnection
{
    if (_mixerNode && _delayNode && _delayToMixerConnection) {
        [self removeConnection:_delayToMixerConnection];
        self.delayToMixerConnection = nil;
        [self update];
    }
}

- (void)setupNodes
{
    [self _setupAudioSession];
    [self _setupNodes];
    self.running = YES;
    [self update];
}

- (void)disposeNodes
{
    self.running = NO;
    [self _disposeNodes];
    [self update];
}

- (BOOL)isNodesAvailable
{
    return _mixerNode != nil;
}

- (BOOL)isDelayConnected
{
    return _mixerNode && _delayNode && _delayToMixerConnection;
}

@end
