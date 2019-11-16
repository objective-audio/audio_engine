//
//  yas_audio_engine_avf_au_protocol.h
//

#pragma once

#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
struct manageable_avf_au {
    virtual ~manageable_avf_au() = default;

    virtual void initialize_raw_unit() = 0;
    virtual void uninitialize_raw_unit() = 0;

    static manageable_avf_au_ptr cast(manageable_avf_au_ptr const &au) {
        return au;
    }
};
}  // namespace yas::audio::engine
