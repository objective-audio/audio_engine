//
//  YASAudioBlocks.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "YASAudioTypes.h"

@class YASAudioData, YASAudioTime;

typedef void (^YASAudioUnitCallbackBlock)(YASAudioUnitRenderParameters *renderParameters);
typedef void (^YASAudioDeviceIOCallbackBlock)(YASAudioData *outData, YASAudioTime *when);
typedef void (^YASAudioNodeRenderBlock)(YASAudioData *data, NSNumber *bus, YASAudioTime *when);
typedef void (^YASAudioOfflineRenderCallbackBlock)(YASAudioData *data, YASAudioTime *when, BOOL *stop);
typedef void (^YASAudioOfflineRenderCompletionBlock)(BOOL cancelled);
