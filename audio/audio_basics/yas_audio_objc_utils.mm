//
//  yas_audio_objc_utils.mm
//

#include "yas_audio_objc_utils.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#endif

using namespace yas;

#if TARGET_OS_IPHONE

audio::channel_map_t yas::to_channel_map(NSArray *const channelDescriptions, audio::direction const dir) {
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

AVAudioTime *yas::to_objc_object(audio::time const &time) {
    AudioTimeStamp const time_stamp = time.audio_time_stamp();
    return [AVAudioTime timeWithAudioTimeStamp:&time_stamp sampleRate:time.sample_rate()];
}

audio::time yas::to_time(AVAudioTime *const av_time) {
    AudioTimeStamp const time_stamp = av_time.audioTimeStamp;
    return audio::time(time_stamp, av_time.sampleRate);
}
