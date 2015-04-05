//
//  YASAudioEngine.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngine.h"
#import "YASAudioConnection.h"
#import "YASAudioUnitNode.h"
#import "YASAudioGraph.h"
#import "YASAudioOfflineOutputNode.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"
#import "NSError+YASAudio.h"
#import <AVFoundation/AVFoundation.h>

#if (!TARGET_OS_IPHONE & TARGET_OS_MAC)
#import "YASAudioDeviceIO.h"
#import "YASAudioDeviceIONode.h"
#endif

NSString *const YASAudioEngineConfigurationChangeNotification = @"YASAudioEngineConfigurationChangeNotification";

@interface YASAudioEngine ()

@property (nonatomic, strong) YASAudioGraph *graph;
@property (nonatomic, strong, readonly) NSMutableSet *nodes;
@property (nonatomic, strong, readonly) NSMutableSet *connections;
@property (nonatomic, strong) YASAudioOfflineOutputNode *offlineOutputNode;

@end

@implementation YASAudioEngine

- (instancetype)init
{
    self = [super init];
    if (self) {
        _nodes = [[NSMutableSet alloc] init];
        _connections = [[NSMutableSet alloc] init];
#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioSessionMediaServicesWereResetNotification:)
                                                     name:AVAudioSessionMediaServicesWereResetNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioSessionRouteChangeNotification:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
#endif
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    YASRelease(_graph);
    YASRelease(_nodes);
    YASRelease(_connections);
    YASRelease(_offlineOutputNode);

    _graph = nil;
    _nodes = nil;
    _connections = nil;
    _offlineOutputNode = nil;

    YASSuperDealloc;
}

- (void)_attachNode:(YASAudioNode *)node
{
    if (!node) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
    }

    if ([_nodes containsObject:node]) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Node is already attached.", __PRETTY_FUNCTION__]));
    }

    [_nodes addObject:node];
    node.engine = self;

    [self _addNodeToGraph:node];
}

- (void)_detachNode:(YASAudioNode *)node
{
    if (!node) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
    }

    if (![_nodes containsObject:node]) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Node is not attached.", __PRETTY_FUNCTION__]));
    }

    [self disconnectNodeOutput:node];
    [self disconnectNodeInput:node];

    [self _removeNodeFromGraph:node];

    node.engine = nil;
    [_nodes removeObject:node];
}

- (void)_detachNodeIfUnused:(YASAudioNode *)node
{
    @autoreleasepool
    {
        NSPredicate *predicate =
            [NSPredicate predicateWithFormat:@"sourceNode = %@ || destinationNode = %@", node, node];
        NSSet *filteredSet = [self.connections filteredSetUsingPredicate:predicate];
        if (filteredSet.count == 0) {
            [self _detachNode:node];
        }
    }
}

- (YASAudioConnection *)connectFromNode:(YASAudioNode *)sourceNode
                                 toNode:(YASAudioNode *)destinationNode
                                fromBus:(NSNumber *)sourceBus
                                  toBus:(NSNumber *)destinationBus
                                 format:(YASAudioFormat *)format
{
    if (!sourceBus || !destinationBus) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return nil;
    }

    if (![sourceNode isAvailableOutputBus:sourceBus]) {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Output bus(%@) is not available.", __PRETTY_FUNCTION__, sourceBus]));
        return nil;
    }

    if (![destinationNode isAvailableInputBus:destinationBus]) {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Input bus(%@) is not available.", __PRETTY_FUNCTION__, destinationBus]));
        return nil;
    }

    if (!format) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Format is nil.", __PRETTY_FUNCTION__]));
        return nil;
    }

    if (![_nodes containsObject:sourceNode]) {
        [self _attachNode:sourceNode];
    }

    if (![_nodes containsObject:destinationNode]) {
        [self _attachNode:destinationNode];
    }

