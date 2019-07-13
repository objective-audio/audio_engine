//
//  yas_audio_unit_parameter.cpp
//

#include <cpp_utils/yas_cf_utils.h>
#include "yas_audio_unit.h"

using namespace yas;

audio::unit::parameter::parameter(AudioUnitParameterInfo const &info, AudioUnitParameterID const parameter_id,
                                  AudioUnitScope const scope)
: _parameter_id(parameter_id),
_scope(scope),
_has_clump(info.flags & kAudioUnitParameterFlag_HasClump),
_clump_id(info.clumpID),
_unit(info.unit),
_min_value(info.minValue),
_max_value(info.maxValue),
_default_value(info.defaultValue),
_unit_name(to_string(info.unitName)),
_name(to_string(info.cfNameString)) {
}

#pragma mark - accessor

AudioUnitParameterID audio::unit::parameter::parameter_id() const {
    return this->_parameter_id;
}

AudioUnitScope audio::unit::parameter::scope() const {
    return this->_scope;
}

CFStringRef audio::unit::parameter::unit_name() const {
    return to_cf_object(this->_unit_name);
}

bool audio::unit::parameter::has_clump() const {
    return this->_has_clump;
}

uint32_t audio::unit::parameter::clump_id() const {
    return this->_clump_id;
}

CFStringRef audio::unit::parameter::name() const {
    return to_cf_object(this->_name);
}

AudioUnitParameterUnit audio::unit::parameter::unit() const {
    return this->_unit;
}

AudioUnitParameterValue audio::unit::parameter::min_value() const {
    return this->_min_value;
}

AudioUnitParameterValue audio::unit::parameter::max_value() const {
    return this->_max_value;
}

AudioUnitParameterValue audio::unit::parameter::default_value() const {
    return this->_default_value;
}

float audio::unit::parameter::value(AudioUnitElement const element) const {
    return this->_values.at(element);
}

void audio::unit::parameter::set_value(AudioUnitParameterValue const value, AudioUnitElement const element) {
    change_info info{
        .element = element,
        .old_value = this->_values[element],
        .new_value = value,
        .parameter = cast<audio::unit::parameter>(),
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
