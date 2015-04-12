//
//  YASAudioNode.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioNode.h"
#import "YASAudioEngine.h"
#import "YASAudioConnection.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"
#import "NSNumber+YASAudio.h"
#import "NSDictionary+YASAudio.h"

@interface YASAudioNodeCore ()

@property (nonatomic, copy) NSDictionary *inputConnectionContainers;
@property (nonatomic, copy) NSDictionary *outputConnectionContainers;

@end

@implementation YASAudioNodeCore

- (void)dealloc
{
    YASRelease(_inputConnectionContainers);
    YASRelease(_outputConnectionContainers);

    _inputConnectionContainers = nil;
    _outputConnectionContainers = nil;

    YASSuperDealloc;
}

- (YASAudioConnection *)inputConnectionForBus:(NSNumber *)bus
{
    YASRaiseIfMainThread;

    YASWeakContainer *container = _inputConnectionContainers[bus];
    return [container autoreleasingObject];
}

- (YASAudioConnection *)outputConnectionForBus:(NSNumber *)bus
{
    YASRaiseIfMainThread;

    YASWeakContainer *container = _outputConnectionContainers[bus];
    return [container autoreleasingObject];
}

- (NSDictionary *)inputConnections
{
    YASRaiseIfMainThread;

    return [_inputConnectionContainers yas_unwrappedDictionaryFromWeakContainers];
}

- (NSDictionary *)outputConnections
{
    YASRaiseIfMainThread;

    return [_outputConnectionContainers yas_unwrappedDictionaryFromWeakContainers];
}

@end

@interface YASAudioNode ()

@property (nonatomic, strong) YASWeakContainer *engineContainer;
@property (atomic, strong) id nodeCore;
@property (atomic, strong) YASAudioTime *renderTime;

@end

@implementation YASAudioNode {
    NSMutableDictionary *_inputConnectionContainers;
    NSMutableDictionary *_outputConnectionContainers;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _inputConnectionContainers = [[NSMutableDictionary alloc] initWithCapacity:8];
        _outputConnectionContainers = [[NSMutableDictionary alloc] initWithCapacity:8];
    }
    return self;
}

- (void)dealloc
{
    @autoreleasepool
    {
        for (YASWeakContainer *container in _inputConnectionContainers.objectEnumerator) {
            YASAudioConnection *inputConnection = [container retainedObject];
            [inputConnection removeDestinationNode];
            YASRelease(inputConnection);
        }
        for (YASWeakContainer *container in _outputConnectionContainers.objectEnumerator) {
            YASAudioConnection *outputConnection = [container retainedObject];
            [outputConnection removeSourceNode];
            YASRelease(outputConnection);
        }
    }

    YASRelease(_inputConnectionContainers);
    YASRelease(_outputConnectionContainers);
    YASRelease(_renderTime);
    YASRelease(_nodeCore);
    YASRelease(_engineContainer);

    _inputConnectionContainers = nil;
    _outputConnectionContainers = nil;
    _renderTime = nil;
    _nodeCore = nil;
    _engineContainer = nil;

    YASSuperDealloc;
}

- (void)reset
{
    [_inputConnectionContainers removeAllObjects];
    [_outputConnectionContainers removeAllObjects];

    [self updateNodeCore];
}

- (void)updateConnections
{
}

- (YASAudioFormat *)inputFormatForBus:(NSNumber *)bus
{
    YASRaiseIfSubThread;

    YASWeakContainer *container = [_inputConnectionContainers objectForKey:bus];
    YASAudioConnection *connection = [container retainedObject];
    YASAudioFormat *format = connection.format;
    YASRelease(connection);
    return format;
}

- (YASAudioFormat *)outputFormatForBus:(NSNumber *)bus
{
    YASRaiseIfSubThread;

    YASWeakContainer *container = [_outputConnectionContainers objectForKey:bus];
    YASAudioConnection *connection = [container retainedObject];
    YASAudioFormat *format = connection.format;
    YASRelease(connection);
    return format;
}