#if DEBUG
    @autoreleasepool
    {
        NSPredicate *predicate = [NSPredicate
            predicateWithFormat:@"(sourceNode = %@ && sourceBus = %@) || (destinationNode = %@ && destinationBus = %@)",
                                sourceNode, sourceBus, destinationNode, destinationBus];
        NSSet *set = [_connections filteredSetUsingPredicate:predicate];
        if (set.count > 0) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Bus is equal to connected bus. sourceNode(%@) / "
                                                           @"sourceBus(%@) / destinationNode(%@) / destinationBus(%@)",
                                                           __PRETTY_FUNCTION__, sourceNode, sourceBus, destinationNode,
                                                           destinationBus]));
            return nil;
        }
    }
#endif

    YASAudioConnection *connection = [[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                                          sourceBus:sourceBus
                                                                    destinationNode:destinationNode
                                                                     destinationBus:destinationBus
                                                                             format:format];
    [_connections addObject:connection];
    YASRelease(connection);

    if (_graph) {
        [self _addConnection:connection];
        [self _updateNodeConnections:sourceNode];
        [self _updateNodeConnections:destinationNode];
    }

    return connection;
}

- (YASAudioConnection *)connectFromNode:(YASAudioNode *)sourceNode
                                 toNode:(YASAudioNode *)destinationNode
                                 format:(YASAudioFormat *)format
{
    if (!sourceNode || !destinationNode || !format) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return nil;
    }
    NSNumber *sourceBus = sourceNode.nextAvailableOutputBus;
    NSNumber *destinationBus = destinationNode.nextAvailableInputBus;

    if (!sourceBus || !destinationBus) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Bus in not available.", __PRETTY_FUNCTION__]));
        return nil;
    }

    return
        [self connectFromNode:sourceNode toNode:destinationNode fromBus:sourceBus toBus:destinationBus format:format];
}

- (void)disconnect:(YASAudioConnection *)connection
{
    NSArray *updateNodes = @[connection.sourceNode, connection.destinationNode];

    [self _removeConnectionFromNodes:connection];
    [connection removeNodes];

    for (YASAudioNode *node in updateNodes) {
        [node updateConnections];
        [self _detachNodeIfUnused:node];
    }

    [_connections removeObject:connection];
}

- (void)disconnectNode:(YASAudioNode *)node
{
    [self _detachNode:node];
}

- (void)disconnectNodeInput:(YASAudioNode *)node bus:(NSNumber *)bus
{
    if (!node || !bus) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }

    [self _disconnectNodeWithPredicate:[[self.class _destinationNodeAndBusPredicateTemplate]
                                           predicateWithSubstitutionVariables:@{
                                               @"destinationNode": node,
                                               @"destinationBus": bus
                                           }]];
}

- (void)disconnectNodeInput:(YASAudioNode *)node
{
    if (!node) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }

    [self _disconnectNodeWithPredicate:[[self.class _destinationNodePredicateTemplate]
                                           predicateWithSubstitutionVariables:@{
                                               @"destinationNode": node
                                           }]];
}

- (void)disconnectNodeOutput:(YASAudioNode *)node bus:(NSNumber *)bus
{
    if (!node || !bus) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }

    [self _disconnectNodeWithPredicate:[[self.class _sourceNodeAndBusPredicateTemplate]
                                           predicateWithSubstitutionVariables:@{
                                               @"sourceNode": node,
                                               @"sourceBus": bus
                                           }]];
}

- (void)disconnectNodeOutput:(YASAudioNode *)node
{
    if (!node) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }

    [self _disconnectNodeWithPredicate:[[self.class _sourceNodePredicateTemplate] predicateWithSubstitutionVariables:@{
        @"sourceNode": node
    }]];
}

- (BOOL)startRender:(NSError **)outError
{
    if (_graph.isRunning || _offlineOutputNode.isRunning) {
        if (outError) {
            *outError = [NSError yas_errorWithCode:YASAudioEngineErrorCodeAlreadyRunning];
        }
        return NO;
    }

    if (![self _prepare]) {
        if (outError) {
            *outError = [NSError yas_errorWithCode:YASAudioEngineErrorCodePrepareFailure];
        }
        return NO;
    }

    _graph.running = YES;

    return YES;
}

