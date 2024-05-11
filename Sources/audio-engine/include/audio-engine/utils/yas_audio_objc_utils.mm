//
//  yas_audio_objc_utils.mm
//

#include "yas_audio_objc_utils.h"

#include <audio-engine/common/yas_audio_time.h>
#include <audio-engine/format/yas_audio_format.h>

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#endif

using namespace yas;
using namespace yas::audio;

#if TARGET_OS_IPHONE

channel_map_t yas::to_channel_map(NSArray *const channelDescriptions, direction const dir) {
    AVAudioSession *const audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *const routeDesc = audioSession.currentRoute;

    NSInteger channel_count = 0;
    NSArray *portDescriptions = nil;

    if (dir == direction::input) {
        channel_count = audioSession.inputNumberOfChannels;
        portDescriptions = routeDesc.inputs;
    } else {
        channel_count = audioSession.outputNumberOfChannels;
        portDescriptions = routeDesc.outputs;
    }

    if (channel_count == 0) {
        return channel_map_t();
    }

    channel_map_t map;
    map.reserve(channel_count);

    for (AVAudioSessionPortDescription *portDescription in portDescriptions) {
        for (AVAudioSessionChannelDescription *channelDescription in portDescription.channels) {
            uint32_t idx = 0;
            uint32_t assign_idx = -1;

            for (AVAudioSessionChannelDescription *assignChannelDescription in channelDescriptions) {
                if ([assignChannelDescription.owningPortUID isEqualToString:portDescription.UID] &&
                    assignChannelDescription.channelNumber == channelDescription.channelNumber) {
                    assign_idx = idx;
                    break;
                }
                idx++;
            }

            map.push_back(assign_idx);
        }
    }

    return map;
}

#endif

AVAudioCommonFormat yas::to_common_format(pcm_format const pcm_format) {
    switch (pcm_format) {
        case pcm_format::float64:
            return AVAudioPCMFormatFloat64;
        case pcm_format::float32:
            return AVAudioPCMFormatFloat32;
        case pcm_format::fixed824:
            return AVAudioPCMFormatInt32;
        case pcm_format::int16:
            return AVAudioPCMFormatInt16;
        case pcm_format::other:
            return AVAudioOtherFormat;
    }
}

objc_ptr<AVAudioFormat *> yas::to_objc_object(format const &format) {
    if (format.channel_count() <= 2) {
        return objc_ptr_with_move_object(
            [[AVAudioFormat alloc] initWithStreamDescription:&format.stream_description()]);
    } else {
        auto const objc_channel_layout =
            objc_ptr_with_move_object([[AVAudioChannelLayout alloc] initWithLayoutTag:format.channel_count()]);
        return objc_ptr_with_move_object([[AVAudioFormat alloc]
            initWithCommonFormat:to_common_format(format.pcm_format())
                      sampleRate:format.sample_rate()
                     interleaved:format.is_interleaved()
                   channelLayout:objc_channel_layout.object()]);
    }
}

objc_ptr<AVAudioTime *> yas::to_objc_object(audio::time const &time) {
    AudioTimeStamp const time_stamp = time.audio_time_stamp();
    return objc_ptr_with_move_object([[AVAudioTime alloc] initWithAudioTimeStamp:&time_stamp
                                                                      sampleRate:time.sample_rate()]);
}

audio::time yas::to_time(AVAudioTime *const av_time) {
    AudioTimeStamp const time_stamp = av_time.audioTimeStamp;
    return audio::time(time_stamp, av_time.sampleRate);
}
