//
//  yas_audio_graph_avf_au_mixer.cpp
//

#include "yas_audio_graph_avf_au_mixer.h"

using namespace yas;

audio::graph_avf_au_mixer::graph_avf_au_mixer()
    : raw_au(graph_avf_au::make_shared(
          {.acd =
               AudioComponentDescription{
                   .componentType = kAudioUnitType_Mixer,
                   .componentSubType = kAudioUnitSubType_MultiChannelMixer,
                   .componentManufacturer = kAudioUnitManufacturer_Apple,
                   .componentFlags = 0,
                   .componentFlagsMask = 0,
               },
           .node_args = {.input_bus_count = std::numeric_limits<uint32_t>::max(), .output_bus_count = 1}})) {
    this->_connections_observer =
        this->raw_au->connection_chain()
            .guard([](auto const &method) { return method == graph_avf_au::connection_method::will_update; })
            .perform([this](auto const &) { this->_update_unit_mixer_connections(); })
            .end();
}

void audio::graph_avf_au_mixer::set_output_volume(float const volume, uint32_t const bus_idx) {
    this->raw_au->raw_au->set_output_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::graph_avf_au_mixer::output_volume(uint32_t const bus_idx) const {
    return this->raw_au->raw_au->output_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::graph_avf_au_mixer::set_output_pan(float const pan, uint32_t const bus_idx) {
    this->raw_au->raw_au->set_output_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::graph_avf_au_mixer::output_pan(uint32_t const bus_idx) const {
    return this->raw_au->raw_au->output_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::graph_avf_au_mixer::set_input_volume(float const volume, uint32_t const bus_idx) {
    this->raw_au->raw_au->set_input_parameter_value(kMultiChannelMixerParam_Volume, volume, bus_idx);
}

float audio::graph_avf_au_mixer::input_volume(uint32_t const bus_idx) const {
    return this->raw_au->raw_au->input_parameter_value(kMultiChannelMixerParam_Volume, bus_idx);
}

void audio::graph_avf_au_mixer::set_input_pan(float const pan, uint32_t const bus_idx) {
    this->raw_au->raw_au->set_input_parameter_value(kMultiChannelMixerParam_Pan, pan, bus_idx);
}

float audio::graph_avf_au_mixer::input_pan(uint32_t const bus_idx) const {
    return this->raw_au->raw_au->input_parameter_value(kMultiChannelMixerParam_Pan, bus_idx);
}

void audio::graph_avf_au_mixer::set_input_enabled(bool const enabled, uint32_t const bus_idx) {
    this->raw_au->raw_au->set_input_parameter_value(kMultiChannelMixerParam_Enable, enabled ? 1.0f : 0.0f, bus_idx);
}

bool audio::graph_avf_au_mixer::input_enabled(uint32_t const bus_idx) const {
    return this->raw_au->raw_au->input_parameter_value(kMultiChannelMixerParam_Enable, bus_idx) != 0.0f;
}

void audio::graph_avf_au_mixer::_update_unit_mixer_connections() {
    auto const &connections = manageable_graph_node::cast(this->raw_au->node)->input_connections();
    if (connections.size() > 0) {
        auto last = connections.end();
        --last;

        auto &pair = *last;
        this->raw_au->raw_au->set_input_bus_count(pair.first + 1);
    }
}

audio::graph_avf_au_mixer_ptr audio::graph_avf_au_mixer::make_shared() {
    auto shared = std::shared_ptr<graph_avf_au_mixer>(new graph_avf_au_mixer{});
    return shared;
}
