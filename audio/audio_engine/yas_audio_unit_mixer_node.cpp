//
//  yas_audio_unit_mixer_node.cpp
//

#include "yas_audio_node.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_mixer_node.h"
#include "yas_audio_unit_node.h"

using namespace yas;

#pragma mark - impl

struct audio::unit_mixer_node::impl : base::impl {
    audio::unit_node _unit_node;

    impl()
        : _unit_node({.acd =
                          AudioComponentDescription{
                              .componentType = kAudioUnitType_Mixer,
                              .componentSubType = kAudioUnitSubType_MultiChannelMixer,
                              .componentManufacturer = kAudioUnitManufacturer_Apple,
                              .componentFlags = 0,
                              .componentFlagsMask = 0,
                          },
                      .node_args = {.input_bus_count = std::numeric_limits<uint32_t>::max(), .output_bus_count = 1}}) {
    }

    void prepare(audio::unit_mixer_node const &node) {
        _connections_observer = _unit_node.subject().make_observer(
            audio::unit_node::method::will_update_connections, [weak_node = to_weak(node)](auto const &) {
                if (auto node = weak_node.lock()) {
                    node.impl_ptr<impl>()->update_unit_mixer_connections();
                }
            });
    }

   private:
    void update_unit_mixer_connections() {
        auto &connections = _unit_node.node().input_connections();
        if (connections.size() > 0) {
            auto last = connections.end();
            --last;
            if (auto unit = _unit_node.audio_unit()) {
                auto &pair = *last;
                unit.set_element_count(pair.first + 1, kAudioUnitScope_Input);
            }
        }
    }

    audio::unit_node::observer_t _connections_observer;
};

#pragma mark - main

audio::unit_mixer_node::unit_mixer_node() : base(std::make_unique<impl>()) {
}

audio::unit_mixer_node::unit_mixer_node(std::nullptr_t) : base(nullptr) {
}

audio::unit_mixer_node::~unit_mixer_node() = default;

void audio::unit_mixer_node::set_output_volume(float const volume, uint32_t const bus_idx) {
    unit_node().set_output_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::unit_mixer_node::output_volume(uint32_t const bus_idx) const {
    return unit_node().output_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::unit_mixer_node::set_output_pan(float const pan, uint32_t const bus_idx) {
    unit_node().set_output_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::unit_mixer_node::output_pan(uint32_t const bus_idx) const {
    return unit_node().output_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::unit_mixer_node::set_input_volume(float const volume, uint32_t const bus_idx) {
    unit_node().set_input_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::unit_mixer_node::input_volume(uint32_t const bus_idx) const {
    return unit_node().input_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::unit_mixer_node::set_input_pan(float const pan, uint32_t const bus_idx) {
    unit_node().set_input_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::unit_mixer_node::input_pan(uint32_t const bus_idx) const {
    return unit_node().input_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::unit_mixer_node::set_input_enabled(bool const enabled, uint32_t const bus_idx) {
    unit_node().set_input_parameter_value(kMultiChannelMixerParam_Enable, enabled ? 1.0f : 0.0f, bus_idx);
}

bool audio::unit_mixer_node::input_enabled(uint32_t const bus_idx) const {
    return unit_node().input_parameter_value(kMultiChannelMixerParam_Enable, bus_idx) != 0.0f;
}

audio::unit_node const &audio::unit_mixer_node::unit_node() const {
    return impl_ptr<impl>()->_unit_node;
}

audio::unit_node &audio::unit_mixer_node::unit_node() {
    return impl_ptr<impl>()->_unit_node;
}
