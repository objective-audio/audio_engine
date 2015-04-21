//
//  YASAudioTapNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioNode.h"
#import "YASAudioTypes.h"

@class YASAudioConnection;

@interface YASAudioTapNode : YASAudioNode

@property (atomic, copy) YASAudioNodeRenderBlock renderBlock;

#pragma mark Render thread

- (YASAudioConnection *)inputConnectionOnRenderForBus:(NSNumber *)bus;
- (YASAudioConnection *)outputConnectionOnRenderForBus:(NSNumber *)bus;
- (NSDictionary *)inputConnectionsOnRender;
- (NSDictionary *)outputConnectionsOnRender;

@end

@interface YASAudioInputTapNode : YASAudioTapNode

@end
