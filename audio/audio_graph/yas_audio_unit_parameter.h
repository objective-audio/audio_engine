//
//  yas_audio_unit_parameter.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include "yas_base.h"
#include "yas_flow.h"

namespace yas::audio {
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

    using flow_pair_t = std::pair<method, change_info>;

    parameter(AudioUnitParameterInfo const &info, AudioUnitParameterID const paramter_id, AudioUnitScope const scope);
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

    [[nodiscard]] flow::node_t<flow_pair_t, false> begin_flow() const;
    [[nodiscard]] flow::node<change_info, flow_pair_t, flow_pair_t, false> begin_flow(method const) const;
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::unit::parameter::method const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::unit::parameter::method const &);
