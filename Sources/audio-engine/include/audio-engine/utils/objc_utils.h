//
//  objc_utils.h
//

#pragma once

#import <AVFoundation/AVFoundation.h>
#include <audio-engine/common/types.h>
#include <cpp-utils/objc_ptr.h>

namespace yas::audio {
class time;
class format;
}  // namespace yas::audio

namespace yas {
#if TARGET_OS_IPHONE
audio::channel_map_t to_channel_map(NSArray *const channelDescriptions, audio::direction const dir);
#endif

AVAudioCommonFormat to_common_format(audio::pcm_format const);
objc_ptr<AVAudioFormat *> to_objc_object(audio::format const &);

objc_ptr<AVAudioTime *> to_objc_object(audio::time const &time);
audio::time to_time(AVAudioTime *const av_time);
}  // namespace yas
