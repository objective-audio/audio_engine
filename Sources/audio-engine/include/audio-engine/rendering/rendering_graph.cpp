//
//  rendering_graph.cpp
//

#include "rendering_graph.h"

#include <audio-engine/graph/graph_connection.h>
#include <audio-engine/graph/graph_node.h>
#include <cpp-utils/stl_utils.h>

using namespace yas;
using namespace yas::audio;

namespace yas::audio {

std::vector<std::unique_ptr<rendering_node>> make_rendering_nodes(renderable_graph_node_ptr const &node) {
    node->prepare_rendering();

    assert(node->render_handler());

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

std::unique_ptr<rendering_output_node> make_rendering_output_node(renderable_graph_node_ptr const &output_node) {
    if (output_node->input_connections().empty()) {
        return nullptr;
    }

    auto const &pair = *output_node->input_connections().begin();

    if (pair.second.expired()) {
        return nullptr;
    }

    renderable_graph_connection_ptr const connection = pair.second.lock();
    renderable_graph_node_ptr const src_node = connection->source_node();

    auto nodes = make_rendering_nodes(src_node);

    if (nodes.empty()) {
        return nullptr;
    }

    return std::make_unique<rendering_output_node>(
        std::move(nodes), rendering_connection{connection->source_bus(), nodes.at(0).get(), connection->format()});
}

std::unique_ptr<rendering_input_node> make_rendering_input_node(renderable_graph_node_ptr const &input_node) {
    if (input_node->output_connections().empty()) {
        return nullptr;
    }

    auto const &pair = *input_node->output_connections().begin();

    if (pair.second.expired()) {
        return nullptr;
    }

    renderable_graph_connection_ptr const connection = pair.second.lock();
    renderable_graph_node_ptr const dst_node = connection->destination_node();

    if (dst_node->is_input_renderable()) {
        dst_node->prepare_rendering();
        return std::make_unique<rendering_input_node>(connection->format(), dst_node->render_handler());
    } else {
        return nullptr;
    }
}
}  // namespace yas::audio

rendering_graph::rendering_graph(renderable_graph_node_ptr const &output_node,
                                 renderable_graph_node_ptr const &input_node)
    : _output_node(make_rendering_output_node(output_node)), _input_node(make_rendering_input_node(input_node)) {
}

rendering_output_node const *rendering_graph::output_node() const {
    return this->_output_node ? this->_output_node.get() : nullptr;
}

rendering_input_node const *rendering_graph::input_node() const {
    return this->_input_node ? this->_input_node.get() : nullptr;
}
