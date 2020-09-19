//
//  yas_audio_graph_connection.h
//

#pragma once

#include <audio/yas_audio_format.h>
#include <audio/yas_audio_graph_connection_protocol.h>
#include <audio/yas_audio_ptr.h>

namespace yas::audio {
struct graph_connection : graph_node_removable, renderable_graph_connection {
    virtual ~graph_connection();

    uint32_t const source_bus;
    uint32_t const destination_bus;
    audio::graph_node_ptr source_node() const;
    audio::graph_node_ptr destination_node() const;
    audio::format const format;

   private:
    mutable std::recursive_mutex _mutex;
    std::weak_ptr<graph_node> _source_node;
    std::weak_ptr<graph_node> _destination_node;
    std::weak_ptr<graph_connection> _weak_connection;

    graph_connection(audio::graph_node_ptr const &source_node, uint32_t const source_bus_idx,
                     audio::graph_node_ptr const &destination_node, uint32_t const destination_bus_idx,
                     audio::format const &format);

    graph_connection(graph_connection const &) = delete;
    graph_connection(graph_connection &&) = delete;
    graph_connection &operator=(graph_connection const &) = delete;
    graph_connection &operator=(graph_connection &&) = delete;

    void remove_nodes() override;
    void remove_source_node() override;
    void remove_destination_node() override;

    void _prepare(graph_connection_ptr const &);

   public:
    static graph_connection_ptr make_shared(audio::graph_node_ptr const &src_node, uint32_t const src_bus,
                                            audio::graph_node_ptr const &dst_node, uint32_t const dst_bus,
                                            audio::format const &format);
};
}  // namespace yas::audio
