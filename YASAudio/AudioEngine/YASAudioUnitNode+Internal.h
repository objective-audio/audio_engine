//
//  YASAudioUnitNode+Internal.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitNode.h"

@interface YASAudioUnitNode (Internal)

- (void)addAudioUnitToGraph:(YASAudioGraph *)graph;
- (void)removeAudioUnitFromGraph;

@end
