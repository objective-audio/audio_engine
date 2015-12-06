//
//  yas_audio_unit_parameter.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_observing.h"
#include <AudioToolbox/AudioToolbox.h>

class yas::audio::unit::parameter
{
   public:
    struct change_info {
        const parameter &parameter;
        const AudioUnitElement element;
        const AudioUnitParameterValue old_value;
        const AudioUnitParameterValue new_value;
    };

    constexpr static auto will_change_key = "yas.audio.audio_unit.parameter.will_change";
    constexpr static auto did_change_key = "yas.audio.audio_unit.parameter.did_change";

    parameter(const AudioUnitParameterInfo &info, const AudioUnitParameterID paramter_id, const AudioUnitScope scope);
    ~parameter();

    parameter(parameter &&);
    parameter &operator=(parameter &&);

    AudioUnitParameterID parameter_id() const;
    AudioUnitScope scope() const;
    CFStringRef unit_name() const;
    bool has_clump() const;
    UInt32 clump_id() const;
    CFStringRef name() const;
    AudioUnitParameterUnit unit() const;
    AudioUnitParameterValue min_value() const;
    AudioUnitParameterValue max_value() const;
    AudioUnitParameterValue default_value() const;

    Float32 value(const AudioUnitElement element) const;
    void set_value(const Float32 value, const AudioUnitElement element);
    const std::unordered_map<AudioUnitElement, AudioUnitParameterValue> &values() const;

    yas::subject<change_info> &subject();

   private:
    class impl;
    std::unique_ptr<impl> _impl;

    parameter(const parameter &) = delete;
    parameter &operator=(const parameter &) = delete;
};
