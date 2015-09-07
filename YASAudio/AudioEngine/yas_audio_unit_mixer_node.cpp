//
//  yas_audio_unit_mixer_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_mixer_node.h"

using namespace yas;

audio_unit_mixer_node_sptr audio_unit_mixer_node::create()
{
    auto node = audio_unit_mixer_node_sptr(new audio_unit_mixer_node());
    prepare_for_create(node);
    return node;
}

audio_unit_mixer_node::audio_unit_mixer_node()
    : audio_unit_node({
          .componentType = kAudioUnitType_Mixer,
          .componentSubType = kAudioUnitSubType_MultiChannelMixer,
          .componentManufacturer = kAudioUnitManufacturer_Apple,
          .componentFlags = 0,
          .componentFlagsMask = 0,
      })
{
}

void audio_unit_mixer_node::update_connections()
{
    auto &connections = input_connections();
    if (connections.size() > 0) {
        auto last = connections.end();
        --last;
        if (auto unit = audio_unit()) {
            auto &pair = *last;
            unit->set_element_count(pair.first + 1, kAudioUnitScope_Input);
        }
    }

    super_class::update_connections();
}

UInt32 audio_unit_mixer_node::input_bus_count() const
{
    return std::numeric_limits<UInt32>::max();
}

UInt32 audio_unit_mixer_node::output_bus_count() const
{
    return 1;
}

void audio_unit_mixer_node::set_output_volume(const Float32 volume, const UInt32 bus_idx)
{
    set_output_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

Float32 audio_unit_mixer_node::output_volume(const UInt32 bus_idx)
{
    return output_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio_unit_mixer_node::set_output_pan(const Float32 pan, const UInt32 bus_idx)
{
    set_output_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

Float32 audio_unit_mixer_node::output_pan(const UInt32 bus_idx)
{
    return output_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio_unit_mixer_node::set_input_volume(const Float32 volume, const UInt32 bus_idx)
{
    set_input_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

Float32 audio_unit_mixer_node::input_volume(const UInt32 bus_idx)
{
    return input_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio_unit_mixer_node::set_input_pan(const Float32 pan, const UInt32 bus_idx)
{
    set_input_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

Float32 audio_unit_mixer_node::input_pan(const UInt32 bus_idx)
{
    return input_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio_unit_mixer_node::set_input_enabled(const bool enabled, UInt32 bus_idx)
{
    set_input_parameter_value(kMultiChannelMixerParam_Enable, enabled ? 1.0f : 0.0f, bus_idx);
}

bool audio_unit_mixer_node::input_enabled(UInt32 bus_idx)
{
    return input_parameter_value(kMultiChannelMixerParam_Enable, bus_idx) != 0.0f;
}
