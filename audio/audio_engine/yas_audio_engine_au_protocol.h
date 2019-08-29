//
//  yas_audio_engine_au_protocol.h
//

#pragma once

#include <cpp_utils/yas_protocol.h>

namespace yas::audio::engine {
struct manageable_au {
    virtual ~manageable_au() = default;

    virtual void prepare_unit() = 0;
    virtual void prepare_parameters() = 0;
    virtual void reload_unit() = 0;
};

using manageable_au_ptr = std::shared_ptr<manageable_au>;
}  // namespace yas::audio::engine
