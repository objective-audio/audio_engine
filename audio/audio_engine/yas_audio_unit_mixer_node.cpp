//
//  yas_audio_unit_mixer_node.cpp
//

#include "yas_audio_unit.h"
#include "yas_audio_unit_mixer_node.h"

using namespace yas;

#pragma mark - impl

struct audio::unit_mixer_node::impl : unit_node::impl {
   private:
    virtual UInt32 input_bus_count() const override {
        return std::numeric_limits<UInt32>::max();
    }

    virtual UInt32 output_bus_count() const override {
        return 1;
    }

    virtual void update_connections() override {
        auto &connections = input_connections();
        if (connections.size() > 0) {
            auto last = connections.end();
            --last;
            if (auto unit = au()) {
                auto &pair = *last;
                unit.set_element_count(pair.first + 1, kAudioUnitScope_Input);
            }
        }

        unit_node::impl::update_connections();
    }
};

#pragma mark - main

audio::unit_mixer_node::unit_mixer_node()
    : unit_node(std::make_unique<impl>(), AudioComponentDescription{
                                              .componentType = kAudioUnitType_Mixer,
                                              .componentSubType = kAudioUnitSubType_MultiChannelMixer,
                                              .componentManufacturer = kAudioUnitManufacturer_Apple,
                                              .componentFlags = 0,
                                              .componentFlagsMask = 0,
                                          }) {
}

audio::unit_mixer_node::unit_mixer_node(std::nullptr_t) : unit_node(nullptr) {
}

void audio::unit_mixer_node::set_output_volume(Float32 const volume, UInt32 const bus_idx) {
    set_output_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

Float32 audio::unit_mixer_node::output_volume(UInt32 const bus_idx) const {
    return output_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::unit_mixer_node::set_output_pan(Float32 const pan, UInt32 const bus_idx) {
    set_output_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

Float32 audio::unit_mixer_node::output_pan(UInt32 const bus_idx) const {
    return output_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::unit_mixer_node::set_input_volume(Float32 const volume, UInt32 const bus_idx) {
    set_input_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

Float32 audio::unit_mixer_node::input_volume(UInt32 const bus_idx) const {
    return input_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::unit_mixer_node::set_input_pan(Float32 const pan, UInt32 const bus_idx) {
    set_input_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

Float32 audio::unit_mixer_node::input_pan(UInt32 const bus_idx) const {
    return input_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::unit_mixer_node::set_input_enabled(const bool enabled, UInt32 const bus_idx) {
    set_input_parameter_value(kMultiChannelMixerParam_Enable, enabled ? 1.0f : 0.0f, bus_idx);
}

bool audio::unit_mixer_node::input_enabled(UInt32 const bus_idx) const {
    return input_parameter_value(kMultiChannelMixerParam_Enable, bus_idx) != 0.0f;
}
