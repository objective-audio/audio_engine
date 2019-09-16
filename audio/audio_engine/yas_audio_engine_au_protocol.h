//
//  yas_audio_engine_au_protocol.h
//

#pragma once

#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
struct manageable_au {
    virtual ~manageable_au() = default;

    virtual void prepare_unit() = 0;
    virtual void prepare_parameters() = 0;
    virtual void reload_unit() = 0;

    static manageable_au_ptr cast(manageable_au_ptr const &au) {
        return au;
    }
};
}  // namespace yas::audio::engine
