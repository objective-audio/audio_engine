//
//  yas_audio_engine_avf_au_mixer.h
//

#pragma once

#include "yas_audio_engine_avf_au.h"

namespace yas::audio::engine {
struct avf_au_mixer final {
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

    static avf_au_mixer_ptr make_shared();

    avf_au_ptr const &au() const;

   private:
    avf_au_ptr _au;
    std::optional<chaining::any_observer_ptr> _connections_observer = std::nullopt;

    avf_au_mixer();

    void _prepare(avf_au_mixer_ptr const &);
    void _update_unit_mixer_connections();
};
}  // namespace yas::audio::engine
