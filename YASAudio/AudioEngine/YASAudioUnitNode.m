//
//  YASAudioUnitNode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitNode.h"
#import "YASAudioUnitParameter.h"
#import "YASAudioNode+Internal.h"
#import "YASAudioConnection+Internal.h"
#import "YASAudioData+Internal.h"
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
@property (nonatomic, strong) NSDictionary *parameters;

@end

@implementation YASAudioUnitNode

- (instancetype)initWithAudioComponentDescription:(const AudioComponentDescription *)acd
{
    self = [super init];
    if (self) {
        _acd = *acd;
        _audioUnit = [[YASAudioUnit alloc] initWithAudioComponentDescription:&_acd];
        self.parameters = @{
            @(kAudioUnitScope_Global): [_audioUnit getParametersWithScope:kAudioUnitScope_Global],
            @(kAudioUnitScope_Input): [_audioUnit getParametersWithScope:kAudioUnitScope_Input],
            @(kAudioUnitScope_Output): [_audioUnit getParametersWithScope:kAudioUnitScope_Output]
        };
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
    YASRelease(_parameters);

    _audioUnit = nil;
    _graphContainer = nil;
    _parameters = nil;

    YASSuperDealloc;
}

- (void)addAudioUnitToGraph:(YASAudioGraph *)graph
{
    if (!graph) {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Argument is nil. graph(%@)", __PRETTY_FUNCTION__, graph]));
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
    for (NSNumber *scopeKey in _parameters) {
        AudioUnitScope scope = scopeKey.uint32Value;
        NSDictionary *parametersInScope = _parameters[scopeKey];
        for (YASAudioUnitParameter *parameter in parametersInScope.allValues) {
            NSDictionary *elementValues = parameter.values;
            for (NSNumber *elementKey in elementValues) {
                AudioUnitElement element = elementKey.uint32Value;
                [_audioUnit setParameter:parameter.parameterID
                                   value:[parameter valueForElement:element]
                                   scope:scope
                                 element:element];
            }
        }
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
                                YASAudioData *data = [[YASAudioData alloc] initWithFormat:connection.format
                                                                          audioBufferList:renderParameters->ioData
                                                                                needsFree:NO];
                                YASAudioTime *when =
                                    [[YASAudioTime alloc] initWithAudioTimeStamp:renderParameters->ioTimeStamp
                                                                      sampleRate:connection.format.sampleRate];

                                [sourceNode renderWithData:data bus:connection.sourceBus when:when];

                                YASRelease(when);
                                YASRelease(data);
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

- (void)setInputElementCount:(const UInt32)inputElementCount
{
    [_audioUnit setElementCount:inputElementCount scope:kAudioUnitScope_Input];
}

- (UInt32)inputElementCount
{
    return [_audioUnit elementCountForScope:kAudioUnitScope_Input];
}

- (void)setOutputElementCount:(const UInt32)outputElementCount
{
    [_audioUnit setElementCount:outputElementCount scope:kAudioUnitScope_Output];
}

- (UInt32)outputElementCount
{
    return [_audioUnit elementCountForScope:kAudioUnitScope_Output];
}

- (void)setGlobalParameter:(AudioUnitParameterID)parameterID value:(Float32)value
{
    NSDictionary *globalParameters = _parameters[@(kAudioUnitScope_Global)];
    YASAudioUnitParameter *parameter = globalParameters[@(parameterID)];
    [parameter setValue:value forElement:0];
    [_audioUnit setParameter:parameterID value:value scope:kAudioUnitScope_Global element:0];
}

- (Float32)globalParameterValue:(AudioUnitParameterID)parameterID
{
    return [_audioUnit getParameter:parameterID scope:kAudioUnitScope_Global element:0];
}

- (void)setInputParameter:(AudioUnitParameterID)parameterID value:(Float32)value element:(AudioUnitElement)element
{
    UInt32 elementCount = [_audioUnit elementCountForScope:kAudioUnitScope_Input];
    if (element >= elementCount) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Out of range. element(%@) count(%@)", __PRETTY_FUNCTION__,
                                                       @(element), @(elementCount)]));
        return;
    }

    NSDictionary *inputParameters = _parameters[@(kAudioUnitScope_Input)];
    YASAudioUnitParameter *parameter = inputParameters[@(parameterID)];
    [parameter setValue:value forElement:element];
    [_audioUnit setParameter:parameterID value:value scope:kAudioUnitScope_Input element:element];
}

- (Float32)inputParameterValue:(AudioUnitParameterID)parameterID element:(AudioUnitElement)element
{
    UInt32 elementCount = [_audioUnit elementCountForScope:kAudioUnitScope_Input];
    if (element >= elementCount) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Out of range. element(%@) count=(%@)",
                                                       __PRETTY_FUNCTION__, @(element), @(elementCount)]));
        return 0;
    }

    return [_audioUnit getParameter:parameterID scope:kAudioUnitScope_Input element:element];
}

- (void)setOutputParameter:(AudioUnitParameterID)parameterID value:(Float32)value element:(AudioUnitElement)element
{
    UInt32 elementCount = [_audioUnit elementCountForScope:kAudioUnitScope_Output];
    if (element >= elementCount) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Out of range. element(%@) count(%@)", __PRETTY_FUNCTION__,
                                                       @(element), @(elementCount)]));
        return;
    }

    NSDictionary *outputParameters = _parameters[@(kAudioUnitScope_Output)];
    YASAudioUnitParameter *parameter = outputParameters[@(parameterID)];
    [parameter setValue:value forElement:element];
    [_audioUnit setParameter:parameterID value:value scope:kAudioUnitScope_Output element:element];
}

- (Float32)outputParameterValue:(AudioUnitParameterID)parameterID element:(AudioUnitElement)element
{
    UInt32 elementCount = [_audioUnit elementCountForScope:kAudioUnitScope_Output];
    if (element >= elementCount) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Out of range. element(%@) count(%@)", __PRETTY_FUNCTION__,
                                                       @(element), @(elementCount)]));
        return 0;
    }

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

- (void)renderWithData:(YASAudioData *)data bus:(NSNumber *)bus when:(YASAudioTime *)when
{
    [super renderWithData:data bus:bus when:when];

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
            .inNumberFrames = data.frameLength,
            .ioData = data.mutableAudioBufferList,
        };

        [audioUnit audioUnitRender:&renderParameters];
    }
}

@end
