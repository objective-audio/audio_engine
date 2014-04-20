
//
// YASAudioGraph.m
//
// Created by Yuki Yasoshima
//

#import "YASAudioGraph.h"
#import "YASAudioNodeRenderInfo.h"
#import "YASAudioConnection.h"
#import "YASAudioMacros.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

static NSMutableDictionary *g_graphs = nil;
static NSLock *g_graphRenderLock = nil;
static NSMutableDictionary *g_renderInfos = nil;
static BOOL g_interrupting = NO;

@interface YASAudioGraph()
@property (nonatomic, strong) YASAudioIONode *ioNode;
@property (nonatomic, strong) NSMutableDictionary *nodes;
@property (nonatomic, strong) NSMutableSet *connections;
@end

@implementation YASAudioGraph

#pragma mark - グローバル／グラフのオブジェクト管理

+ (NSString *)_uniqueString
{
    NSString *result = nil;
    
    while (YES) {
        
        result = [[NSProcessInfo processInfo] globallyUniqueString];
        
        if (![g_graphs objectForKey:result]) {
            break;
        }
        
    }
    
    return result;
}

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        g_graphs = [[NSMutableDictionary alloc] initWithCapacity:2];
        
        g_graphRenderLock = [[NSLock alloc] init];
        
        g_renderInfos = [[NSMutableDictionary alloc] initWithCapacity:2];
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_didBecomeActiveNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:@selector(_interruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
        
    });
}

+ (void)_startAllAudioGraph
{
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
    }
    
    for (YASAudioGraph *graph in g_graphs.allValues) {
        if (graph.running) [graph _startGraph];
    }
    
    g_interrupting = NO;
}

+ (void)_stopAllAudioGraph
{
    for (YASAudioGraph *graph in g_graphs.allValues) {
        [graph _stopGraph];
    }
    
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setActive:NO error:&error]) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
    }
}

+ (void)_addGraph:(YASAudioGraph *)graph
{
    if (graph) {
        
        [g_graphRenderLock lock];
        
        [g_graphs setObject:graph forKey:graph.identifier];
        
        [g_graphRenderLock unlock];
    }
}

+ (void)_removeGraph:(YASAudioGraph *)graph
{
    [g_graphRenderLock lock];
    
    if (graph) {
        [g_graphs removeObjectForKey:graph.identifier];
    }
    
    [g_graphRenderLock unlock];
}

+ (YASAudioGraph *)_graphForKey:(NSString *)key
{
    YASAudioGraph *graph = nil;
    
    [g_graphRenderLock lock];
    
    graph = [g_graphs objectForKey:key];
    YASAudioRetain(graph)
    YASAudioAutorelease(graph);
    
    [g_graphRenderLock unlock];
    
    return graph;
}

#pragma mark - AudioSessionの通知

+ (void)_didBecomeActiveNotification:(NSNotification *)notif
{
    [self _startAllAudioGraph];
}

+ (void)_interruptionNotification:(NSNotification *)notif
{
    NSDictionary *info = notif.userInfo;
    NSNumber *typeNum = [info valueForKey:AVAudioSessionInterruptionTypeKey];
    AVAudioSessionInterruptionType interruptionType = [typeNum unsignedIntegerValue];
    
    if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
        g_interrupting = YES;
        [self _stopAllAudioGraph];
    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            [self _startAllAudioGraph];
            g_interrupting = NO;
        }
    }
}

#pragma mark - グローバル／レンダー

+ (BOOL)containsAudioNodeRenderInfoWithGraphKey:(NSString *)graphKey nodeKey:(NSString *)nodeKey
{
    NSMutableDictionary *graphInfos = [g_renderInfos objectForKey:graphKey];
    
    if (!graphInfos) {
        return NO;
    }
    
    YASAudioNodeRenderInfo *renderInfo = [graphInfos objectForKey:nodeKey];
    
    if (!renderInfo) {
        return NO;
    }
    
    return YES;
}

+ (YASAudioNodeRenderInfo *)audioNodeRenderInfoWithGraphKey:(NSString *)graphKey nodeKey:(NSString *)nodeKey
{
    NSMutableDictionary *graphInfos = [g_renderInfos objectForKey:graphKey];
    
    if (!graphInfos) {
        graphInfos = [NSMutableDictionary dictionaryWithCapacity:8];
        [g_renderInfos setObject:graphInfos forKey:graphKey];
    }
    
    YASAudioNodeRenderInfo *renderInfo = [graphInfos objectForKey:nodeKey];
    
    if (!renderInfo) {
        renderInfo = [[YASAudioNodeRenderInfo alloc] initWithGraphKey:graphKey nodeKey:nodeKey];
        [graphInfos setObject:renderInfo forKey:nodeKey];
        YASAudioRelease(renderInfo);
    }
    
    return renderInfo;
}