- (void)setEngine:(YASAudioEngine *)engine
{
    self.engineContainer = engine.weakContainer;
}

- (YASAudioEngine *)engine
{
    return [_engineContainer autoreleasingObject];
}

- (YASAudioTime *)lastRenderTime
{
    return self.renderTime;
}

#pragma mark Core

- (Class)nodeCoreClass
{
    return [YASAudioNodeCore class];
}

- (id)newNodeCoreObject
{
    YASAudioNodeCore *core = [[[self nodeCoreClass] alloc] init];
    core.inputConnectionContainers = _inputConnectionContainers;
    core.outputConnectionContainers = _outputConnectionContainers;

    return core;
}

- (void)updateNodeCore
{
    id core = [self newNodeCoreObject];
    self.nodeCore = core;
    YASRelease(core);
}

#pragma mark Connection

- (void)addConnection:(YASAudioConnection *)connection
{
    if (connection.destinationNode == self) {
        _inputConnectionContainers[connection.destinationBus] = connection.weakContainer;
    } else if (connection.sourceNode == self) {
        _outputConnectionContainers[connection.sourceBus] = connection.weakContainer;
    } else {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Connection does not exist in a node.", __PRETTY_FUNCTION__]));
    }

    [self updateNodeCore];
}

- (void)removeConnection:(YASAudioConnection *)connection
{
    if (connection.destinationNode == self) {
        NSNumber *toBus = connection.destinationBus;
        [_inputConnectionContainers removeObjectForKey:toBus];
    }

    if (connection.sourceNode == self) {
        NSNumber *fromBus = connection.sourceBus;
        [_outputConnectionContainers removeObjectForKey:fromBus];
    }

    [self updateNodeCore];
}

- (YASAudioConnection *)inputConnectionForBus:(NSNumber *)bus
{
    YASRaiseIfSubThread;

    YASWeakContainer *container = _inputConnectionContainers[bus];
    return [container autoreleasingObject];
}

- (YASAudioConnection *)outputConnectionForBus:(NSNumber *)bus
{
    YASRaiseIfSubThread;

    YASWeakContainer *container = _outputConnectionContainers[bus];
    return [container autoreleasingObject];
}

- (NSDictionary *)inputConnections
{
    YASRaiseIfSubThread;

    return [_inputConnectionContainers yas_unwrappedDictionaryFromWeakContainers];
}

- (NSDictionary *)outputConnections
{
    YASRaiseIfSubThread;

    return [_outputConnectionContainers yas_unwrappedDictionaryFromWeakContainers];
}

#pragma mark Bus

- (UInt32)inputBusCount
{
    return 0;
}

- (UInt32)outputBusCount
{
    return 0;
}

- (NSNumber *)nextAvailableInputBus
{
    return [_inputConnectionContainers yas_emptyNumberKeyInLength:self.inputBusCount];
}

- (NSNumber *)nextAvailableOutputBus
{
    return [_outputConnectionContainers yas_emptyNumberKeyInLength:self.outputBusCount];
}

- (BOOL)isAvailableInputBus:(NSNumber *)bus
{
    if (bus.uint32Value >= self.inputBusCount) {
        return NO;
    }

    return _inputConnectionContainers[bus] == nil;
}

- (BOOL)isAvailableOutputBus:(NSNumber *)bus
{
    if (bus.uint32Value >= self.outputBusCount) {
        return NO;
    }

    return _outputConnectionContainers[bus] == nil;
}

#pragma mark Render thread

- (void)renderWithData:(YASAudioData *)data bus:(NSNumber *)bus when:(YASAudioTime *)when
{
    [self setRenderTimeOnRender:when];
}

- (void)setRenderTimeOnRender:(YASAudioTime *)time
{
    self.renderTime = time;
}

@end
