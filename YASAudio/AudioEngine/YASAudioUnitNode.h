//
//  YASAudioUnitNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioNode.h"

@class YASAudioGraph;

@interface YASAudioUnitNode : YASAudioNode

@property (atomic, strong) YASAudioUnit *audioUnit;
@property (nonatomic, strong, readonly) NSDictionary *globalParameterInfos;
@property (nonatomic, strong, readonly) NSDictionary *inputParameterInfos;
@property (nonatomic, strong, readonly) NSDictionary *outputParameterInfos;
@property (nonatomic, assign, readonly) NSUInteger inputElementCount;
@property (nonatomic, assign, readonly) NSUInteger outputElementCount;

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

@interface YASAudioUnitNode (YASInternal)

- (void)addAudioUnitToGraph:(YASAudioGraph *)graph;
- (void)removeAudioUnitFromGraph;

@end
