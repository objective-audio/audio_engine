//
//  YASAudioBlocks.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "YASAudioTypes.h"

@class YASAudioData, AVAudioTime;

typedef void (^YASAudioUnitCallbackBlock)(YASAudioUnitRenderParameters *renderParameters);
typedef void (^YASAudioDeviceIOCallbackBlock)(YASAudioData *outData, AVAudioTime *when);
typedef void (^YASAudioNodeRenderBlock)(YASAudioData *data, NSNumber *bus, AVAudioTime *when);
typedef void (^YASAudioOfflineRenderCallbackBlock)(YASAudioData *data, AVAudioTime *when, BOOL *stop);
typedef void (^YASAudioOfflineRenderCompletionBlock)(BOOL cancelled);
