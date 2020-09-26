//
//  yas_audio_graph_avf_au_mixer.h
//

#pragma once

#include <audio/yas_audio_graph_avf_au.h>

namespace yas::audio {
struct graph_avf_au_mixer final {
    void set_output_volume(float const volume, uint32_t const bus_idx);
    float output_volume(uint32_t const bus_idx) const;
    void set_output_pan(float const pan, uint32_t const bus_idx);
    float output_pan(uint32_t const bus_idx) const;

    void set_input_volume(float const volume, uint32_t const bus_idx);
    float input_volume(uint32_t const bus_idx) const;
    void set_input_pan(float const pan, uint32_t const bus_idx);
    float input_pan(uint32_t const bus_idx) const;

    void set_input_enabled(bool const enabled, uint32_t const bus_idx);
    bool input_enabled(uint32_t const bus_idx) const;

    static graph_avf_au_mixer_ptr make_shared();

    graph_avf_au_ptr const &raw_au() const;

   private:
    graph_avf_au_ptr _raw_au;
    std::optional<chaining::any_observer_ptr> _connections_observer = std::nullopt;

    graph_avf_au_mixer();

    void _update_unit_mixer_connections();
};
}  // namespace yas::audio
