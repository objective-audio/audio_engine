//
//  yas_audio_unit_parameter.cpp
//

#include "yas_audio_unit.h"
#include "yas_cf_utils.h"

using namespace yas;

class yas::audio::unit::parameter::impl {
   public:
    AudioUnitParameterID parameter_id;
    AudioUnitScope scope;
    bool has_clump;
    UInt32 clump_id;
    AudioUnitParameterUnit unit;
    AudioUnitParameterValue min_value;
    AudioUnitParameterValue max_value;
    AudioUnitParameterValue default_value;
    std::unordered_map<AudioUnitElement, AudioUnitParameterValue> values;
    std::string unit_name;
    std::string name;
    yas::subject<audio::unit::parameter::change_info> subject;

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
          unit_name(yas::to_string(info.unitName)),
          name(yas::to_string(info.cfNameString)) {
    }

    ~impl() {
    }

    impl(impl &&impl) {
        parameter_id = std::move(impl.parameter_id);
        scope = std::move(impl.scope);
        has_clump = std::move(impl.has_clump);
        clump_id = std::move(impl.clump_id);
        unit = std::move(impl.unit);
        min_value = std::move(impl.min_value);
        max_value = std::move(impl.max_value);
        default_value = std::move(impl.default_value);
        values = std::move(impl.values);
        unit_name = std::move(impl.unit_name);
        name = std::move(impl.name);
    }

    impl &operator=(impl &&impl) {
        parameter_id = std::move(impl.parameter_id);
        scope = std::move(impl.scope);
        has_clump = std::move(impl.has_clump);
        clump_id = std::move(impl.clump_id);
        unit = std::move(impl.unit);
        min_value = std::move(impl.min_value);
        max_value = std::move(impl.max_value);
        default_value = std::move(impl.default_value);
        values = std::move(impl.values);
        unit_name = std::move(impl.unit_name);
        name = std::move(impl.name);

        return *this;
    }
};

audio::unit::parameter::parameter(AudioUnitParameterInfo const &info, AudioUnitParameterID const parameter_id,
                                  AudioUnitScope const scope)
    : _impl(std::make_unique<impl>(info, parameter_id, scope)) {
}

audio::unit::parameter::~parameter() = default;

audio::unit::parameter::parameter(parameter &&parameter) {
    _impl = std::move(parameter._impl);
}

audio::unit::parameter &audio::unit::parameter::operator=(parameter &&rhs) {
    if (this == &rhs) {
        return *this;
    }
    _impl = std::move(rhs._impl);
    return *this;
}

#pragma mark - accessor

AudioUnitParameterID audio::unit::parameter::parameter_id() const {
    return _impl->parameter_id;
}

AudioUnitScope audio::unit::parameter::scope() const {
    return _impl->scope;
}

CFStringRef audio::unit::parameter::unit_name() const {
    return to_cf_object(_impl->unit_name);
}

bool audio::unit::parameter::has_clump() const {
    return _impl->has_clump;
}

UInt32 audio::unit::parameter::clump_id() const {
    return _impl->clump_id;
}

CFStringRef audio::unit::parameter::name() const {
    return to_cf_object(_impl->name);
}

AudioUnitParameterUnit audio::unit::parameter::unit() const {
    return _impl->unit;
}

AudioUnitParameterValue audio::unit::parameter::min_value() const {
    return _impl->min_value;
}

AudioUnitParameterValue audio::unit::parameter::max_value() const {
    return _impl->max_value;
}

AudioUnitParameterValue audio::unit::parameter::default_value() const {
    return _impl->default_value;
}

Float32 audio::unit::parameter::value(AudioUnitElement const element) const {
    return _impl->values.at(element);
}

void audio::unit::parameter::set_value(AudioUnitParameterValue const value, AudioUnitElement const element) {
    change_info info{
        .element = element, .old_value = _impl->values[element], .new_value = value, .parameter = *this,
    };

    _impl->subject.notify(will_change_key, info);
    _impl->values[element] = value;
    _impl->subject.notify(did_change_key, info);
}

std::unordered_map<AudioUnitElement, AudioUnitParameterValue> const &audio::unit::parameter::values() const {
    return _impl->values;
}

subject<audio::unit::parameter::change_info> &audio::unit::parameter::subject() {
    return _impl->subject;
}
