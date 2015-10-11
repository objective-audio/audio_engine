//
//  yas_audio_types.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_types.h"
#import <AudioToolbox/AudioToolbox.h>

using namespace yas;

UInt32 yas::to_uint32(const yas::direction &dir)
{
    return static_cast<UInt32>(dir);
}

std::string yas::to_string(const direction &dir)
{
    switch (dir) {
        case direction::output:
            return "output";
        case direction::input:
            return "input";
    }
}

std::string yas::to_string(const AudioUnitScope scope)
{
    switch (scope) {
        case kAudioUnitScope_Global:
            return "global";
        case kAudioUnitScope_Input:
            return "input";
        case kAudioUnitScope_Output:
            return "output";
        case kAudioUnitScope_Group:
            return "group";
        case kAudioUnitScope_Part:
            return "part";
        case kAudioUnitScope_Note:
            return "note";
        case kAudioUnitScope_Layer:
            return "layer";
        case kAudioUnitScope_LayerItem:
            return "layer_item";
    }

    return "unknown";
}

std::string yas::to_string(const render_type &type)
{
    switch (type) {
        case render_type::normal:
            return "normal";
        case render_type::notify:
            return "notify";
        case render_type::input:
            return "notify";
        case render_type::unknown:
            return "unknown";
    }
}
