//
//  yas_audio_unit_parameter.cpp
//

#include "yas_audio_unit.h"
#include "yas_cf_utils.h"
#include "yas_observing.h"

using namespace yas;

struct audio::unit::parameter::impl : base::impl {
    AudioUnitParameterID _parameter_id;
    AudioUnitScope _scope;
    bool _has_clump;
    uint32_t _clump_id;
    AudioUnitParameterUnit _unit;
    AudioUnitParameterValue _min_value;
    AudioUnitParameterValue _max_value;
    AudioUnitParameterValue _default_value;
    std::unordered_map<AudioUnitElement, AudioUnitParameterValue> _values;
    std::string _unit_name;
    std::string _name;
    subject_t _subject;

    impl(AudioUnitParameterInfo const &info, AudioUnitParameterID const parameter_id, AudioUnitScope const scope)
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

    ~impl() {
    }

    void set_value(AudioUnitParameterValue const value, AudioUnitElement const element) {
        change_info info{
            .element = element,
            .old_value = _values[element],
            .new_value = value,
            .parameter = cast<audio::unit::parameter>(),
        };

        _subject.notify(method::will_change, info);
        _values[element] = value;
        _subject.notify(method::did_change, info);
    }
};

audio::unit::parameter::parameter(AudioUnitParameterInfo const &info, AudioUnitParameterID const parameter_id,
                                  AudioUnitScope const scope)
    : base(std::make_unique<impl>(info, parameter_id, scope)) {
}

audio::unit::parameter::parameter(std::nullptr_t) : base(nullptr) {
}

#pragma mark - accessor

AudioUnitParameterID audio::unit::parameter::parameter_id() const {
    return impl_ptr<impl>()->_parameter_id;
}

AudioUnitScope audio::unit::parameter::scope() const {
    return impl_ptr<impl>()->_scope;
}

CFStringRef audio::unit::parameter::unit_name() const {
    return to_cf_object(impl_ptr<impl>()->_unit_name);
}

bool audio::unit::parameter::has_clump() const {
    return impl_ptr<impl>()->_has_clump;
}

uint32_t audio::unit::parameter::clump_id() const {
    return impl_ptr<impl>()->_clump_id;
}

CFStringRef audio::unit::parameter::name() const {
    return to_cf_object(impl_ptr<impl>()->_name);
}

AudioUnitParameterUnit audio::unit::parameter::unit() const {
    return impl_ptr<impl>()->_unit;
}

AudioUnitParameterValue audio::unit::parameter::min_value() const {
    return impl_ptr<impl>()->_min_value;
}

AudioUnitParameterValue audio::unit::parameter::max_value() const {
    return impl_ptr<impl>()->_max_value;
}

AudioUnitParameterValue audio::unit::parameter::default_value() const {
    return impl_ptr<impl>()->_default_value;
}

float audio::unit::parameter::value(AudioUnitElement const element) const {
    return impl_ptr<impl>()->_values.at(element);
}

void audio::unit::parameter::set_value(AudioUnitParameterValue const value, AudioUnitElement const element) {
    impl_ptr<impl>()->set_value(value, element);
}

std::unordered_map<AudioUnitElement, AudioUnitParameterValue> const &audio::unit::parameter::values() const {
    return impl_ptr<impl>()->_values;
}

audio::unit::parameter::subject_t &audio::unit::parameter::subject() {
    return impl_ptr<impl>()->_subject;
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