+ (void)audioNodeRender:(YASAudioNodeRenderInfo *)renderInfo
{
    YASAudioGraph *graph = [YASAudioGraph _graphForKey:renderInfo.graphKey];
    
    if (graph) {
        
        YASAudioNode *node = [graph nodeForKey:renderInfo.nodeKey];
        
        if (node) {
            [node render:renderInfo];
        }
        
    }
}

#pragma mark - セットアップ

- (BOOL)_setupAUGraph
{
    OSStatus err = noErr;
    
    err = NewAUGraph(&_auGraph);
    YAS_Require_NoErr(err, bail);
    
    err = [self _openGraph];
    YAS_Require_NoErr(err, bail);
    
    _ioNode = [self _addIONode];
    YASAudioRetain(_ioNode);
    
bail:
    if (err) {
        if (_auGraph) {
            [self _closeGraph];
            DisposeAUGraph(_auGraph);
        }
        return NO;
    }
    return YES;
}

+ (id)graph
{
    id graph = [[[self class] alloc] init];
    YASAudioAutorelease(graph);
    return graph;
}

- (id)init
{
    self = [super init];
    if (self) {
        
        _nodes = [[NSMutableDictionary alloc] init];
        _connections = [[NSMutableSet alloc] init];
        _running = NO;
        
        _identifier = [YASAudioGraph _uniqueString];
        YASAudioRetain(_identifier);
        
        if (![self _setupAUGraph]) {
            YASAudioRelease(self);
            self = nil;
        } else {
            [YASAudioGraph _addGraph:self];
        }
    }
    
    return self;
}

- (void)dealloc
{
    [self _uninitializeGraph];
    
    [self removeAllNodes];
    
    OSStatus err = noErr;
    err = DisposeAUGraph(_auGraph);
    YAS_Require_NoErr(err, bail);
    
bail:
    
    _auGraph = 0;
    
    YASAudioRelease(_identifier);
    YASAudioRelease(_nodes);
    YASAudioRelease(_connections);
    YASAudioRelease(_ioNode);
    YASAudioSuperDealloc;
}

- (void)invalidate
{
    [self _stopGraph];
    
    [YASAudioGraph _removeGraph:self];
}

#pragma mark - 更新

- (void)_updateAUGraphRunning
{
    if (_running) {
        [self _startGraph];
    } else {
        [self _stopGraph];
    }
}

#pragma mark - アクセサ

- (void)setRunning:(BOOL)running
{
    if (_running != running) {
        _running = running;
        [self _updateAUGraphRunning];
    }
}

#pragma mark - ノード

- (YASAudioNode *)_nodeForKeyFromNodesSynchronized:(id)key
{
    YASAudioNode *node = nil;
    
    @synchronized(self) {
        node = [_nodes objectForKey:key];
        YASAudioRetain(node);
        YASAudioAutorelease(node);
    }
    
    return node;
}

- (void)_setNodeToNodesSynchronized:(YASAudioNode *)node
{
    @synchronized(self) {
        [_nodes setObject:node forKey:node.identifier];
    }
}

- (void)_removeNodeFromNodesSynchronized:(YASAudioNode *)node
{
    @synchronized(self) {
        [_nodes removeObjectForKey:node.identifier];
    }
}

- (YASAudioNode *)addNodeWithType:(OSType)type subType:(OSType)subType
{
    AudioComponentDescription acd;
    acd.componentType = type;
    acd.componentSubType = subType;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    
    YASAudioNode *newNode = [[YASAudioNode alloc] initWithGraph:self acd:&acd];
    [self _setNodeToNodesSynchronized:newNode];
    YASAudioRelease(newNode);
    
    return newNode;
}

- (YASAudioIONode *)_addIONode
{
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    
    YASAudioIONode *newNode = [[YASAudioIONode alloc] initWithGraph:self acd:&acd];
    [self _setNodeToNodesSynchronized:newNode];
    YASAudioRelease(newNode);
    
    return newNode;
}

