//
//  yas_audio_engine_avf_au_mixer.h
//

#pragma once

#include "yas_audio_engine_avf_au.h"

namespace yas::audio::engine {
struct avf_au_mixer final {
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
