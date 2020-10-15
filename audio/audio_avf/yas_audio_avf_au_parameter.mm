//
//  yas_audio_graph_avf_au_parameter.mm
//

#include "yas_audio_avf_au_parameter.h"
#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_stl_utils.h>

using namespace yas;

static_assert(sizeof(AUValue) == sizeof(float), "AUValue must be equal to float.");

namespace yas::audio::avf_au_parameter_utils {
std::vector<std::string> value_strings(AUParameter *const objc_param) {
    if (auto const valueStrings = objc_param.valueStrings) {
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

std::vector<float> values(AUParameter *const objc_param) {
    auto const strings = avf_au_parameter_utils::value_strings(objc_param);
    return yas::to_vector<float>(strings, [&objc_param](std::string const &string) {
        return [objc_param valueFromString:(__bridge NSString *)to_cf_object(string)];
    });
}

std::optional<std::string> unit_name(AUParameter *const objc_param) {
    if (NSString *unitName = objc_param.unitName) {
        return to_string((__bridge CFStringRef)unitName);
    } else {
        return std::nullopt;
    }
}
}

audio::avf_au_parameter::avf_au_parameter(AUParameter *const objc_param)
    : key_path(to_string((__bridge CFStringRef)objc_param.keyPath)),
      identifier(to_string((__bridge CFStringRef)objc_param.identifier)),
      unit(objc_param.unit),
      unit_name(avf_au_parameter_utils::unit_name(objc_param)),
      _default_value(objc_param.value),
      display_name(to_string((__bridge CFStringRef)objc_param.displayName)),
      _min_value(objc_param.minValue),
      _max_value(objc_param.maxValue),
      _value_strings(avf_au_parameter_utils::value_strings(objc_param)),
      _values(avf_au_parameter_utils::values(objc_param)),
      _value(_default_value) {
}

audio::avf_au_parameter::avf_au_parameter(std::string &&key_path, std::string &&identifier,
                                          AudioUnitParameterUnit const unit, std::optional<std::string> &&unit_name,
                                          float const default_value, std::string &&display_name, float const min_value,
                                          float const max_value, std::vector<std::string> &&value_strings,
                                          std::vector<float> &&values)
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

audio::avf_au_parameter_scope audio::avf_au_parameter::scope() const {
    return scope_from_key_path(this->key_path);
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

float audio::avf_au_parameter::value() const {
    return this->_value;
}

void audio::avf_au_parameter::set_value(float const value) {
    if (this->_value != value) {
        this->_value = value;
        if (this->_value_changed_handler) {
            this->_value_changed_handler(value);
        }
    }
}

void audio::avf_au_parameter::set_value_at(std::size_t const idx) {
    if (idx < this->_values.size()) {
        this->set_value(this->_values.at(idx));
    }
}

void audio::avf_au_parameter::reset_value() {
    this->set_value(this->_default_value);
}

void audio::avf_au_parameter::set_value_changed_handler(std::function<void(float const)> &&handler) {
    this->_value_changed_handler = std::move(handler);
}

audio::avf_au_parameter_ptr audio::avf_au_parameter::make_shared(AUParameter *const objc_param) {
    return avf_au_parameter_ptr(new avf_au_parameter{objc_param});
}

audio::avf_au_parameter_ptr audio::avf_au_parameter::make_shared(std::string &&key_path, std::string &&identifier,
                                                                 AudioUnitParameterUnit const unit,
                                                                 std::optional<std::string> &&unit_name,
                                                                 float const default_value, std::string &&display_name,
                                                                 float const min_value, float const max_value,
                                                                 std::vector<std::string> &&value_strings,
                                                                 std::vector<float> &&values) {
    return avf_au_parameter_ptr(new avf_au_parameter{
        std::move(key_path), std::move(identifier), unit, std::move(unit_name), default_value, std::move(display_name),
        min_value, max_value, std::move(value_strings), std::move(values)});
}

audio::avf_au_parameter_scope audio::avf_au_parameter::scope_from_key_path(std::string const &key_path) {
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
