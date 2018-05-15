//
//  yas_audio_objc_utils.h
//

#pragma once

#import <AVFoundation/AVFoundation.h>
#include "yas_audio_types.h"
#include "yas_objc_ptr.h"

namespace yas::audio {
class time;
}

namespace yas {
#if TARGET_OS_IPHONE
audio::channel_map_t to_channel_map(NSArray *const channelDescriptions, audio::direction const dir);
#endif

objc_ptr<AVAudioTime *> to_objc_object(audio::time const &time);
audio::time to_time(AVAudioTime *const av_time);
}  // namespace yas
