//
//  YASAudioNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASWeakSupport.h"
#import <AudioUnit/AudioUnit.h>

@class YASAudioFormat, YASAudioData, YASAudioTime, YASAudioEngine, YASAudioUnit, YASAudioConnection;

@interface YASAudioNodeCore : NSObject

- (YASAudioConnection *)inputConnectionForBus:(NSNumber *)bus;
- (YASAudioConnection *)outputConnectionForBus:(NSNumber *)bus;
- (NSDictionary *)inputConnections;
- (NSDictionary *)outputConnections;

@end

@interface YASAudioNode : YASWeakProvider

- (void)reset;

- (YASAudioFormat *)inputFormatForBus:(NSNumber *)bus;
- (YASAudioFormat *)outputFormatForBus:(NSNumber *)bus;
- (NSNumber *)nextAvailableInputBus;
- (NSNumber *)nextAvailableOutputBus;
- (BOOL)isAvailableInputBus:(NSNumber *)bus;
- (BOOL)isAvailableOutputBus:(NSNumber *)bus;
- (YASAudioEngine *)engine;
- (YASAudioTime *)lastRenderTime;

#pragma mark - Override by Subclass

- (UInt32)inputBusCount;
- (UInt32)outputBusCount;

#pragma mark Render thread

- (void)renderWithData:(YASAudioData *)data bus:(NSNumber *)bus when:(YASAudioTime *)when;

@end

@interface YASAudioNode (YASInternal)

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

- (void)setRenderTimeOnRender:(YASAudioTime *)time;

@end
