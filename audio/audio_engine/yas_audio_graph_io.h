//
//  yas_audio_graph_io.h
//

#pragma once

#include <audio/yas_audio_graph_io_protocol.h>
#include <audio/yas_audio_graph_node.h>
#include <audio/yas_audio_io_device.h>
#include <audio/yas_audio_ptr.h>
#include <chaining/yas_chaining_umbrella.h>

namespace yas::audio {
struct graph_io : manageable_graph_io {
    virtual ~graph_io();

    audio::graph_node_ptr const &node() const;
    audio::graph_node_ptr const &output_node() const;
    audio::graph_node_ptr const &input_node() const;

    audio::io_ptr const &raw_io() override;

    static graph_io_ptr make_shared(audio::io_ptr const &);

   private:
    std::weak_ptr<graph_io> _weak_graph_io;
    audio::graph_node_ptr _node;
    audio::io_ptr _raw_io;
    chaining::any_observer_ptr _connections_observer;

    graph_io(audio::io_ptr const &);

    graph_io(graph_io &&) = delete;
    graph_io &operator=(graph_io &&) = delete;
    graph_io(graph_io const &) = delete;
    graph_io &operator=(graph_io const &) = delete;

    void _prepare(graph_io_ptr const &);
    void _update_io_connections();
    bool _validate_connections();
};
}  // namespace yas::audio
