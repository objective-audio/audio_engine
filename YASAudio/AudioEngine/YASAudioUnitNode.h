//
//  YASAudioUnitNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioNode.h"

@class YASAudioGraph, YASAudioUnit;

@interface YASAudioUnitNode : YASAudioNode

@property (atomic, strong) YASAudioUnit *audioUnit;
@property (nonatomic, strong, readonly) NSDictionary *parameters;
@property (nonatomic, assign, readonly) UInt32 inputElementCount;
@property (nonatomic, assign, readonly) UInt32 outputElementCount;

- (instancetype)initWithAudioComponentDescription:(const AudioComponentDescription *)acd NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithType:(const OSType)type subType:(const OSType)subType;

- (void)setGlobalParameter:(AudioUnitParameterID)parameterID value:(Float32)value;
- (Float32)globalParameterValue:(AudioUnitParameterID)parameterID;
- (void)setInputParameter:(AudioUnitParameterID)parameterID value:(Float32)value element:(AudioUnitElement)element;
- (Float32)inputParameterValue:(AudioUnitParameterID)parameterID element:(AudioUnitElement)element;
- (void)setOutputParameter:(AudioUnitParameterID)parameterID value:(Float32)value element:(AudioUnitElement)element;
- (Float32)outputParameterValue:(AudioUnitParameterID)parameterID element:(AudioUnitElement)element;

#pragma mark - Override by subclass

- (void)prepareAudioUnit;
- (void)prepareParameters NS_REQUIRES_SUPER;

@end
