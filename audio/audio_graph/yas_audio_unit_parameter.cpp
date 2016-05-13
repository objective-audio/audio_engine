//
//  yas_audio_unit_parameter.cpp
//

#include "yas_audio_unit.h"
#include "yas_cf_utils.h"
#include "yas_observing.h"

using namespace yas;

struct audio::unit::parameter::impl : base::impl {
    AudioUnitParameterID parameter_id;
    AudioUnitScope scope;
    bool has_clump;
    uint32_t clump_id;
    AudioUnitParameterUnit unit;
    AudioUnitParameterValue min_value;
    AudioUnitParameterValue max_value;
    AudioUnitParameterValue default_value;
    std::unordered_map<AudioUnitElement, AudioUnitParameterValue> values;
    std::string unit_name;
    std::string name;
    subject_t subject;

    impl(AudioUnitParameterInfo const &info, AudioUnitParameterID const parameter_id, AudioUnitScope const scope)
        : parameter_id(parameter_id),
          scope(scope),
          has_clump(info.flags & kAudioUnitParameterFlag_HasClump),
          clump_id(info.clumpID),
          unit(info.unit),
          min_value(info.minValue),
          max_value(info.maxValue),
          default_value(info.defaultValue),
          values(),
          unit_name(to_string(info.unitName)),
          name(to_string(info.cfNameString)) {
    }

    ~impl() {
    }

    void set_value(AudioUnitParameterValue const value, AudioUnitElement const element) {
        change_info info{
            .element = element,
            .old_value = values[element],
            .new_value = value,
            .parameter = cast<audio::unit::parameter>(),
        };

        subject.notify(method::will_change, info);
        values[element] = value;
        subject.notify(method::did_change, info);
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
    return impl_ptr<impl>()->parameter_id;
}

AudioUnitScope audio::unit::parameter::scope() const {
    return impl_ptr<impl>()->scope;
}

CFStringRef audio::unit::parameter::unit_name() const {
    return to_cf_object(impl_ptr<impl>()->unit_name);
}

bool audio::unit::parameter::has_clump() const {
    return impl_ptr<impl>()->has_clump;
}

uint32_t audio::unit::parameter::clump_id() const {
    return impl_ptr<impl>()->clump_id;
}

CFStringRef audio::unit::parameter::name() const {
    return to_cf_object(impl_ptr<impl>()->name);
}

AudioUnitParameterUnit audio::unit::parameter::unit() const {
    return impl_ptr<impl>()->unit;
}

AudioUnitParameterValue audio::unit::parameter::min_value() const {
    return impl_ptr<impl>()->min_value;
}

AudioUnitParameterValue audio::unit::parameter::max_value() const {
    return impl_ptr<impl>()->max_value;
}

AudioUnitParameterValue audio::unit::parameter::default_value() const {
    return impl_ptr<impl>()->default_value;
}

float audio::unit::parameter::value(AudioUnitElement const element) const {
    return impl_ptr<impl>()->values.at(element);
}

void audio::unit::parameter::set_value(AudioUnitParameterValue const value, AudioUnitElement const element) {
    impl_ptr<impl>()->set_value(value, element);
}

std::unordered_map<AudioUnitElement, AudioUnitParameterValue> const &audio::unit::parameter::values() const {
    return impl_ptr<impl>()->values;
}

audio::unit::parameter::subject_t &audio::unit::parameter::subject() {
    return impl_ptr<impl>()->subject;
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
