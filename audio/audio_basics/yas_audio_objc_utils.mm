//
//  yas_audio_objc_utils.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_objc_utils.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#endif

using namespace yas;

#if TARGET_OS_IPHONE

audio::channel_map_t yas::to_channel_map(NSArray *const channelDescriptions, const audio::direction dir) {
    AVAudioSession *const audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *const routeDesc = audioSession.currentRoute;

    NSInteger channel_count = 0;
    NSArray *portDescriptions = nil;

    if (dir == audio::direction::input) {
        channel_count = audioSession.inputNumberOfChannels;
        portDescriptions = routeDesc.inputs;
    } else {
        channel_count = audioSession.outputNumberOfChannels;
        portDescriptions = routeDesc.outputs;
    }

    if (channel_count == 0) {
        return audio::channel_map_t();
    }

    audio::channel_map_t map;
    map.reserve(channel_count);

    for (AVAudioSessionPortDescription *portDescription in portDescriptions) {
        for (AVAudioSessionChannelDescription *channelDescription in portDescription.channels) {
            UInt32 idx = 0;
            UInt32 assign_idx = -1;

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

AVAudioTime *yas::to_objc_object(const audio::time &time) {
    const AudioTimeStamp time_stamp = time.audio_time_stamp();
    return [AVAudioTime timeWithAudioTimeStamp:&time_stamp sampleRate:time.sample_rate()];
}

audio::time yas::to_time(AVAudioTime *const av_time) {
    const AudioTimeStamp time_stamp = av_time.audioTimeStamp;
    return audio::time(time_stamp, av_time.sampleRate);
}