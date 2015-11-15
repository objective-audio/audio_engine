//
//  yas_audio_unit_mixer_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_mixer_node.h"
#include "yas_audio_unit.h"

using namespace yas;

#pragma mark - impl

class audio_unit_mixer_node::impl : public super_class::impl
{
    using super_class = audio_unit_node::impl;

   private:
    virtual UInt32 input_bus_count() const override
    {
        return std::numeric_limits<UInt32>::max();
    }

    virtual UInt32 output_bus_count() const override
    {
        return 1;
    }

    virtual void update_connections() override
    {
        auto &connections = input_connections();
        if (connections.size() > 0) {
            auto last = connections.end();
            --last;
            if (auto unit = au()) {
                auto &pair = *last;
                unit.set_element_count(pair.first + 1, kAudioUnitScope_Input);
            }
        }

        super_class::update_connections();
    }
};

#pragma mark - main

audio_unit_mixer_node::audio_unit_mixer_node()
    : super_class(std::make_unique<impl>(), AudioComponentDescription{
                                                .componentType = kAudioUnitType_Mixer,
                                                .componentSubType = kAudioUnitSubType_MultiChannelMixer,
                                                .componentManufacturer = kAudioUnitManufacturer_Apple,
                                                .componentFlags = 0,
                                                .componentFlagsMask = 0,
                                            })
{
}

audio_unit_mixer_node::audio_unit_mixer_node(std::nullptr_t) : super_class(nullptr)
{
}

void audio_unit_mixer_node::set_output_volume(const Float32 volume, const UInt32 bus_idx) const
{
    set_output_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

Float32 audio_unit_mixer_node::output_volume(const UInt32 bus_idx) const
{
    return output_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio_unit_mixer_node::set_output_pan(const Float32 pan, const UInt32 bus_idx) const
{
    set_output_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

Float32 audio_unit_mixer_node::output_pan(const UInt32 bus_idx) const
{
    return output_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio_unit_mixer_node::set_input_volume(const Float32 volume, const UInt32 bus_idx) const
{
    set_input_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

Float32 audio_unit_mixer_node::input_volume(const UInt32 bus_idx) const
{
    return input_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio_unit_mixer_node::set_input_pan(const Float32 pan, const UInt32 bus_idx) const
{
    set_input_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

Float32 audio_unit_mixer_node::input_pan(const UInt32 bus_idx) const
{
    return input_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio_unit_mixer_node::set_input_enabled(const bool enabled, UInt32 bus_idx) const
{
    set_input_parameter_value(kMultiChannelMixerParam_Enable, enabled ? 1.0f : 0.0f, bus_idx);
}

bool audio_unit_mixer_node::input_enabled(UInt32 bus_idx) const
{
    return input_parameter_value(kMultiChannelMixerParam_Enable, bus_idx) != 0.0f;
}
