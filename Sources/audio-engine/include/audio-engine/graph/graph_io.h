//
//  graph_io.h
//

#pragma once

#include <audio-engine/common/ptr.h>
#include <audio-engine/graph/graph_io_protocol.h>
#include <audio-engine/graph/graph_node.h>
#include <audio-engine/io/io_device.h>

namespace yas::audio {
class graph_input_context;

struct graph_io : manageable_graph_io {
    virtual ~graph_io();

    audio::graph_node_ptr const output_node;
    audio::graph_node_ptr const input_node;

    [[nodiscard]] audio::io_ptr const &raw_io() override;

    [[nodiscard]] static graph_io_ptr make_shared(audio::io_ptr const &);

   private:
    audio::io_ptr const _raw_io;
    std::shared_ptr<graph_input_context> _input_context = nullptr;

    graph_io(audio::io_ptr const &);

    graph_io(graph_io &&) = delete;
    graph_io &operator=(graph_io &&) = delete;
    graph_io(graph_io const &) = delete;
    graph_io &operator=(graph_io const &) = delete;

    void _prepare(graph_io_ptr const &);
    bool _validate_connections();

    void update_rendering() override;
    void clear_rendering() override;
};
}  // namespace yas::audio
