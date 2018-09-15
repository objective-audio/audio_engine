//
//  yas_audio_au_mixer.cpp
//

#include "yas_audio_engine_au_mixer.h"
#include "yas_audio_engine_au.h"
#include "yas_audio_engine_node.h"
#include "yas_audio_unit.h"

using namespace yas;

#pragma mark - impl

struct audio::engine::au_mixer::impl : base::impl {
    audio::engine::au _au;

    impl()
        : _au({.acd =
                   AudioComponentDescription{
                       .componentType = kAudioUnitType_Mixer,
                       .componentSubType = kAudioUnitSubType_MultiChannelMixer,
                       .componentManufacturer = kAudioUnitManufacturer_Apple,
                       .componentFlags = 0,
                       .componentFlagsMask = 0,
                   },
               .node_args = {.input_bus_count = std::numeric_limits<uint32_t>::max(), .output_bus_count = 1}}) {
    }

    void prepare(audio::engine::au_mixer const &au_mixer) {
        this->_connections_observer = this->_au.chain(au::method::will_update_connections)
                                          .perform([weak_au_mixer = to_weak(au_mixer)](auto const &) {
                                              if (auto au_mixer = weak_au_mixer.lock()) {
                                                  au_mixer.impl_ptr<impl>()->update_unit_mixer_connections();
                                              }
                                          })
                                          .end();
    }

   private:
    void update_unit_mixer_connections() {
        auto &connections = _au.node().input_connections();
        if (connections.size() > 0) {
            auto last = connections.end();
            --last;
            if (auto unit = _au.unit()) {
                auto &pair = *last;
                unit.set_element_count(pair.first + 1, kAudioUnitScope_Input);
            }
        }
    }

    chaining::any_observer _connections_observer = nullptr;
};

#pragma mark - main

audio::engine::au_mixer::au_mixer() : base(std::make_unique<impl>()) {
}

audio::engine::au_mixer::au_mixer(std::nullptr_t) : base(nullptr) {
}

audio::engine::au_mixer::~au_mixer() = default;

void audio::engine::au_mixer::set_output_volume(float const volume, uint32_t const bus_idx) {
    au().set_output_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::engine::au_mixer::output_volume(uint32_t const bus_idx) const {
    return au().output_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::engine::au_mixer::set_output_pan(float const pan, uint32_t const bus_idx) {
    au().set_output_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::engine::au_mixer::output_pan(uint32_t const bus_idx) const {
    return au().output_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::engine::au_mixer::set_input_volume(float const volume, uint32_t const bus_idx) {
    au().set_input_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::engine::au_mixer::input_volume(uint32_t const bus_idx) const {
    return au().input_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::engine::au_mixer::set_input_pan(float const pan, uint32_t const bus_idx) {
    au().set_input_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::engine::au_mixer::input_pan(uint32_t const bus_idx) const {
    return au().input_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::engine::au_mixer::set_input_enabled(bool const enabled, uint32_t const bus_idx) {
    au().set_input_parameter_value(kMultiChannelMixerParam_Enable, enabled ? 1.0f : 0.0f, bus_idx);
}

bool audio::engine::au_mixer::input_enabled(uint32_t const bus_idx) const {
    return au().input_parameter_value(kMultiChannelMixerParam_Enable, bus_idx) != 0.0f;
}

audio::engine::au const &audio::engine::au_mixer::au() const {
    return impl_ptr<impl>()->_au;
}

audio::engine::au &audio::engine::au_mixer::au() {
    return impl_ptr<impl>()->_au;
}
