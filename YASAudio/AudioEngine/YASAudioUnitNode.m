//
//  YASAudioUnitNode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitNode.h"
#import "YASAudioUnitParameter.h"
#import "YASAudioConnection.h"
#import "YASAudioPCMBuffer.h"
#import "YASAudioFormat.h"
#import "YASAudioGraph.h"
#import "YASAudioUnit.h"
#import "YASAudioTime.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"
#import "NSNumber+YASAudio.h"

@interface YASAudioUnitNode ()

@property (nonatomic, assign, readonly) AudioComponentDescription acd;
@property (nonatomic, strong) YASWeakContainer *graphContainer;
@property (nonatomic, strong) NSDictionary *globalParameterInfos;
@property (nonatomic, strong) NSDictionary *inputParameterInfos;
@property (nonatomic, strong) NSDictionary *outputParameterInfos;

@end

@implementation YASAudioUnitNode

- (instancetype)initWithAudioComponentDescription:(const AudioComponentDescription *)acd
{
    self = [super init];
    if (self) {
        _acd = *acd;
        _audioUnit = [[YASAudioUnit alloc] initWithAudioComponentDescription:&_acd];
        self.globalParameterInfos = [_audioUnit getParameterInfosWithScope:kAudioUnitScope_Global];
        self.inputParameterInfos = [_audioUnit getParameterInfosWithScope:kAudioUnitScope_Input];
        self.outputParameterInfos = [_audioUnit getParameterInfosWithScope:kAudioUnitScope_Output];
    }
    return self;
}

- (instancetype)initWithType:(const OSType)type subType:(const OSType)subType
{
    const AudioComponentDescription acd = {
        .componentType = type,
        .componentSubType = subType,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    };

    return [self initWithAudioComponentDescription:&acd];
}

- (void)dealloc
{
    YASRelease(_audioUnit);
    YASRelease(_graphContainer);
    YASRelease(_globalParameterInfos);
    YASRelease(_inputParameterInfos);
    YASRelease(_outputParameterInfos);

    _audioUnit = nil;
    _graphContainer = nil;
    _globalParameterInfos = nil;
    _inputParameterInfos = nil;
    _outputParameterInfos = nil;

    YASSuperDealloc;
}

- (void)addAudioUnitToGraph:(YASAudioGraph *)graph
{
    if (!graph) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil", __PRETTY_FUNCTION__]));
        return;
    }

    self.graphContainer = graph.weakContainer;

    [self prepareAudioUnit];

    [graph addAudioUnit:self.audioUnit];

    [self prepareParameters];
}

- (void)removeAudioUnitFromGraph
{
    if (!_graphContainer) {
        YASLog(@"%s - AudioGraph is already released.", __PRETTY_FUNCTION__);
        return;
    }

    YASAudioGraph *graph = [self.graphContainer retainedObject];
    [graph removeAudioUnit:_audioUnit];
    YASRelease(graph);

    self.graphContainer = nil;
}

- (void)prepareAudioUnit
{
    [_audioUnit setMaximumFramesPerSlice:4096];
}

- (void)prepareParameters
{
    for (YASAudioUnitParameter *info in _globalParameterInfos.allValues) {
        [_audioUnit setParameter:info.parameterID value:info.value scope:kAudioUnitScope_Global element:0];
    }
}

- (void)updateConnections
{
    @synchronized(self)
    {
        @autoreleasepool
        {
            YASAudioUnit *audioUnit = self.audioUnit;
            if (audioUnit) {
                NSUInteger inputBusCount = self.inputElementCount;
                if (inputBusCount > 0) {
                    YASWeakContainer *container = self.weakContainer;
                    audioUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
                        @autoreleasepool
                        {
                            YASAudioNode *node = [container retainedObject];
                            YASAudioNodeCore *core = node.nodeCore;
                            YASAudioConnection *connection =
                                [core inputConnectionForBus:@(renderParameters->inBusNumber)];
                            YASAudioNode *sourceNode = connection.sourceNode;

                            if (connection && sourceNode) {
                                YASAudioPCMBuffer *buffer =
                                    [[YASAudioPCMBuffer alloc] initWithPCMFormat:connection.format
                                                                 audioBufferList:renderParameters->ioData
                                                                       needsFree:NO];
                                YASAudioTime *when =
                                    [[YASAudioTime alloc] initWithAudioTimeStamp:renderParameters->ioTimeStamp
                                                                      sampleRate:connection.format.sampleRate];

                                [sourceNode renderWithBuffer:buffer bus:connection.sourceBus when:when];

                                YASRelease(when);
                                YASRelease(buffer);
                            }
                            YASRelease(node);
                        }
                    };
                    for (UInt32 i = 0; i < inputBusCount; i++) {
                        NSNumber *bus = @(i);
                        YASAudioConnection *connection = [self inputConnectionForBus:bus];
                        if (connection) {
                            YASAudioFormat *format = connection.format;
                            [audioUnit setInputFormat:format.streamDescription busNumber:i];
                            [audioUnit setRenderCallback:i];
                        } else {
                            [audioUnit removeRenderCallback:i];
                        }
                    }
                } else {
                    audioUnit.renderCallbackBlock = nil;
                }

                NSUInteger outputBusCount = self.outputElementCount;
                if (outputBusCount > 0) {
                    for (UInt32 i = 0; i < outputBusCount; i++) {
                        NSNumber *bus = @(i);
                        YASAudioConnection *connection = [self outputConnectionForBus:bus];
                        if (connection) {
                            YASAudioFormat *format = connection.format;
                            [audioUnit setOutputFormat:format.streamDescription busNumber:i];
                        }
                    }
                }
            }
        }
    }
}

