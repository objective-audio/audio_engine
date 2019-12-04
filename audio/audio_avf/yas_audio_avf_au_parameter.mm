//
//  yas_audio_engine_avf_au_parameter.mm
//

#include "yas_audio_avf_au_parameter.h"
#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_avf_au_parameter_core.h"

using namespace yas;

audio::avf_au_parameter::avf_au_parameter(avf_au_parameter_core_ptr const &core)
    : _core(core), _value(chaining::value::holder<AUValue>::make_shared(core->objc_parameter.object().value)) {
    this->_pool += this->_value->chain()
                       .perform([this](auto const &value) { this->_core->objc_parameter.object().value = value; })
                       .end();
}

std::string audio::avf_au_parameter::key_path() const {
    return to_string((__bridge CFStringRef)this->_core->objc_parameter.object().keyPath);
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

std::string audio::avf_au_parameter::identifier() const {
    return to_string((__bridge CFStringRef)this->_core->objc_parameter.object().identifier);
}

AudioUnitParameterUnit audio::avf_au_parameter::unit() const {
    return this->_core->objc_parameter.object().unit;
}

AUValue audio::avf_au_parameter::min_value() const {
    return this->_core->objc_parameter.object().minValue;
}

AUValue audio::avf_au_parameter::max_value() const {
    return this->_core->objc_parameter.object().maxValue;
}

std::optional<std::string> audio::avf_au_parameter::unit_name() const {
    if (NSString *unitName = this->_core->objc_parameter.object().unitName) {
        return to_string((__bridge CFStringRef)unitName);
    } else {
        return std::nullopt;
    }
}

AUValue audio::avf_au_parameter::value() const {
    return this->_value->raw();
}

void audio::avf_au_parameter::set_value(AUValue const value) {
    this->_value->set_value(value);
}

chaining::chain_sync_t<AUValue> audio::avf_au_parameter::chain() const {
    return this->_value->chain();
}

void audio::avf_au_parameter::_prepare(avf_au_parameter_ptr const &shared) {
}

audio::avf_au_parameter_ptr audio::avf_au_parameter::make_shared(avf_au_parameter_core_ptr const &core) {
    auto shared = avf_au_parameter_ptr(new avf_au_parameter{core});
    shared->_prepare(shared);
    return shared;
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