//
//  YASAudioTapNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioNode.h"
#import "YASAudioBlocks.h"

@class YASAudioConnection;

@interface YASAudioTapNode : YASAudioNode

@property (atomic, copy) YASAudioNodeRenderBlock renderBlock;

#pragma mark Render thread

- (YASAudioConnection *)inputConnectionOnRenderForBus:(NSNumber *)bus;
- (YASAudioConnection *)outputConnectionOnRenderForBus:(NSNumber *)bus;
- (NSDictionary *)inputConnectionsOnRender;
- (NSDictionary *)outputConnectionsOnRender;
- (void)renderSourceNodeWithData:(YASAudioData *)data bus:(NSNumber *)bus when:(YASAudioTime *)when;

@end

@interface YASAudioInputTapNode : YASAudioTapNode

@end