- (BOOL)startOfflineRenderWithOutputCallbackBlock:(YASAudioOfflineRenderCallbackBlock)outputCallbackBlock
                                  completionBlock:(YASAudioOfflineRenderCompletionBlock)completionBlock
                                            error:(NSError **)outError
{
    if (_graph.isRunning || _offlineOutputNode.isRunning) {
        if (outError) {
            *outError = [NSError yas_errorWithCode:YASAudioEngineErrorCodeAlreadyRunning];
        }
        return NO;
    }

    if (![self _prepare]) {
        if (outError) {
            *outError = [NSError yas_errorWithCode:YASAudioEngineErrorCodePrepareFailure];
        }
        return NO;
    }

    return [_offlineOutputNode startWithOutputCallbackBlock:outputCallbackBlock
                                            completionBlock:completionBlock
                                                      error:outError];
}

- (void)stop
{
    _graph.running = NO;
    [_offlineOutputNode stop];
}

#pragma mark Private

- (BOOL)_prepare
{
    if (_graph) {
        return YES;
    }

    _graph = [[YASAudioGraph alloc] init];

    for (YASAudioNode *node in _nodes) {
        [self _addNodeToGraph:node];
    }

    for (YASAudioConnection *connection in _connections) {
        if (![self _addConnection:connection]) {
            return NO;
        }
    }

    [self _updateAllNodeConnections];

    return YES;
}

- (void)_disconnectNodeWithPredicate:(NSPredicate *)predicate
{
    @autoreleasepool
    {
        NSSet *removeConnections = [_connections filteredSetUsingPredicate:predicate];
        NSMutableSet *updateNodes = [[NSMutableSet alloc] initWithCapacity:removeConnections.count * 2];
        for (YASAudioConnection *connection in removeConnections) {
            @autoreleasepool
            {
                [updateNodes addObject:connection.sourceNode];
                [updateNodes addObject:connection.destinationNode];
                [self _removeConnectionFromNodes:connection];
                [connection removeNodes];
            }
        }
        for (YASAudioNode *node in updateNodes) {
            [node updateConnections];
            [self _detachNodeIfUnused:node];
        }
        YASRelease(updateNodes);
        [_connections minusSet:removeConnections];
    }
}

- (void)_addNodeToGraph:(YASAudioNode *)node
{
    if (!_graph) {
        return;
    }

    if ([node isKindOfClass:[YASAudioUnitNode class]]) {
        YASAudioUnitNode *audioUnitNode = (YASAudioUnitNode *)node;
        [audioUnitNode addAudioUnitToGraph:_graph];
    }

#if (!TARGET_OS_IPHONE & TARGET_OS_MAC)
    if ([node isKindOfClass:[YASAudioDeviceIONode class]]) {
        YASAudioDeviceIONode *audioDeviceIONode = (YASAudioDeviceIONode *)node;
        [audioDeviceIONode addAudioDeviceIOToGraph:_graph];
    }
#endif

    if ([node isKindOfClass:[YASAudioOfflineOutputNode class]]) {
        if (_offlineOutputNode) {
            YASRaiseWithReason(
                ([NSString stringWithFormat:@"%s - OfflineOutputNode is already attached.", __PRETTY_FUNCTION__]));
        } else {
            _offlineOutputNode = (YASAudioOfflineOutputNode *)YASRetain(node);
        }
    }
}

- (void)_removeNodeFromGraph:(YASAudioNode *)node
{
    if (!_graph) {
        return;
    }

    if ([node isKindOfClass:[YASAudioUnitNode class]]) {
        YASAudioUnitNode *audioUnitNode = (YASAudioUnitNode *)node;
        [audioUnitNode removeAudioUnitFromGraph];
    }

#if (!TARGET_OS_IPHONE & TARGET_OS_MAC)
    if ([node isKindOfClass:[YASAudioDeviceIO class]]) {
        YASAudioDeviceIONode *audioDeviceIONode = (YASAudioDeviceIONode *)node;
        [audioDeviceIONode removeAudioDeviceIOFromGraph];
    }
#endif

    if ([node isKindOfClass:[YASAudioOfflineOutputNode class]]) {
        if ([_offlineOutputNode isEqual:node]) {
            self.offlineOutputNode = nil;
        }
    }
}

