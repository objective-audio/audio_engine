//
//  yas_audio_engine_kernel_protocol.h
//

#pragma once

#include <cpp_utils/yas_protocol.h>

namespace yas::audio::engine {
struct manageable_kernel {
    virtual ~manageable_kernel() = default;

    virtual void set_input_connections(audio::engine::connection_wmap connections) = 0;
    virtual void set_output_connections(audio::engine::connection_wmap connections) = 0;
};
}  // namespace yas::audio::engine
