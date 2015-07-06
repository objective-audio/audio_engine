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
    uint32_t clump_id;
    AudioUnitParameterUnit unit;
    AudioUnitParameterValue min_value;
    AudioUnitParameterValue max_value;
    AudioUnitParameterValue default_value;
    std::map<AudioUnitElement, AudioUnitParameterValue> values;

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
          _unit_name(nullptr),
          _name(nullptr)
    {
        set_unit_name(info.unitName);
        set_name(info.cfNameString);
    }

    ~impl()
    {
        set_unit_name(nullptr);
        set_name(nullptr);
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

        _unit_name = std::move(impl.unit_name());
        _name = std::move(impl.name());
        impl._unit_name = nullptr;
        impl._name = nullptr;
    }

    impl &operator=(impl &&impl)
    {
        return *this;
    }

    void set_unit_name(const CFStringRef &unit_name)
    {
        yas::set_cf_property(_unit_name, unit_name);
    }

    CFStringRef unit_name() const
    {
        return _unit_name;
    }

    void set_name(const CFStringRef &name)
    {
        yas::set_cf_property(_name, name);
    }

    CFStringRef name() const
    {
        return _name;
    }

   private:
    CFStringRef _unit_name;
    CFStringRef _name;
};

audio_unit_parameter::audio_unit_parameter(const AudioUnitParameterInfo &info, const AudioUnitParameterID parameter_id,
                                           const AudioUnitScope scope)
    : _impl(std::make_unique<impl>(info, parameter_id, scope))
{
}

audio_unit_parameter::~audio_unit_parameter()
{
}

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

CFStringRef audio_unit_parameter::unit_name() const
{
    return _impl->unit_name();
}

bool audio_unit_parameter::has_clump() const
{
    return _impl->has_clump;
}

uint32_t audio_unit_parameter::clump_id() const
{
    return _impl->clump_id;
}

CFStringRef audio_unit_parameter::name() const
{
    return _impl->name();
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
    _impl->values.insert(std::make_pair(element, value));
}
