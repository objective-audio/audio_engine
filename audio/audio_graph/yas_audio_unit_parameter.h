//
//  yas_audio_unit_parameter.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include "yas_base.h"
#include "yas_observing.h"

namespace yas {
namespace audio {
    class unit::parameter : public base {
       public:
        class impl;

        struct change_info {
            parameter const &parameter;
            AudioUnitElement const element;
            AudioUnitParameterValue const old_value;
            AudioUnitParameterValue const new_value;
        };

        static auto constexpr will_change_key = "yas.audio.audio_unit.parameter.will_change";
        static auto constexpr did_change_key = "yas.audio.audio_unit.parameter.did_change";

        parameter(AudioUnitParameterInfo const &info, AudioUnitParameterID const paramter_id,
                  AudioUnitScope const scope);
        parameter(std::nullptr_t);

        AudioUnitParameterID parameter_id() const;
        AudioUnitScope scope() const;
        CFStringRef unit_name() const;
        bool has_clump() const;
        uint32_t clump_id() const;
        CFStringRef name() const;
        AudioUnitParameterUnit unit() const;
        AudioUnitParameterValue min_value() const;
        AudioUnitParameterValue max_value() const;
        AudioUnitParameterValue default_value() const;

        float value(AudioUnitElement const element) const;
        void set_value(float const value, AudioUnitElement const element);
        std::unordered_map<AudioUnitElement, AudioUnitParameterValue> const &values() const;

        yas::subject<change_info> &subject();
    };
}
}
