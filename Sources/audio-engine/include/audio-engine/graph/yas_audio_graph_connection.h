//
//  yas_audio_graph_connection.h
//

#pragma once

#include <audio-engine/common/yas_audio_ptr.h>
#include <audio-engine/format/yas_audio_format.h>
#include <audio-engine/graph/yas_audio_graph_connection_protocol.h>

namespace yas::audio {
struct graph_connection : graph_node_removable, renderable_graph_connection {
    virtual ~graph_connection();

    [[nodiscard]] uint32_t source_bus() const override;
    [[nodiscard]] uint32_t destination_bus() const;
    [[nodiscard]] audio::graph_node_ptr source_node() const override;
    [[nodiscard]] audio::graph_node_ptr destination_node() const override;
    [[nodiscard]] audio::format const &format() const override;

   private:
    uint32_t const _source_bus;
    uint32_t const _destination_bus;
    std::weak_ptr<graph_node> _source_node;
    std::weak_ptr<graph_node> _destination_node;
    std::weak_ptr<graph_connection> _weak_connection;
    audio::format const _format;

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

   public:
    static graph_connection_ptr make_shared(audio::graph_node_ptr const &src_node, uint32_t const src_bus,
                                            audio::graph_node_ptr const &dst_node, uint32_t const dst_bus,
                                            audio::format const &format);
};
}  // namespace yas::audio
