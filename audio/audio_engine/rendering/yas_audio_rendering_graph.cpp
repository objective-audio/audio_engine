//
//  yas_audio_rendering_graph.cpp
//

#include "yas_audio_rendering_graph.h"

#include <audio/yas_audio_graph_connection.h>
#include <audio/yas_audio_graph_node.h>
#include <cpp_utils/yas_stl_utils.h>

using namespace yas;

namespace yas::audio {

std::vector<std::unique_ptr<rendering_node>> make_rendering_nodes(renderable_graph_node_ptr const &node) {
    std::vector<std::unique_ptr<rendering_node>> sub_nodes;
    rendering_connection_map connections;

    for (auto const &pair : node->input_connections()) {
        if (pair.second.expired()) {
            continue;
        }

        uint32_t const dst_bus_idx = pair.first;
        renderable_graph_connection_ptr const connection = pair.second.lock();
        renderable_graph_node_ptr const src_node = connection->source_node();

        std::vector<std::unique_ptr<rendering_node>> src_rendering_nodes = make_rendering_nodes(src_node);

        connections.emplace(dst_bus_idx, rendering_connection{connection->source_bus(), src_rendering_nodes.at(0).get(),
                                                              connection->format()});

        yas::move_back_insert(sub_nodes, std::move(src_rendering_nodes));
    }

    std::vector<std::unique_ptr<rendering_node>> result;
    result.emplace_back(std::make_unique<rendering_node>(node->render_handler(), std::move(connections)));

    if (!sub_nodes.empty()) {
        yas::move_back_insert(result, std::move(sub_nodes));
    }

    return result;
}

std::vector<std::unique_ptr<rendering_node>> make_input_rendering_nodes(renderable_graph_node_ptr const &input_node) {
    for (auto const &pair : input_node->output_connections()) {
        if (pair.second.expired()) {
            continue;
        }

        renderable_graph_connection_ptr const connection = pair.second.lock();
        renderable_graph_node_ptr const dst_node = connection->destination_node();

        if (dst_node->is_input_renderable()) {
            renderable_graph_node_ptr const src_node = connection->source_node();
            auto src_rendering_node =
                std::make_unique<rendering_node>(src_node->render_handler(), rendering_connection_map{});
            rendering_connection src_connection{connection->source_bus(), src_rendering_node.get(),
                                                connection->format()};

            std::vector<std::unique_ptr<rendering_node>> result;

            result.emplace_back(std::make_unique<rendering_node>(
                dst_node->render_handler(), rendering_connection_map{{pair.first, std::move(src_connection)}}));
            result.emplace_back(std::move(src_rendering_node));

            return result;
        }
    }

    return {};
}
}  // namespace yas::audio

audio::rendering_graph::rendering_graph(renderable_graph_node_ptr const &output_node,
                                        renderable_graph_node_ptr const &input_node)
    : _nodes(make_rendering_nodes(output_node)), _input_nodes(make_input_rendering_nodes(input_node)) {
}

std::vector<std::unique_ptr<audio::rendering_node>> const &audio::rendering_graph::nodes() const {
    return this->_nodes;
}

std::vector<std::unique_ptr<audio::rendering_node>> const &audio::rendering_graph::input_nodes() const {
    return this->_input_nodes;
}
