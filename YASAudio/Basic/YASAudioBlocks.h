//
//  YASAudioBlocks.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#ifndef YASAudio_Tests_YASAudioBlocks_h
#define YASAudio_Tests_YASAudioBlocks_h

#include "YASAudioTypes.h"

@class YASAudioData, YASAudioTime;

typedef void (^YASAudioUnitCallbackBlock)(YASAudioUnitRenderParameters *renderParameters);
typedef void (^YASAudioDeviceIOCallbackBlock)(YASAudioData *outData, YASAudioTime *when);
typedef void (^YASAudioNodeRenderBlock)(YASAudioData *data, NSNumber *bus, YASAudioTime *when);
typedef void (^YASAudioOfflineRenderCallbackBlock)(YASAudioData *data, YASAudioTime *when, BOOL *stop);
typedef void (^YASAudioOfflineRenderCompletionBlock)(BOOL cancelled);

#endif
