//
//  yas_audio_engine_kernel_protocol.h
//

#pragma once

#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
struct manageable_kernel {
    virtual ~manageable_kernel() = default;

    virtual void set_input_connections(audio::engine::connection_wmap connections) = 0;
    virtual void set_output_connections(audio::engine::connection_wmap connections) = 0;

    static manageable_kernel_ptr cast(manageable_kernel_ptr const &kernel) {
        return kernel;
    }
};
}  // namespace yas::audio::engine
