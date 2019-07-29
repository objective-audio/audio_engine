//
//  yas_audio_unit_parameter.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <chaining/yas_chaining_umbrella.h>
#include <ostream>

namespace yas::audio {
struct unit::parameter {
    struct change_info {
        parameter const &parameter;
        AudioUnitElement const element;
        AudioUnitParameterValue const old_value;
        AudioUnitParameterValue const new_value;
    };

    enum class method { will_change, did_change };

    using chaining_pair_t = std::pair<method, change_info>;

    parameter(AudioUnitParameterInfo const &info, AudioUnitParameterID const paramter_id, AudioUnitScope const scope);

    AudioUnitParameterID const parameter_id;
    AudioUnitScope const scope;
    bool const has_clump;
    uint32_t const clump_id;
    AudioUnitParameterUnit const unit;
    AudioUnitParameterValue const min_value;
    AudioUnitParameterValue const max_value;
    AudioUnitParameterValue const default_value;

    std::string const unit_name;
    std::string const name;
    CFStringRef cf_unit_name() const;
    CFStringRef cf_name() const;

    float value(AudioUnitElement const element) const;
    void set_value(float const value, AudioUnitElement const element);
    std::unordered_map<AudioUnitElement, AudioUnitParameterValue> const &values() const;

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<change_info, chaining_pair_t> chain(method const) const;

   private:
    std::unordered_map<AudioUnitElement, AudioUnitParameterValue> _values;
    chaining::notifier<chaining_pair_t> _notifier;
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::unit::parameter::method const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::unit::parameter::method const &);
