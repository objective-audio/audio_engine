//
//  yas_audio_graph_kernel_protocol.h
//

#pragma once

#include "yas_audio_ptr.h"

namespace yas::audio {
struct manageable_graph_kernel {
    virtual ~manageable_graph_kernel() = default;

    virtual void set_input_connections(audio::graph_connection_wmap connections) = 0;
    virtual void set_output_connections(audio::graph_connection_wmap connections) = 0;

    static manageable_graph_kernel_ptr cast(manageable_graph_kernel_ptr const &kernel) {
        return kernel;
    }
};
}  // namespace yas::audio
