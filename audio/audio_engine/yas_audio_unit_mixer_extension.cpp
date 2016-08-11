//
//  yas_audio_unit_mixer_extension.cpp
//

#include "yas_audio_node.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_extension.h"
#include "yas_audio_unit_mixer_extension.h"

using namespace yas;

#pragma mark - impl

struct audio::unit_mixer_extension::impl : base::impl {
    audio::unit_extension _unit_extension;

    impl()
        : _unit_extension(
              {.acd =
                   AudioComponentDescription{
                       .componentType = kAudioUnitType_Mixer,
                       .componentSubType = kAudioUnitSubType_MultiChannelMixer,
                       .componentManufacturer = kAudioUnitManufacturer_Apple,
                       .componentFlags = 0,
                       .componentFlagsMask = 0,
                   },
               .node_args = {.input_bus_count = std::numeric_limits<uint32_t>::max(), .output_bus_count = 1}}) {
    }

    void prepare(audio::unit_mixer_extension const &ext) {
        _connections_observer = _unit_extension.subject().make_observer(
            audio::unit_extension::method::will_update_connections, [weak_ext = to_weak(ext)](auto const &) {
                if (auto ext = weak_ext.lock()) {
                    ext.impl_ptr<impl>()->update_unit_mixer_connections();
                }
            });
    }

   private:
    void update_unit_mixer_connections() {
        auto &connections = _unit_extension.node().input_connections();
        if (connections.size() > 0) {
            auto last = connections.end();
            --last;
            if (auto unit = _unit_extension.audio_unit()) {
                auto &pair = *last;
                unit.set_element_count(pair.first + 1, kAudioUnitScope_Input);
            }
        }
    }

    audio::unit_extension::observer_t _connections_observer;
};

#pragma mark - main

audio::unit_mixer_extension::unit_mixer_extension() : base(std::make_unique<impl>()) {
}

audio::unit_mixer_extension::unit_mixer_extension(std::nullptr_t) : base(nullptr) {
}

audio::unit_mixer_extension::~unit_mixer_extension() = default;

void audio::unit_mixer_extension::set_output_volume(float const volume, uint32_t const bus_idx) {
    unit_extension().set_output_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::unit_mixer_extension::output_volume(uint32_t const bus_idx) const {
    return unit_extension().output_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::unit_mixer_extension::set_output_pan(float const pan, uint32_t const bus_idx) {
    unit_extension().set_output_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::unit_mixer_extension::output_pan(uint32_t const bus_idx) const {
    return unit_extension().output_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::unit_mixer_extension::set_input_volume(float const volume, uint32_t const bus_idx) {
    unit_extension().set_input_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::unit_mixer_extension::input_volume(uint32_t const bus_idx) const {
    return unit_extension().input_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::unit_mixer_extension::set_input_pan(float const pan, uint32_t const bus_idx) {
    unit_extension().set_input_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::unit_mixer_extension::input_pan(uint32_t const bus_idx) const {
    return unit_extension().input_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::unit_mixer_extension::set_input_enabled(bool const enabled, uint32_t const bus_idx) {
    unit_extension().set_input_parameter_value(kMultiChannelMixerParam_Enable, enabled ? 1.0f : 0.0f, bus_idx);
}

bool audio::unit_mixer_extension::input_enabled(uint32_t const bus_idx) const {
    return unit_extension().input_parameter_value(kMultiChannelMixerParam_Enable, bus_idx) != 0.0f;
}

audio::unit_extension const &audio::unit_mixer_extension::unit_extension() const {
    return impl_ptr<impl>()->_unit_extension;
}

audio::unit_extension &audio::unit_mixer_extension::unit_extension() {
    return impl_ptr<impl>()->_unit_extension;
}
