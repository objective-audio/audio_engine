//
//  yas_audio_objc_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_time.h"
#import <AVFoundation/AVFoundation.h>

namespace yas {
#if TARGET_OS_IPHONE
audio::channel_map_t to_channel_map(NSArray *const channelDescriptions, const audio::direction dir);
#endif

AVAudioTime *to_objc_object(const audio::time &time);
audio::time to_time(AVAudioTime *const av_time);
}
