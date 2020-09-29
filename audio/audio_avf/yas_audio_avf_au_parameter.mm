//
//  yas_audio_graph_avf_au_parameter.mm
//

#include "yas_audio_avf_au_parameter.h"
#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_avf_au_parameter_core.h"

using namespace yas;

static_assert(sizeof(AUValue) == sizeof(float), "AUValue must be equal to float.");

namespace yas::audio::avf_au_parameter_utils {
std::vector<std::string> value_strings(avf_au_parameter_core_ptr const &core) {
    if (auto const valueStrings = core->objc_parameter.object().valueStrings) {
        std::vector<std::string> result;
        result.reserve(valueStrings.count);

        for (NSString *valueString in valueStrings) {
            result.emplace_back(to_string((__bridge CFStringRef)valueString));
        }

        return result;
    } else {
        return {};
    }
}

std::vector<float> values(avf_au_parameter_core_ptr const &core) {
    auto const strings = avf_au_parameter_utils::value_strings(core);
    return yas::to_vector<float>(strings, [&core](std::string const &string) {
        return [core->objc_parameter.object() valueFromString:(__bridge NSString *)to_cf_object(string)];
    });
}

std::optional<std::string> unit_name(avf_au_parameter_core_ptr const &core) {
    if (NSString *unitName = core->objc_parameter.object().unitName) {
        return to_string((__bridge CFStringRef)unitName);
    } else {
        return std::nullopt;
    }
}
}

audio::avf_au_parameter::avf_au_parameter(avf_au_parameter_core_ptr const &core)
    : _key_path(to_string((__bridge CFStringRef)core->objc_parameter.object().keyPath)),
      _identifier(to_string((__bridge CFStringRef)core->objc_parameter.object().identifier)),
      _unit(core->objc_parameter.object().unit),
      _unit_name(avf_au_parameter_utils::unit_name(core)),
      _default_value(core->objc_parameter.object().value),
      _display_name(to_string((__bridge CFStringRef)core->objc_parameter.object().displayName)),
      _min_value(core->objc_parameter.object().minValue),
      _max_value(core->objc_parameter.object().maxValue),
      _value_strings(avf_au_parameter_utils::value_strings(core)),
      _values(avf_au_parameter_utils::values(core)),
      _value(chaining::value::holder<float>::make_shared(_default_value)) {
}

std::string const &audio::avf_au_parameter::key_path() const {
    return this->_key_path;
}

audio::avf_au_parameter_scope audio::avf_au_parameter::scope() const {
    using namespace yas::audio;

    auto const key_path = this->key_path();
    auto const scope_str = yas::split(key_path, '.').at(0);

    if (scope_str == to_string(avf_au_parameter_scope::global)) {
        return avf_au_parameter_scope::global;
    } else if (scope_str == to_string(avf_au_parameter_scope::input)) {
        return avf_au_parameter_scope::input;
    } else if (scope_str == to_string(avf_au_parameter_scope::output)) {
        return avf_au_parameter_scope::output;
    } else {
        throw std::runtime_error("scope not found.");
    }
}

std::string const &audio::avf_au_parameter::identifier() const {
    return this->_identifier;
}

AudioUnitParameterUnit audio::avf_au_parameter::unit() const {
    return this->_unit;
}

std::string const &audio::avf_au_parameter::display_name() const {
    return this->_display_name;
}

float audio::avf_au_parameter::min_value() const {
    return this->_min_value;
}

float audio::avf_au_parameter::max_value() const {
    return this->_max_value;
}

float const &audio::avf_au_parameter::default_value() const {
    return this->_default_value;
}

std::vector<std::string> const &audio::avf_au_parameter::value_strings() const {
    return this->_value_strings;
}

std::optional<std::string> const &audio::avf_au_parameter::unit_name() const {
    return this->_unit_name;
}

float audio::avf_au_parameter::value() const {
    return this->_value->raw();
}

void audio::avf_au_parameter::set_value(float const value) {
    this->_value->set_value(value);
}

void audio::avf_au_parameter::set_value_at(std::size_t const idx) {
    if (idx < this->_values.size()) {
        this->set_value(this->_values.at(idx));
    }
}

void audio::avf_au_parameter::reset_value() {
    this->_value->set_value(this->_default_value);
}

chaining::chain_sync_t<float> audio::avf_au_parameter::chain() const {
    return this->_value->chain();
}

audio::avf_au_parameter_ptr audio::avf_au_parameter::make_shared(avf_au_parameter_core_ptr const &core) {
    return avf_au_parameter_ptr(new avf_au_parameter{core});
}

AudioUnitScope audio::to_raw_scope(avf_au_parameter_scope const scope) {
    switch (scope) {
        case avf_au_parameter_scope::global:
            return kAudioUnitScope_Global;
        case avf_au_parameter_scope::input:
            return kAudioUnitScope_Input;
        case avf_au_parameter_scope::output:
            return kAudioUnitScope_Output;
    }
}

std::string yas::to_string(audio::avf_au_parameter_scope const &scope) {
    using namespace yas::audio;

    switch (scope) {
        case avf_au_parameter_scope::global:
            return "global";
        case avf_au_parameter_scope::input:
            return "input";
        case avf_au_parameter_scope::output:
            return "output";
    }
}