- (BOOL)_addConnection:(YASAudioConnection *)connection
{
    if (!connection) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return NO;
    }

    @autoreleasepool
    {
        YASAudioNode *destinationNode = connection.destinationNode;
        YASAudioNode *sourceNode = connection.sourceNode;

        if (![_nodes containsObject:sourceNode] || ![_nodes containsObject:destinationNode]) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Node is not attached.", __PRETTY_FUNCTION__]));
            return NO;
        }

        [destinationNode addConnection:connection];
        [sourceNode addConnection:connection];
    }

    return YES;
}

- (void)_removeConnectionFromNodes:(YASAudioConnection *)connection
{
    if (!connection) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }

    @autoreleasepool
    {
        YASAudioNode *sourceNode = connection.sourceNode;
        YASAudioNode *destinationNode = connection.destinationNode;
        if (sourceNode) {
            [sourceNode removeConnection:connection];
        }
        if (destinationNode) {
            [destinationNode removeConnection:connection];
        }
    }
}

- (void)_updateNodeConnections:(YASAudioNode *)node
{
    if (!_graph) {
        return;
    }

    [node updateConnections];
}

- (void)_updateAllNodeConnections
{
    if (!_graph) {
        return;
    }

    for (YASAudioNode *node in _nodes) {
        [node updateConnections];
    }
}

- (NSSet *)_inputConnectionsDestinationNode:(YASAudioNode *)node
{
    NSPredicate *predicate = [[self.class _destinationNodePredicateTemplate] predicateWithSubstitutionVariables:@{
        @"destinationNode": node
    }];
    return [_connections filteredSetUsingPredicate:predicate];
}

- (NSSet *)_outputConnectionsSourceNode:(YASAudioNode *)node
{
    NSPredicate *predicate = [[self.class _sourceNodePredicateTemplate] predicateWithSubstitutionVariables:@{
        @"sourceNode": node
    }];
    return [_connections filteredSetUsingPredicate:predicate];
}

+ (NSPredicate *)_destinationNodePredicateTemplate
{
    static NSPredicate *predicate = nil;
    if (!predicate) {
        predicate = YASRetain([NSPredicate predicateWithFormat:@"destinationNode == $destinationNode"]);
    }
    return predicate;
}

+ (NSPredicate *)_destinationNodeAndBusPredicateTemplate
{
    static NSPredicate *predicate = nil;
    if (!predicate) {
        predicate = YASRetain([NSPredicate
            predicateWithFormat:@"destinationNode == $destinationNode && destinationBus == $destinationBus"]);
    }
    return predicate;
}

+ (NSPredicate *)_sourceNodePredicateTemplate
{
    static NSPredicate *predicate = nil;
    if (!predicate) {
        predicate = YASRetain([NSPredicate predicateWithFormat:@"sourceNode == $sourceNode"]);
    }
    return predicate;
}

+ (NSPredicate *)_sourceNodeAndBusPredicateTemplate
{
    static NSPredicate *predicate = nil;
    if (!predicate) {
        predicate =
            YASRetain([NSPredicate predicateWithFormat:@"sourceNode == $sourceNode && sourceBus == $sourceBus"]);
    }
    return predicate;
}

#pragma mark Notification

- (void)audioSessionMediaServicesWereResetNotification:(NSNotification *)notification
{
    if (_graph) {
        BOOL isRunning = _graph.isRunning;
        _graph.running = NO;

        for (YASAudioNode *node in _nodes) {
            [self _removeNodeFromGraph:node];
        }

        self.graph = nil;

        if (![self _prepare]) {
            return;
        }

        if (isRunning) {
            _graph.running = YES;
        }
    }
}

- (void)audioSessionRouteChangeNotification:(NSNotification *)notification
{
    [self sendConfigurationChangeNotification];
}

- (void)sendConfigurationChangeNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:YASAudioEngineConfigurationChangeNotification
                                                        object:self];
}

@end
