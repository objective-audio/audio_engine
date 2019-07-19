//
//  yas_audio_au_mixer.cpp
//

#include "yas_audio_engine_au_mixer.h"
#include "yas_audio_engine_au.h"
#include "yas_audio_engine_node.h"
#include "yas_audio_unit.h"

using namespace yas;

audio::engine::au_mixer::au_mixer()
    : _au(make_au({.acd =
                       AudioComponentDescription{
                           .componentType = kAudioUnitType_Mixer,
                           .componentSubType = kAudioUnitSubType_MultiChannelMixer,
                           .componentManufacturer = kAudioUnitManufacturer_Apple,
                           .componentFlags = 0,
                           .componentFlagsMask = 0,
                       },
                   .node_args = {.input_bus_count = std::numeric_limits<uint32_t>::max(), .output_bus_count = 1}})) {
}

void audio::engine::au_mixer::set_output_volume(float const volume, uint32_t const bus_idx) {
    this->au().set_output_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::engine::au_mixer::output_volume(uint32_t const bus_idx) const {
    return this->au().output_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::engine::au_mixer::set_output_pan(float const pan, uint32_t const bus_idx) {
    this->au().set_output_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::engine::au_mixer::output_pan(uint32_t const bus_idx) const {
    return this->au().output_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::engine::au_mixer::set_input_volume(float const volume, uint32_t const bus_idx) {
    this->au().set_input_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::engine::au_mixer::input_volume(uint32_t const bus_idx) const {
    return this->au().input_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::engine::au_mixer::set_input_pan(float const pan, uint32_t const bus_idx) {
    this->au().set_input_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::engine::au_mixer::input_pan(uint32_t const bus_idx) const {
    return this->au().input_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::engine::au_mixer::set_input_enabled(bool const enabled, uint32_t const bus_idx) {
    this->au().set_input_parameter_value(kMultiChannelMixerParam_Enable, enabled ? 1.0f : 0.0f, bus_idx);
}

bool audio::engine::au_mixer::input_enabled(uint32_t const bus_idx) const {
    return this->au().input_parameter_value(kMultiChannelMixerParam_Enable, bus_idx) != 0.0f;
}

audio::engine::au const &audio::engine::au_mixer::au() const {
    return *this->_au;
}

audio::engine::au &audio::engine::au_mixer::au() {
    return *this->_au;
}

void audio::engine::au_mixer::prepare() {
    this->_connections_observer = this->_au->chain(au::method::will_update_connections)
                                      .perform([weak_au_mixer = to_weak(shared_from_this())](auto const &) {
                                          if (auto au_mixer = weak_au_mixer.lock()) {
                                              au_mixer->_update_unit_mixer_connections();
                                          }
                                      })
                                      .end();
}

void audio::engine::au_mixer::_update_unit_mixer_connections() {
    auto &connections = this->_au->node().manageable()->input_connections();
    if (connections.size() > 0) {
        auto last = connections.end();
        --last;
        if (auto unit = this->_au->unit()) {
            auto &pair = *last;
            unit->set_element_count(pair.first + 1, kAudioUnitScope_Input);
        }
    }
}

namespace yas::audio::engine {
struct au_mixer_factory : au_mixer {
    void prepare() {
        this->au_mixer::prepare();
    }
};
}  // namespace yas::audio::engine

std::shared_ptr<audio::engine::au_mixer> audio::engine::make_au_mixer() {
    auto shared = std::make_shared<au_mixer_factory>();
    shared->prepare();
    return shared;
}
