//
//  yas_objc_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_time.h"
#import <AVFoundation/AVFoundation.h>

namespace yas
{
#if TARGET_OS_IPHONE
    channel_map_t to_channel_map(const NSArray *channelDescriptions, const yas::direction dir);
#endif

    AVAudioTime *to_objc_object(const audio_time &time);
    audio_time to_audio_time(const AVAudioTime *av_time);
}
