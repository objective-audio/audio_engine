//
//  yas_audio_graph_avf_au_mixer.h
//

#pragma once

#include <audio-engine/graph/yas_audio_graph_avf_au.h>

namespace yas::audio {
struct graph_avf_au_mixer final {
    void set_output_volume(float const volume, uint32_t const bus_idx);
    [[nodiscard]] float output_volume(uint32_t const bus_idx) const;
    void set_output_pan(float const pan, uint32_t const bus_idx);
    [[nodiscard]] float output_pan(uint32_t const bus_idx) const;

    void set_input_volume(float const volume, uint32_t const bus_idx);
    [[nodiscard]] float input_volume(uint32_t const bus_idx) const;
    void set_input_pan(float const pan, uint32_t const bus_idx);
    [[nodiscard]] float input_pan(uint32_t const bus_idx) const;

    void set_input_enabled(bool const enabled, uint32_t const bus_idx);
    [[nodiscard]] bool input_enabled(uint32_t const bus_idx) const;

    [[nodiscard]] static graph_avf_au_mixer_ptr make_shared();

    graph_avf_au_ptr const raw_au;

   private:
    observing::cancellable_ptr _connections_canceller;

    graph_avf_au_mixer();

    void _update_unit_mixer_connections();
};
}  // namespace yas::audio
