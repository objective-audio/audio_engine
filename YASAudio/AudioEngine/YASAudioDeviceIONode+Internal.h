//
//  YASAudioDeviceIONode+Internal.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioDeviceIONode.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

@interface YASAudioDeviceIONode (Internal)

- (void)addAudioDeviceIOToGraph:(YASAudioGraph *)graph;
- (void)removeAudioDeviceIOFromGraph;

@end

#endif
