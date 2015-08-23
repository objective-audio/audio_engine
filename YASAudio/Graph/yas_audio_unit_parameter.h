//
//  yas_audio_unit_parameter.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <string>
#include <map>
#include <memory>

namespace yas
{
    class audio_unit_parameter;
    using audio_unit_parameter_map = std::map<AudioUnitParameterID, audio_unit_parameter>;

    class audio_unit_parameter
    {
       public:
        audio_unit_parameter(const AudioUnitParameterInfo &info, const AudioUnitParameterID paramter_id,
                             const AudioUnitScope scope);
        ~audio_unit_parameter();

        audio_unit_parameter(audio_unit_parameter &&);
        audio_unit_parameter &operator=(audio_unit_parameter &&);

        AudioUnitParameterID parameter_id() const;
        AudioUnitScope scope() const;
        const std::string &unit_name() const;
        bool has_clump() const;
        uint32_t clump_id() const;
        const std::string &name() const;
        AudioUnitParameterUnit unit() const;
        AudioUnitParameterValue min_value() const;
        AudioUnitParameterValue max_value() const;
        AudioUnitParameterValue default_value() const;

        Float32 value(const AudioUnitElement element) const;
        void set_value(const Float32 value, const AudioUnitElement element);
        const std::map<AudioUnitElement, AudioUnitParameterValue> &values() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        audio_unit_parameter(const audio_unit_parameter &) = delete;
        audio_unit_parameter &operator=(const audio_unit_parameter &) = delete;
    };
}
