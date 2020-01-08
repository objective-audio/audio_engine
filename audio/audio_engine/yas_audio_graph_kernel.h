//
//  yas_audio_graph_kernel.h
//

#pragma once

#include <any>
#include "yas_audio_graph_kernel_protocol.h"
#include "yas_audio_ptr.h"

namespace yas::audio {
struct graph_kernel : manageable_graph_kernel {
    virtual ~graph_kernel();

    audio::graph_connection_smap input_connections() const;
    audio::graph_connection_smap output_connections() const;
    audio::graph_connection_ptr input_connection(uint32_t const bus_idx) const;
    audio::graph_connection_ptr output_connection(uint32_t const bus_idx) const;

    std::optional<std::any> decorator = std::nullopt;

    static graph_kernel_ptr make_shared();

   private:
    std::weak_ptr<graph_kernel> _weak_kernel;

    graph_kernel();

    void set_input_connections(audio::graph_connection_wmap connections) override;
    void set_output_connections(audio::graph_connection_wmap connections) override;

    graph_connection_wmap _input_connections;
    graph_connection_wmap _output_connections;
};
}  // namespace yas::audio
