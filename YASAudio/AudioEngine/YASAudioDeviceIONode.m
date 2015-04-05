//
//  YASAudioDeviceIONode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioDeviceIONode.h"
#import "YASAudioDevice.h"
#import "YASAudioNode.h"
#import "YASAudioGraph.h"
#import "YASAudioConnection.h"
#import "YASAudioDeviceIO.h"
#import "YASAudioTapNode.h"
#import "YASAudioChannelRoute.h"
#import "YASAudioPCMBuffer.h"
#import "YASAudioFormat.h"
#import "YASAudioTime.h"
#import "YASWeakSupport.h"
#import "YASMacros.h"
#import "NSNumber+YASAudio.h"
#import "NSException+YASAudio.h"
#import "YASAudioUtility.h"

@interface YASAudioDeviceIONodeCore : YASAudioNodeCore

@property (nonatomic, strong) NSSet *outputChannelRoutes;
@property (nonatomic, strong) NSSet *inputChannelRoutes;

@end

@implementation YASAudioDeviceIONodeCore

- (void)dealloc
{
    YASRelease(_outputChannelRoutes);
    YASRelease(_inputChannelRoutes);

    _outputChannelRoutes = nil;
    _inputChannelRoutes = nil;

    YASSuperDealloc;
}

- (NSArray *)outputChannelRoutesWithSourceBus:(NSNumber *)sourceBus format:(YASAudioFormat *)format
{
    if (!_outputChannelRoutes) {
        return [YASAudioChannelRoute defaultChannelRoutesWithBus:sourceBus.uint32Value format:format];
    }

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", YASAudioSourceBusKey, sourceBus];
    NSSortDescriptor *chDesc = [NSSortDescriptor sortDescriptorWithKey:YASAudioSourceChannelKey ascending:YES];
    NSSet *filteredSet = [_outputChannelRoutes filteredSetUsingPredicate:predicate];
    NSArray *sortedAssignments = [filteredSet sortedArrayUsingDescriptors:@[chDesc]];

    BOOL result = NO;

    if (sortedAssignments.count == format.channelCount) {
        result = YES;
        for (UInt32 i = 0; i < sortedAssignments.count; i++) {
            YASAudioChannelRoute *route = sortedAssignments[i];
            if (route.sourceChannel != i) {
                result = NO;
                break;
            }
        }
    }

    if (!result) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Invalid channel routes.", __PRETTY_FUNCTION__]));
        return nil;
    }

    return sortedAssignments;
}

- (NSArray *)inputChannelRoutesWithDestinationBus:(NSNumber *)destinationBus format:(YASAudioFormat *)format
{
    if (!_inputChannelRoutes) {
        return [YASAudioChannelRoute defaultChannelRoutesWithBus:destinationBus.uint32Value format:format];
    }

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", YASAudioDestinationBusKey, destinationBus];
    NSSortDescriptor *chDesc = [NSSortDescriptor sortDescriptorWithKey:YASAudioDestinationChannelKey ascending:YES];
    NSSet *filteredSet = [_inputChannelRoutes filteredSetUsingPredicate:predicate];
    NSArray *sortedAssignments = [filteredSet sortedArrayUsingDescriptors:@[chDesc]];

    BOOL result = NO;

    if (sortedAssignments.count == format.channelCount) {
        result = YES;
        for (UInt32 i = 0; i < sortedAssignments.count; i++) {
            YASAudioChannelRoute *route = sortedAssignments[i];
            if (route.destinationChannel != i) {
                result = NO;
                break;
            }
        }
    }

    if (!result) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Invalid channel routes.", __PRETTY_FUNCTION__]));
        return nil;
    }

    return sortedAssignments;
}

@end

@interface YASAudioDeviceIONode ()

@property (nonatomic, strong) YASAudioDeviceIO *audioDeviceIO;
@property (atomic, strong) YASWeakContainer *graphContainer;
@property (nonatomic, strong) YASAudioDeviceIONodeCore *nodeCoreOnRender;

@end

@implementation YASAudioDeviceIONode {
    YASAudioDevice *_audioDevice;
}

- (instancetype)init
{
    YASAudioDevice *device = [YASAudioDevice defaultOutputDevice];
    return [self initWithAudioDevice:device];
}

- (instancetype)initWithAudioDevice:(YASAudioDevice *)audioDevice
{
    self = [super init];
    if (self) {
        if (!audioDevice) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
            YASRelease(self);
            return nil;
        }
        _audioDevice = YASRetain(audioDevice);
        [self updateNodeCore];
    }
    return self;
}

- (void)dealloc
{
    YASRelease(_nodeCoreOnRender);
    YASRelease(_audioDevice);
    YASRelease(_audioDeviceIO);
    YASRelease(_graphContainer);

    _nodeCoreOnRender = nil;
    _audioDevice = nil;
    _audioDeviceIO = nil;
    _graphContainer = nil;

    YASSuperDealloc;
}

