//
//  yas_audio_rendering_graph.cpp
//

#include "yas_audio_rendering_graph.h"

#include <cpp_utils/yas_stl_utils.h>

using namespace yas;

namespace yas::audio {

std::vector<std::unique_ptr<rendering_node>> make_rendering_nodes(graph_node_ptr const &node) {
    std::vector<std::unique_ptr<rendering_node>> sub_nodes;
    rendering_connection_map connections;

    for (auto const &pair : node->input_connections()) {
        uint32_t const dst_bus_idx = pair.first;
        graph_connection_ptr const connection = pair.second.lock();
        graph_node_ptr const src_node = connection->source_node();

        std::vector<std::unique_ptr<rendering_node>> src_rendering_nodes = make_rendering_nodes(src_node);

        connections.emplace(dst_bus_idx, rendering_connection{connection->source_bus, src_rendering_nodes.at(0).get(),
                                                              connection->format});

        yas::move_back_insert(sub_nodes, std::move(src_rendering_nodes));
    }

    std::vector<std::unique_ptr<rendering_node>> result;
    result.emplace_back(std::make_unique<rendering_node>([](auto const &) {}, std::move(connections)));

    if (!sub_nodes.empty()) {
        yas::move_back_insert(result, std::move(sub_nodes));
    }

    return {};
}
}  // namespace yas::audio

audio::rendering_graph::rendering_graph(graph_node_ptr const &end_node) : nodes(make_rendering_nodes(end_node)) {
}
