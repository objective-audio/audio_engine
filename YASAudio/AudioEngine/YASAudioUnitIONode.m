//
//  YAS2AudioUnitIONode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitIONode.h"
#import "YASAudioNode+Internal.h"
#import "YASAudioTapNode.h"
#import "YASAudioConnection+Internal.h"
#import "YASAudioData+Internal.h"
#import "YASAudioFormat.h"
#import "YASAudioGraph.h"
#import "YASAudioUnit.h"
#import "YASAudioTime.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"
#import "NSNumber+YASAudio.h"
#import <AVFoundation/AVFoundation.h>

#if !TARGET_OS_IPHONE & TARGET_OS_MAC
#import "YASAudioDevice.h"
#endif

@implementation YASAudioUnitIONode

- (instancetype)init
{
    AudioComponentDescription acd = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = YASAudioUnitSubType_DefaultIO,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    };

    self = [super initWithAudioComponentDescription:&acd];
    if (self) {
    }
    return self;
}

- (void)dealloc
{
    YASRelease(_outputChannelMap);
    YASRelease(_inputChannelMap);

    _outputChannelMap = nil;
    _inputChannelMap = nil;

#if TARGET_OS_IPHONE

    YASRelease(_outputChannelAssignments);
    YASRelease(_inputChannelAssignments);

    _outputChannelAssignments = nil;
    _inputChannelAssignments = nil;

#endif

    YASSuperDealloc;
}

- (void)prepareAudioUnit
{
    [self.audioUnit setEnableOutput:YES];
    [self.audioUnit setEnableInput:YES];
    [self.audioUnit setMaximumFramesPerSlice:4096];
}

- (void)setOutputChannelMap:(NSArray *)channelMap
{
    if (![_outputChannelMap isEqualToArray:channelMap]) {
        YASRelease(_outputChannelMap);
        _outputChannelMap = YASRetain(channelMap);

        NSData *channelMapData = [channelMap yas_channelMapData];
        [self.audioUnit setChannelMap:channelMapData scope:kAudioUnitScope_Output];
    }
}

- (void)setInputChannelMap:(NSArray *)channelMap
{
    if (![_inputChannelMap isEqualToArray:channelMap]) {
        YASRelease(_inputChannelMap);
        _inputChannelMap = YASRetain(channelMap);

        NSData *channelMapData = [channelMap yas_channelMapData];
        [self.audioUnit setChannelMap:channelMapData scope:kAudioUnitScope_Input];
    }
}

#if TARGET_OS_IPHONE

- (void)setOutputChannelAssignments:(NSArray *)outputChannelAssignments
{
    if (_outputChannelAssignments != outputChannelAssignments) {
        YASRelease(_outputChannelAssignments);
        _outputChannelAssignments = YASRetain(outputChannelAssignments);

        self.outputChannelMap =
            [self.class channelMapFromChannelAssignments:outputChannelAssignments scope:kAudioUnitScope_Output];
    }
}

- (void)setInputChannelAssignments:(NSArray *)inputChannelAssignments
{
    if (_inputChannelAssignments != inputChannelAssignments) {
        YASRelease(_inputChannelAssignments);
        _inputChannelAssignments = YASRetain(inputChannelAssignments);

        self.inputChannelMap =
            [self.class channelMapFromChannelAssignments:inputChannelAssignments scope:kAudioUnitScope_Input];
    }
}

+ (NSArray *)channelMapFromChannelAssignments:(NSArray *)channelAssignments scope:(AudioUnitScope)scope
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *routeDesc = audioSession.currentRoute;

    NSInteger channelCount = 0;
    NSArray *portDescriptions = nil;

    if (scope == kAudioUnitScope_Input) {
        channelCount = audioSession.inputNumberOfChannels;
        portDescriptions = routeDesc.inputs;
    } else if (scope == kAudioUnitScope_Output) {
        channelCount = audioSession.outputNumberOfChannels;
        portDescriptions = routeDesc.outputs;
    } else {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s Out of scope.", __PRETTY_FUNCTION__]));
        return nil;
    }

    if (channelCount == 0) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s Channel count is 0.", __PRETTY_FUNCTION__]));
        return nil;
    }

    NSMutableArray *mutableChannelMap = [[NSMutableArray alloc] initWithCapacity:channelCount];

    for (AVAudioSessionPortDescription *portDescription in portDescriptions) {
        for (AVAudioSessionChannelDescription *channelDescription in portDescription.channels) {
            UInt32 idx = 0;
            UInt32 assignIndex = -1;

            for (AVAudioSessionChannelDescription *assignChannelDescription in channelAssignments) {
                if ([assignChannelDescription.owningPortUID isEqualToString:portDescription.UID] &&
                    assignChannelDescription.channelNumber == channelDescription.channelNumber) {
                    assignIndex = idx;
                    break;
                }
                idx++;
            }

            [mutableChannelMap addObject:@(assignIndex)];
        }
    }

    NSArray *channelMap = [mutableChannelMap copy];
    YASRelease(mutableChannelMap);

    return YASAutorelease(channelMap);
}

#elif TARGET_OS_MAC

- (void)setDevice:(YASAudioDevice *)device
{
    if (!device) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s Argument is nil.", __PRETTY_FUNCTION__]));
    }

    self.audioUnit.currentDevice = device.audioDeviceID;
}

- (YASAudioDevice *)device
{
    return [YASAudioDevice deviceForID:self.audioUnit.currentDevice];
}

#endif

- (void)prepareParameters
{
    [super prepareParameters];

    if (_outputChannelMap) {
        NSData *channelMapData = [_outputChannelMap yas_channelMapData];
        [self.audioUnit setChannelMap:channelMapData scope:kAudioUnitScope_Output];
    }

    if (_inputChannelMap) {
        NSData *channelMapData = [_inputChannelMap yas_channelMapData];
        [self.audioUnit setChannelMap:channelMapData scope:kAudioUnitScope_Input];
    }
}

