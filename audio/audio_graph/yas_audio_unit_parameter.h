//
//  yas_audio_unit_parameter.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include "yas_observing.h"

class yas::audio::unit::parameter {
   public:
    struct change_info {
        parameter const &parameter;
        AudioUnitElement const element;
        AudioUnitParameterValue const old_value;
        AudioUnitParameterValue const new_value;
    };

    static auto constexpr will_change_key = "yas.audio.audio_unit.parameter.will_change";
    static auto constexpr did_change_key = "yas.audio.audio_unit.parameter.did_change";

    parameter(AudioUnitParameterInfo const &info, AudioUnitParameterID const paramter_id, AudioUnitScope const scope);
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

    Float32 value(AudioUnitElement const element) const;
    void set_value(Float32 const value, AudioUnitElement const element);
    std::unordered_map<AudioUnitElement, AudioUnitParameterValue> const &values() const;

    yas::subject<change_info> &subject();

   private:
    class impl;
    std::unique_ptr<impl> _impl;

    parameter(parameter const &) = delete;
    parameter &operator=(parameter const &) = delete;
};
