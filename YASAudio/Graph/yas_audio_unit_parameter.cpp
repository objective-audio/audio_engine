//
//  yas_audio_unit_parameter.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_parameter.h"
#include "yas_cf_utils.h"
#include "YASMacros.h"

using namespace yas;

class audio_unit_parameter::impl
{
   public:
    AudioUnitParameterID parameter_id;
    AudioUnitScope scope;
    bool has_clump;
    UInt32 clump_id;
    AudioUnitParameterUnit unit;
    AudioUnitParameterValue min_value;
    AudioUnitParameterValue max_value;
    AudioUnitParameterValue default_value;
    std::map<AudioUnitElement, AudioUnitParameterValue> values;
    std::string unit_name;
    std::string name;

    impl(const AudioUnitParameterInfo &info, const AudioUnitParameterID parameter_id, const AudioUnitScope scope)
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
          name(yas::to_string(info.cfNameString))
    {
    }

    ~impl()
    {
    }

    impl(impl &&impl)
    {
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

    impl &operator=(impl &&impl)
    {
        return *this;
    }
};

audio_unit_parameter::audio_unit_parameter(const AudioUnitParameterInfo &info, const AudioUnitParameterID parameter_id,
                                           const AudioUnitScope scope)
    : _impl(std::make_unique<impl>(info, parameter_id, scope))
{
}

audio_unit_parameter::~audio_unit_parameter() = default;

audio_unit_parameter::audio_unit_parameter(audio_unit_parameter &&parameter)
{
    _impl = std::move(parameter._impl);
}

audio_unit_parameter &audio_unit_parameter::operator=(audio_unit_parameter &&parameter)
{
    if (this == &parameter) {
        return *this;
    }
    _impl = std::move(parameter._impl);
    return *this;
}

#pragma mark - accessor

AudioUnitParameterID audio_unit_parameter::parameter_id() const
{
    return _impl->parameter_id;
}

AudioUnitScope audio_unit_parameter::scope() const
{
    return _impl->scope;
}

const std::string &audio_unit_parameter::unit_name() const
{
    return _impl->unit_name;
}

bool audio_unit_parameter::has_clump() const
{
    return _impl->has_clump;
}

UInt32 audio_unit_parameter::clump_id() const
{
    return _impl->clump_id;
}

const std::string &audio_unit_parameter::name() const
{
    return _impl->name;
}

AudioUnitParameterUnit audio_unit_parameter::unit() const
{
    return _impl->unit;
}

AudioUnitParameterValue audio_unit_parameter::min_value() const
{
    return _impl->min_value;
}

AudioUnitParameterValue audio_unit_parameter::max_value() const
{
    return _impl->max_value;
}

AudioUnitParameterValue audio_unit_parameter::default_value() const
{
    return _impl->default_value;
}

Float32 audio_unit_parameter::value(const AudioUnitElement element) const
{
    return _impl->values.at(element);
}

void audio_unit_parameter::set_value(const AudioUnitParameterValue value, const AudioUnitElement element)
{
    _impl->values[element] = value;
}

const std::map<AudioUnitElement, AudioUnitParameterValue> &audio_unit_parameter::values() const
{
    return _impl->values;
}
