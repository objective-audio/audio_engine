//
//  YASAudioEngine.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASWeakSupport.h"
#import "YASAudioTypes.h"

extern NSString *const YASAudioEngineConfigurationChangeNotification;

@class YASAudioNode, YASAudioFormat, YASAudioConnection;

@interface YASAudioEngine : YASWeakProvider

- (YASAudioConnection *)connectFromNode:(YASAudioNode *)sourceNode
                                 toNode:(YASAudioNode *)destinationNode
                                 format:(YASAudioFormat *)format;
- (YASAudioConnection *)connectFromNode:(YASAudioNode *)sourceNode
                                 toNode:(YASAudioNode *)destinationNode
                                fromBus:(NSNumber *)sourceBus
                                  toBus:(NSNumber *)destinationBus
                                 format:(YASAudioFormat *)format;

- (void)disconnect:(YASAudioConnection *)connection;
- (void)disconnectNode:(YASAudioNode *)node;
- (void)disconnectNodeInput:(YASAudioNode *)node bus:(NSNumber *)bus;
- (void)disconnectNodeInput:(YASAudioNode *)node;
- (void)disconnectNodeOutput:(YASAudioNode *)node bus:(NSNumber *)bus;
- (void)disconnectNodeOutput:(YASAudioNode *)node;

- (BOOL)startRender:(NSError **)outError;
- (BOOL)startOfflineRenderWithOutputCallbackBlock:(YASAudioOfflineRenderCallbackBlock)outputCallbackBlock
                                  completionBlock:(YASAudioOfflineRenderCompletionBlock)completionBlock
                                            error:(NSError **)outError;
- (void)stop;

@end
