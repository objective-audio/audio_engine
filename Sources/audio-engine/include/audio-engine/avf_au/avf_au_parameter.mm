//
//  avf_au_parameter.mm
//

#include "avf_au_parameter.h"

#import <AVFoundation/AVFoundation.h>

#include <cpp-utils/cf_utils.h>
#include <cpp-utils/stl_utils.h>

using namespace yas;
using namespace yas::audio;

static_assert(sizeof(AUValue) == sizeof(float), "AUValue must be equal to float.");

avf_au_parameter::avf_au_parameter(std::string &&key_path, std::string &&identifier, AudioUnitParameterUnit const unit,
                                   std::optional<std::string> &&unit_name, float const default_value,
                                   std::string &&display_name, float const min_value, float const max_value,
                                   std::vector<std::string> &&value_strings, std::vector<float> &&values)
    : key_path(std::move(key_path)),
      identifier(std::move(identifier)),
      unit(unit),
      unit_name(std::move(unit_name)),
      _default_value(default_value),
      display_name(std::move(display_name)),
      _min_value(min_value),
      _max_value(max_value),
      _value_strings(std::move(value_strings)),
      _values(std::move(values)),
      _value(_default_value) {
}

avf_au_parameter_scope avf_au_parameter::scope() const {
    return scope_from_key_path(this->key_path);
}

float avf_au_parameter::min_value() const {
    return this->_min_value;
}

float avf_au_parameter::max_value() const {
    return this->_max_value;
}

float const &avf_au_parameter::default_value() const {
    return this->_default_value;
}

std::vector<std::string> const &avf_au_parameter::value_strings() const {
    return this->_value_strings;
}

float avf_au_parameter::value() const {
    return this->_value;
}

void avf_au_parameter::set_value(float const value) {
    if (this->_value != value) {
        this->_value = value;
        if (this->_value_changed_handler) {
            this->_value_changed_handler(value);
        }
    }
}

void avf_au_parameter::set_value_at(std::size_t const idx) {
    if (idx < this->_values.size()) {
        this->set_value(this->_values.at(idx));
    }
}

void avf_au_parameter::reset_value() {
    this->set_value(this->_default_value);
}

void avf_au_parameter::set_value_changed_handler(std::function<void(float const)> &&handler) {
    this->_value_changed_handler = std::move(handler);
}

avf_au_parameter_ptr avf_au_parameter::make_shared(std::string &&key_path, std::string &&identifier,
                                                   AudioUnitParameterUnit const unit,
                                                   std::optional<std::string> &&unit_name, float const default_value,
                                                   std::string &&display_name, float const min_value,
                                                   float const max_value, std::vector<std::string> &&value_strings,
                                                   std::vector<float> &&values) {
    return avf_au_parameter_ptr(new avf_au_parameter{
        std::move(key_path), std::move(identifier), unit, std::move(unit_name), default_value, std::move(display_name),
        min_value, max_value, std::move(value_strings), std::move(values)});
}

avf_au_parameter_scope avf_au_parameter::scope_from_key_path(std::string const &key_path) {
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
