//
//  YASAudioTapNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioNode.h"
#import "YASAudioTypes.h"

@interface YASAudioTapNode : YASAudioNode

@property (atomic, copy) YASAudioNodeRenderBlock renderBlock;

@end

@interface YASAudioInputTapNode : YASAudioTapNode

@end