- (void)removeNode:(YASAudioNode *)node
{
    NSMutableSet *removeConSet = [[NSMutableSet alloc] init];
    
    for (YASAudioConnection *connection in _connections) {
        if ([node isEqual:connection.sourceNode] || [node isEqual:connection.destNode]) {
            [removeConSet addObject:connection];
        }
    }
    
    for (YASAudioConnection *connection in removeConSet) {
        [_connections removeObject:connection];
    }
    
    YASAudioRelease(removeConSet);
    
    [node remove];
    [self _removeNodeFromNodesSynchronized:node];
}

- (void)removeAllNodes
{
    NSDictionary *tmpSet = nil;
    
    @synchronized(self) {
        tmpSet = [_nodes copy];
    }
    
    for (YASAudioNode *node in tmpSet.allValues) {
        [self removeNode:node];
    }
    
    YASAudioRelease(tmpSet);
}

- (YASAudioNode *)nodeForKey:(NSString *)key
{
    return [self _nodeForKeyFromNodesSynchronized:key];
}

#pragma mark - コネクション

- (YASAudioConnection *)addConnectionWithSourceNode:(YASAudioNode *)sourceNode sourceOutputNumber:(UInt32)sourceOutputNumber destNode:(YASAudioNode *)destNode destInputNumber:(UInt32)destInputNumber
{
    YASAudioConnection *connection = nil;
    
    OSStatus err = noErr;
    
    err = AUGraphConnectNodeInput(_auGraph, sourceNode.node, sourceOutputNumber, destNode.node, destInputNumber);
    YAS_Require_NoErr(err, bail);
    
    connection = [[YASAudioConnection alloc] init];
    connection.sourceNode = sourceNode;
    connection.sourceOutputNumber = sourceOutputNumber;
    connection.destNode = destNode;
    connection.destInputNumber = destInputNumber;
    [_connections addObject:connection];
    YASAudioAutorelease(connection);
    
bail:
    
    return connection;
}

- (void)removeConnection:(YASAudioConnection *)connection
{
    OSStatus err = noErr;
    YASAudioRetain(connection);
    
    err = AUGraphDisconnectNodeInput(_auGraph, connection.destNode.node, connection.destInputNumber);
    YAS_Require_NoErr(err, bail);
    
    [_connections removeObject:connection];
    
bail:
    YASAudioRelease(connection);
}

#pragma mark - グラフ

- (void)update
{
    OSStatus err = AUGraphUpdate(_auGraph, NULL);
    YAS_Verify_NoErr(err);
}

- (OSStatus)_startGraph
{
    OSStatus err = noErr;
    Boolean isInitialized = false;
    
    err = AUGraphIsInitialized(_auGraph, &isInitialized);
    YAS_Verify_NoErr(err);
    
    if (!isInitialized) {
        err = AUGraphInitialize(_auGraph);
        YAS_Verify_NoErr(err);
    }
    
    err = AUGraphStart(_auGraph);
    YAS_Verify_NoErr(err);
    
    return err;
}

- (OSStatus)_stopGraph
{
    OSStatus err = noErr;
    Boolean isRunning = false;
    
    err = AUGraphIsRunning(_auGraph, &isRunning);
    YAS_Verify_NoErr(err);
    
    if (isRunning) {
        err = AUGraphStop(_auGraph);
        YAS_Verify_NoErr(err);
    }
    
    return err;
}

- (void)_uninitializeGraph
{
    OSStatus err = noErr;
    Boolean isInitialized = false;
    
    err = AUGraphIsInitialized(_auGraph, &isInitialized);
    YAS_Verify_NoErr(err);
    
    if (isInitialized) {
        err = AUGraphUninitialize(_auGraph);
        YAS_Verify_NoErr(err);
    }
}

- (OSStatus)_openGraph
{
    OSStatus err = noErr;
    Boolean isOpen = false;
    
    err = AUGraphIsOpen(_auGraph, &isOpen);
    YAS_Verify_NoErr(err);
    
    if (!isOpen) {
        err = AUGraphOpen(_auGraph);
        YAS_Verify_NoErr(err);
    }
    
    return err;
}

- (OSStatus)_closeGraph
{
    OSStatus err = noErr;
    Boolean isOpen = false;
    
    err = AUGraphIsOpen(_auGraph, &isOpen);
    YAS_Verify_NoErr(err);
    
    if (isOpen) {
        err = AUGraphClose(_auGraph);
        YAS_Verify_NoErr(err);
    }
    
    return err;
}

@end
