//
//  YASAudioNode+Internal.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioNode.h"

@class YASAudioConnection;

@interface YASAudioNode (Internal)

- (void)setEngine:(YASAudioEngine *)engine;
- (void)addConnection:(YASAudioConnection *)connection;
- (void)removeConnection:(YASAudioConnection *)connection;
- (YASAudioConnection *)inputConnectionForBus:(NSNumber *)bus;
- (YASAudioConnection *)outputConnectionForBus:(NSNumber *)bus;
- (NSDictionary *)inputConnections;
- (NSDictionary *)outputConnections;

- (void)updateNodeCore;

#pragma mark - Override by Subclass

- (void)updateConnections;
- (Class)nodeCoreClass;
- (id)newNodeCoreObject NS_REQUIRES_SUPER;

#pragma mark Render thread

@property (atomic, strong, readonly) id nodeCore;

- (void)setRenderTimeOnRender:(AVAudioTime *)time;

@end

@interface YASAudioNodeCore : NSObject

- (YASAudioConnection *)inputConnectionForBus:(NSNumber *)bus;
- (YASAudioConnection *)outputConnectionForBus:(NSNumber *)bus;
- (NSDictionary *)inputConnections;
- (NSDictionary *)outputConnections;

@end
