//
//  yas_objc_utils.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_objc_utils.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#endif

using namespace yas;

#if TARGET_OS_IPHONE

channel_map_t yas::to_channel_map(const NSArray *channelAssignments, const AudioUnitScope scope)
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *routeDesc = audioSession.currentRoute;

    NSInteger channel_count = 0;
    NSArray *portDescriptions = nil;

    if (scope == kAudioUnitScope_Input) {
        channel_count = audioSession.inputNumberOfChannels;
        portDescriptions = routeDesc.inputs;
    } else if (scope == kAudioUnitScope_Output) {
        channel_count = audioSession.outputNumberOfChannels;
        portDescriptions = routeDesc.outputs;
    } else {
        std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : out of scope. scope(" + yas::to_string(scope) +
                              ")");
    }

    if (channel_count == 0) {
        return channel_map_t();
    }

    channel_map_t map;
    map.reserve(channel_count);

    for (AVAudioSessionPortDescription *portDescription in portDescriptions) {
        for (AVAudioSessionChannelDescription *channelDescription in portDescription.channels) {
            UInt32 idx = 0;
            UInt32 assign_idx = -1;

            for (AVAudioSessionChannelDescription *assignChannelDescription in channelAssignments) {
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