- (NSNumber *)nextAvailableOutputBus
{
    NSNumber *bus = [super nextAvailableOutputBus];
    if ([bus isEqualToNumber:@0]) {
        bus = @1;
    }
    return bus;
}

- (BOOL)isAvailableOutputBus:(NSNumber *)bus
{
    if ([bus isEqualToNumber:@1]) {
        bus = @0;
    } else {
        return NO;
    }
    return [super isAvailableOutputBus:bus];
}

@end

#pragma mark -

@implementation YASAudioUnitOutputNode

- (void)prepareAudioUnit
{
    [self.audioUnit setEnableOutput:YES];
    [self.audioUnit setEnableInput:NO];
    [self.audioUnit setMaximumFramesPerSlice:4096];
}

- (UInt32)inputBusCount
{
    return 1;
}

- (UInt32)outputBusCount
{
    return 0;
}

@end

#pragma mark -

@interface YASAudioUnitInputNode ()

@property (atomic, strong) YASAudioData *inputData;
@property (atomic, strong) YASAudioTime *renderTime;

@end

@implementation YASAudioUnitInputNode

- (void)dealloc
{
    YASRelease(_inputData);
    YASRelease(_renderTime);

    _inputData = nil;
    _renderTime = nil;

    YASSuperDealloc;
}

- (void)prepareAudioUnit
{
    [self.audioUnit setEnableOutput:NO];
    [self.audioUnit setEnableInput:YES];
    [self.audioUnit setMaximumFramesPerSlice:4096];
}

- (UInt32)inputBusCount
{
    return 0;
}

- (UInt32)outputBusCount
{
    return 1;
}

- (void)updateConnections
{
    [super updateConnections];

    @autoreleasepool
    {
        YASAudioUnit *audioUnit = self.audioUnit;
        YASAudioConnection *outputConnection = [self outputConnectionForBus:@1];

        if (outputConnection) {
            [audioUnit setInputCallback];

            YASAudioFormat *format = outputConnection.format;
            YASAudioData *inputData = [[YASAudioData alloc] initWithFormat:format frameCapacity:4096];
            YASWeakContainer *inputNodeContainer = self.weakContainer;

            audioUnit.inputCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
                if (renderParameters->inNumberFrames <= inputData.frameCapacity) {
                    inputData.frameLength = renderParameters->inNumberFrames;
                    renderParameters->ioData = inputData.mutableAudioBufferList;

                    YASAudioUnitInputNode *inputNode = [inputNodeContainer retainedObject];

                    if (inputNode) {
                        YASAudioNodeCore *nodeCore = [inputNode nodeCore];
                        YASAudioConnection *connection = [nodeCore outputConnectionForBus:@1];

                        YASAudioTime *time = [[YASAudioTime alloc] initWithAudioTimeStamp:renderParameters->ioTimeStamp
                                                                               sampleRate:connection.format.sampleRate];
                        [inputNode setRenderTimeOnRender:time];
                        YASRelease(time);

                        @autoreleasepool
                        {
                            YASAudioUnit *ioUnit = inputNode.audioUnit;

                            if (ioUnit) {
                                renderParameters->inBusNumber = 1;
                                [ioUnit audioUnitRender:renderParameters];
                            }

                            id destinationNode = connection.destinationNode;

                            if ([destinationNode isKindOfClass:[YASAudioInputTapNode class]]) {
                                YASAudioInputTapNode *inputTapNode = destinationNode;
                                [inputTapNode renderWithData:inputData bus:@0 when:time];
                            }
                        }
                    }

                    YASRelease(inputNode);
                }
            };

            self.inputData = inputData;
            YASRelease(inputData);
        } else {
            [audioUnit removeInputCallback];
            audioUnit.inputCallbackBlock = NULL;
            self.inputData = nil;
        }
    }
}

#pragma mark Render thread

- (void)render:(YASAudioUnitRenderParameters *)renderParameters format:(YASAudioFormat *)format
{
    YASAudioData *renderData =
        [[YASAudioData alloc] initWithFormat:format audioBufferList:renderParameters->ioData needsFree:NO];
    YASAudioData *inputData = self.inputData;
    UInt32 renderFrameLength = renderParameters->inNumberFrames;

    if (renderData.audioBufferList != inputData.audioBufferList) {
        if (inputData && renderFrameLength <= inputData.frameLength) {
            [renderData copyFromData:inputData fromStartFrame:0 toStartFrame:0 length:renderFrameLength];
        } else {
            [renderData clear];
        }
    }

    YASRelease(renderData);
}

@end

#pragma mark -

@implementation NSArray (YASAudioUnitIONode)

- (NSData *)yas_channelMapData
{
    NSUInteger count = self.count;
    if (count > 0) {
        NSMutableData *data = [NSMutableData dataWithLength:self.count * sizeof(UInt32)];
        UInt32 *ptr = data.mutableBytes;
        for (UInt32 i = 0; i < count; i++) {
            NSNumber *numberValue = self[i];
            ptr[i] = numberValue.uint32Value;
        }
        return data;
    } else {
        return nil;
    }
}

+ (NSArray *)yas_channelMapArrayWithData:(NSData *)data
{
    if (data.length > 0) {
        NSUInteger count = data.length / sizeof(UInt32);
        NSMutableArray *array = [NSMutableArray array];
        const UInt32 *ptr = data.bytes;
        for (UInt32 i = 0; i < count; i++) {
            [array addObject:@(ptr[i])];
        }
        return YASAutorelease([array copy]);
    } else {
        return nil;
    }
}

@end