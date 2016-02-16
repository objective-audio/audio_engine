//
//  yas_audio_objc_utils.h
//

#pragma once

#import <AVFoundation/AVFoundation.h>
#include "yas_audio_time.h"
#include "yas_audio_types.h"

namespace yas {
#if TARGET_OS_IPHONE
audio::channel_map_t to_channel_map(NSArray *const channelDescriptions, audio::direction const dir);
#endif

AVAudioTime *to_objc_object(audio::time const &time);
audio::time to_time(AVAudioTime *const av_time);
}