- (UInt32)inputBusCount
{
    return 1;
}

- (UInt32)outputBusCount
{
    return 1;
}

- (NSUInteger)inputElementCount
{
    return [_audioUnit elementCountForScope:kAudioUnitScope_Input];
}

- (NSUInteger)outputElementCount
{
    return [_audioUnit elementCountForScope:kAudioUnitScope_Output];
}

- (void)setGlobalParameter:(AudioUnitParameterID)parameterID value:(Float32)value
{
    YASAudioUnitParameter *info = _globalParameterInfos[@(parameterID)];
    info.value = value;

    [_audioUnit setParameter:parameterID value:value scope:kAudioUnitScope_Global element:0];
}

- (Float32)globalParameterValue:(AudioUnitParameterID)parameterID
{
    return [_audioUnit getParameter:parameterID scope:kAudioUnitScope_Global element:0];
}

- (void)setInputParameter:(AudioUnitParameterID)parameterID value:(Float32)value element:(AudioUnitElement)element
{
    YASAudioUnitParameter *info = _inputParameterInfos[@(parameterID)];
    info.value = value;

    [_audioUnit setParameter:parameterID value:value scope:kAudioUnitScope_Input element:element];
}

- (Float32)inputParameterValue:(AudioUnitParameterID)parameterID element:(AudioUnitElement)element
{
    return [_audioUnit getParameter:parameterID scope:kAudioUnitScope_Input element:element];
}

- (void)setOutputParameter:(AudioUnitParameterID)parameterID value:(Float32)value element:(AudioUnitElement)element
{
    YASAudioUnitParameter *info = _outputParameterInfos[@(parameterID)];
    info.value = value;

    [_audioUnit setParameter:parameterID value:value scope:kAudioUnitScope_Output element:element];
}

- (Float32)outputParameterValue:(AudioUnitParameterID)parameterID element:(AudioUnitElement)element
{
    return [_audioUnit getParameter:parameterID scope:kAudioUnitScope_Output element:element];
}

- (void)_reloadAudioUnit
{
    YASAudioGraph *graph = [self.graphContainer retainedObject];

    if (graph) {
        [self removeAudioUnitFromGraph];
    }

    YASAudioUnit *audioUnit = [[YASAudioUnit alloc] initWithAudioComponentDescription:&_acd];
    self.audioUnit = audioUnit;
    YASRelease(audioUnit);

    if (graph) {
        [self addAudioUnitToGraph:graph];
    }

    YASRelease(graph);
}

#pragma mark Render thread

- (void)renderWithBuffer:(YASAudioPCMBuffer *)buffer bus:(NSNumber *)bus when:(YASAudioTime *)when
{
    [super renderWithBuffer:buffer bus:bus when:when];

    @autoreleasepool
    {
        YASAudioUnit *audioUnit = self.audioUnit;
        AudioUnitRenderActionFlags actionFlags = 0;
        const AudioTimeStamp timeStamp = when.audioTimeStamp;

        YASAudioUnitRenderParameters renderParameters = {
            .inRenderType = YASAudioUnitRenderTypeNormal,
            .ioActionFlags = &actionFlags,
            .ioTimeStamp = &timeStamp,
            .inBusNumber = bus.uint32Value,
            .inNumberFrames = buffer.frameLength,
            .ioData = buffer.mutableAudioBufferList,
        };

        [audioUnit audioUnitRender:&renderParameters];
    }
}

@end
