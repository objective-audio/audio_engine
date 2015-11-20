//
//  yas_audio_unit_parameter.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_observing.h"
#include <AudioToolbox/AudioToolbox.h>
#include <string>
#include <unordered_map>
#include <memory>

namespace yas
{
    class audio_unit_parameter;
    using audio_unit_parameter_map_t = std::unordered_map<AudioUnitParameterID, audio_unit_parameter>;

    class audio_unit_parameter
    {
       public:
        struct change_info {
            const audio_unit_parameter &parameter;
            const AudioUnitElement element;
            const AudioUnitParameterValue old_value;
            const AudioUnitParameterValue new_value;
        };

        constexpr static auto will_change_key = "yas.audio_unit_parameter.will_change";
        constexpr static auto did_change_key = "yas.audio_unit_parameter.did_change";

        audio_unit_parameter(const AudioUnitParameterInfo &info, const AudioUnitParameterID paramter_id,
                             const AudioUnitScope scope);
        ~audio_unit_parameter();

        audio_unit_parameter(audio_unit_parameter &&);
        audio_unit_parameter &operator=(audio_unit_parameter &&);

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

        subject<change_info> &subject();

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        audio_unit_parameter(const audio_unit_parameter &) = delete;
        audio_unit_parameter &operator=(const audio_unit_parameter &) = delete;
    };
}