- (void)setAudioDevice:(YASAudioDevice *)audioDevice
{
    if (![_audioDevice isEqualToAudioDevice:audioDevice]) {
        YASRelease(_audioDevice);
        _audioDevice = YASRetain(audioDevice);

        self.audioDeviceIO.audioDevice = audioDevice;
        [self _notifyDidChangeAudioDevice];
    }
}

- (YASAudioDevice *)audioDevice
{
    return _audioDevice;
}

- (void)addAudioDeviceIOToGraph:(YASAudioGraph *)graph
{
    if (!graph) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil", __PRETTY_FUNCTION__]));
        return;
    }

    if (_audioDeviceIO) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - AudioDeviceIO is already added", __PRETTY_FUNCTION__]));
        return;
    }

    self.graphContainer = graph.weakContainer;

    YASAudioDeviceIO *deviceIO = [[YASAudioDeviceIO alloc] initWithAudioDevice:self.audioDevice];
    self.audioDeviceIO = deviceIO;
    [graph addAudioDeviceIO:deviceIO];
    YASRelease(deviceIO);
}

- (void)removeAudioDeviceIOFromGraph
{
    if (!_graphContainer) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - AudioGraph is nil", __PRETTY_FUNCTION__]));
        return;
    }

    if (!_audioDeviceIO) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - AudioDeviceIO is removed", __PRETTY_FUNCTION__]));
        return;
    }

    YASAudioGraph *graph = [self.graphContainer retainedObject];
    [graph removeAudioDeviceIO:_audioDeviceIO];
    YASRelease(graph);

    self.graphContainer = nil;
    self.audioDeviceIO = nil;
}

- (void)prepareParameters
{
}

- (BOOL)_validateConnections
{
    @autoreleasepool
    {
        YASAudioDeviceIO *audioDeviceIO = self.audioDeviceIO;

        if (audioDeviceIO) {
            NSDictionary *inputConnections = self.inputConnections;
            if (inputConnections.count > 0) {
                for (YASAudioConnection *connection in inputConnections.objectEnumerator) {
                    YASAudioFormat *connectionFormat = connection.format;
                    YASAudioFormat *deviceFormat = audioDeviceIO.audioDevice.outputFormat;
                    if (connectionFormat.bitDepthFormat != deviceFormat.bitDepthFormat ||
                        connectionFormat.sampleRate != deviceFormat.sampleRate || connectionFormat.isInterleaved) {
                        YASLog(@"%s - Output device io format is not match.", __PRETTY_FUNCTION__);
                        return NO;
                    }
                }
            }
            NSDictionary *outputConnections = self.outputConnections;
            if (outputConnections.count > 0) {
                for (YASAudioConnection *connection in outputConnections.objectEnumerator) {
                    YASAudioFormat *connectionFormat = connection.format;
                    YASAudioFormat *deviceFormat = audioDeviceIO.audioDevice.inputFormat;
                    if (connectionFormat.bitDepthFormat != deviceFormat.bitDepthFormat ||
                        connectionFormat.sampleRate != deviceFormat.sampleRate || connectionFormat.isInterleaved) {
                        YASLog(@"%s - Input device io format is not match.", __PRETTY_FUNCTION__);
                        return NO;
                    }
                }
            }
        }
    }

    return YES;
}

