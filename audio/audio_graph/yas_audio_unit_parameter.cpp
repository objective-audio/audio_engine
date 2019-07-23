//
//  yas_audio_unit_parameter.cpp
//

#include <cpp_utils/yas_cf_utils.h>
#include "yas_audio_unit.h"

using namespace yas;

audio::unit::parameter::parameter(AudioUnitParameterInfo const &info, AudioUnitParameterID const parameter_id,
                                  AudioUnitScope const scope)
    : parameter_id(parameter_id),
      scope(scope),
      has_clump(info.flags & kAudioUnitParameterFlag_HasClump),
      clump_id(info.clumpID),
      unit(info.unit),
      min_value(info.minValue),
      max_value(info.maxValue),
      default_value(info.defaultValue),
      unit_name(to_string(info.unitName)),
      name(to_string(info.cfNameString)) {
}

#pragma mark - accessor

CFStringRef audio::unit::parameter::cf_unit_name() const {
    return to_cf_object(this->unit_name);
}

CFStringRef audio::unit::parameter::cf_name() const {
    return to_cf_object(this->name);
}

float audio::unit::parameter::value(AudioUnitElement const element) const {
    return this->_values.at(element);
}

void audio::unit::parameter::set_value(AudioUnitParameterValue const value, AudioUnitElement const element) {
    change_info info{
        .element = element,
        .old_value = this->_values[element],
        .new_value = value,
        .parameter = *this,
    };

    this->_notifier.notify(std::make_pair(method::will_change, info));
    this->_values[element] = value;
    this->_notifier.notify(std::make_pair(method::did_change, info));
}

std::unordered_map<AudioUnitElement, AudioUnitParameterValue> const &audio::unit::parameter::values() const {
    return this->_values;
}

chaining::chain_unsync_t<audio::unit::parameter::chaining_pair_t> audio::unit::parameter::chain() const {
    return this->_notifier.chain();
}

chaining::chain_relayed_unsync_t<audio::unit::parameter::change_info, audio::unit::parameter::chaining_pair_t>
audio::unit::parameter::chain(method const method) const {
    return this->_notifier.chain()
        .guard([method](auto const &pair) { return pair.first == method; })
        .to([](chaining_pair_t const &pair) { return pair.second; });
}

#pragma mark -

std::string yas::to_string(audio::unit::parameter::method const &method) {
    switch (method) {
        case audio::unit::parameter::method::will_change:
            return "will_change";
        case audio::unit::parameter::method::did_change:
            return "did_change";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::unit::parameter::method const &value) {
    os << to_string(value);
    return os;
}
