//
//  yas_audio_unit_parameter.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include "yas_base.h"

namespace yas {
template <typename T, typename K>
class subject;

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

        enum class method { will_change, did_change };

        using subject_t = subject<change_info, method>;

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

        subject_t &subject();
    };
}
std::string to_string(audio::unit::parameter::method const &);
}