- (void)updateConnections
{
    @autoreleasepool
    {
        YASAudioDeviceIO *audioDeviceIO = self.audioDeviceIO;
        if (!audioDeviceIO) {
            return;
        }

        if (![self _validateConnections]) {
            audioDeviceIO.renderCallbackBlock = nil;
            return;
        }

        YASWeakContainer *nodeContainer = self.weakContainer;
        YASWeakContainer *deviceIOContainer = audioDeviceIO.weakContainer;

        audioDeviceIO.renderCallbackBlock = ^(YASAudioPCMBuffer *outBuffer, YASAudioTime *when) {
            @autoreleasepool
            {
                YASAudioDeviceIONode *node = [nodeContainer autoreleasingObject];
                if (!node) {
                    return;
                }

                YASAudioDeviceIONodeCore *core = node.nodeCore;
                if (!core) {
                    return;
                }

                self.nodeCoreOnRender = core;

                if (outBuffer) {
                    NSDictionary *connections = core.inputConnections;
                    for (YASAudioConnection *connection in connections.objectEnumerator) {
                        NSArray *channelRoutes =
                            [core outputChannelRoutesWithSourceBus:connection.sourceBus format:connection.format];
                        if (channelRoutes) {
                            YASAudioFormat *format = connection.format;
                            YASAudioPCMBuffer *renderBuffer =
                                [[YASAudioPCMBuffer alloc] initWithPCMFormat:format
                                                                      buffer:outBuffer
                                                         outputChannelRoutes:channelRoutes];

                            YASAudioNode *sourceNode = connection.sourceNode;
                            [sourceNode renderWithBuffer:renderBuffer bus:connection.sourceBus when:when];

                            YASRelease(renderBuffer);
                        }
                    }
                }

                {
                    YASAudioDeviceIO *deviceIO = [deviceIOContainer retainedObject];
                    if (deviceIO) {
                        NSDictionary *connections = core.outputConnections;
                        for (YASAudioConnection *connection in connections.objectEnumerator) {
                            id destinationNode = connection.destinationNode;
                            if ([destinationNode isKindOfClass:[YASAudioInputTapNode class]]) {
                                YASAudioInputTapNode *inputTapNode = destinationNode;
                                YASAudioFormat *format = connection.format;

                                NSArray *channelRoutes =
                                    [core inputChannelRoutesWithDestinationBus:connection.destinationBus format:format];
                                if (channelRoutes) {
                                    YASAudioPCMBuffer *inputBuffer = [deviceIO inputBufferOnRender];
                                    YASAudioTime *inputTime = [deviceIO inputTimeOnRender];
                                    if (inputBuffer && inputTime) {
                                        YASAudioPCMBuffer *renderBuffer =
                                            [[YASAudioPCMBuffer alloc] initWithPCMFormat:format
                                                                                  buffer:inputBuffer
                                                                      inputChannelRoutes:channelRoutes];

                                        [inputTapNode renderWithBuffer:renderBuffer bus:@0 when:inputTime];

                                        YASRelease(renderBuffer);
                                    }
                                }
                            }
                        }

                        YASRelease(deviceIO);
                    }
                }

                self.nodeCoreOnRender = nil;
            }
        };
    }
}

- (UInt32)inputBusCount
{
    return UINT32_MAX;
}

- (UInt32)outputBusCount
{
    return UINT32_MAX;
}

- (void)setOutputChannelAssignments:(NSSet *)routes
{
    if (_outputChannelRoutes != routes) {
        YASRelease(_outputChannelRoutes);
        _outputChannelRoutes = YASRetain(routes);

        [self updateNodeCore];
    }
}

- (void)setInputChannelAssignments:(NSSet *)routes
{
    if (_inputChannelRoutes != routes) {
        YASRelease(_inputChannelRoutes);
        _inputChannelRoutes = YASRetain(routes);

        [self updateNodeCore];
    }
}

#pragma mark Private

- (Class)nodeCoreClass
{
    return [YASAudioDeviceIONodeCore class];
}

- (id)newNodeCoreObject
{
    YASAudioDeviceIONodeCore *core = [super newNodeCoreObject];
    core.outputChannelRoutes = _outputChannelRoutes;
    core.inputChannelRoutes = _inputChannelRoutes;

    return core;
}

- (void)_notifyDidChangeAudioDevice
{
}

#pragma mark Render thread

- (void)renderWithBuffer:(YASAudioPCMBuffer *)buffer bus:(NSNumber *)bus when:(YASAudioTime *)when
{
    [super renderWithBuffer:buffer bus:bus when:when];

    @autoreleasepool
    {
        YASAudioDeviceIO *audioDeviceIO = self.audioDeviceIO;
        if (audioDeviceIO) {
            YASAudioFormat *format = buffer.format;
            YASAudioFormat *deviceFormat = audioDeviceIO.audioDevice.inputFormat;
            if (format.bitDepthFormat != deviceFormat.bitDepthFormat || format.isInterleaved) {
                YASRaiseWithReason(([NSString stringWithFormat:@"%s - Format is not match.", __PRETTY_FUNCTION__]));
                return;
            }

            YASAudioDeviceIONodeCore *nodeCore = self.nodeCoreOnRender;
            if (nodeCore) {
                NSArray *channelRoutes = [nodeCore inputChannelRoutesWithDestinationBus:bus format:format];
                if (channelRoutes) {
                    YASAudioPCMBuffer *inputBuffer = [audioDeviceIO inputBufferOnRender];
                    const AudioBufferList *inputAudioBufferList = inputBuffer.audioBufferList;
                    const AudioBufferList *outputAudioBufferList = buffer.audioBufferList;
                    if (inputAudioBufferList &&
                        !YASAudioIsEqualAudioBufferListStructure(inputAudioBufferList, outputAudioBufferList)) {
                        YASAudioPCMBuffer *renderBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format
                                                                                                buffer:inputBuffer
                                                                                    inputChannelRoutes:channelRoutes];

                        [buffer copyDataFlexiblyFromBuffer:renderBuffer];

                        YASRelease(renderBuffer);
                    }
                }
            }
        }
    }
}

@end
