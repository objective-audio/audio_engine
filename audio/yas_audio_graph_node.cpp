//
//  yas_audio_node.cpp
//

#include "yas_audio_graph_node.h"

#include <cpp_utils/yas_result.h>
#include <cpp_utils/yas_stl_utils.h>

#include "yas_audio_graph.h"
#include "yas_audio_graph_connection.h"
#include "yas_audio_time.h"

using namespace yas;
using namespace yas::audio;

#pragma mark - graph_node

graph_node::graph_node(graph_node_args &&args)
    : _input_bus_count(args.input_bus_count),
      _output_bus_count(args.output_bus_count),
      _is_input_renderable(args.input_renderable),
      _override_output_bus_idx(args.override_output_bus_idx) {
}

graph_node::~graph_node() = default;

void graph_node::reset() {
    if (this->_will_reset_handler) {
        this->_will_reset_handler();
    }

    this->_input_connections.clear();
    this->_output_connections.clear();

    this->update_rendering();
}

graph_connection_ptr graph_node::input_connection(uint32_t const bus_idx) const {
    if (this->_input_connections.count(bus_idx) > 0) {
        return this->_input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

graph_connection_ptr graph_node::output_connection(uint32_t const bus_idx) const {
    if (this->_output_connections.count(bus_idx) > 0) {
        return this->_output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

graph_connection_wmap const &graph_node::input_connections() const {
    return this->_input_connections;
}

graph_connection_wmap const &graph_node::output_connections() const {
    return this->_output_connections;
}

std::optional<format> graph_node::input_format(uint32_t const bus_idx) const {
    if (auto connection = this->input_connection(bus_idx)) {
        return connection->format();
    }
    return std::nullopt;
}

std::optional<format> graph_node::output_format(uint32_t const bus_idx) const {
    if (auto connection = this->output_connection(bus_idx)) {
        return connection->format();
    }
    return std::nullopt;
}

bus_result_t graph_node::next_available_input_bus() const {
    auto key = min_empty_key(this->_input_connections);
    if (key && *key < this->input_bus_count()) {
        return key;
    }
    return std::nullopt;
}

bus_result_t graph_node::next_available_output_bus() const {
    auto key = min_empty_key(this->_output_connections);
    if (key && *key < this->output_bus_count()) {
        auto &override_bus_idx = this->_override_output_bus_idx;
        if (override_bus_idx && *key == 0) {
            return *override_bus_idx;
        }
        return key;
    }
    return std::nullopt;
}

bool graph_node::is_available_input_bus(uint32_t const bus_idx) const {
    if (bus_idx >= this->input_bus_count()) {
        return false;
    }
    return this->_input_connections.count(bus_idx) == 0;
}

bool graph_node::is_available_output_bus(uint32_t const bus_idx) const {
    auto &override_bus_idx = this->_override_output_bus_idx;
    auto target_bus_idx = (override_bus_idx && *override_bus_idx == bus_idx) ? 0 : bus_idx;
    if (target_bus_idx >= this->output_bus_count()) {
        return false;
    }
    return this->_output_connections.count(target_bus_idx) == 0;
}

graph_ptr graph_node::graph() const {
    return this->_weak_graph.lock();
}

uint32_t graph_node::input_bus_count() const {
    return this->_input_bus_count;
}

uint32_t graph_node::output_bus_count() const {
    return this->_output_bus_count;
}

bool graph_node::is_input_renderable() const {
    return this->_is_input_renderable;
}

void graph_node::set_render_handler(node_render_f handler) {
    this->_render_handler = std::move(handler);
}

node_render_f const graph_node::render_handler() const {
    if (this->_render_handler) {
        return this->_render_handler;
    } else {
        static node_render_f const _empty_handler = [](auto const &) {};
        return _empty_handler;
    }
}

void graph_node::add_connection(graph_connection_ptr const &connection) {
    auto weak_connection = to_weak(connection);
    if (connection->destination_node().get() == this) {
        auto bus_idx = connection->destination_bus();
        this->_input_connections.insert(std::make_pair(bus_idx, weak_connection));
    } else if (connection->source_node().get() == this) {
        auto bus_idx = connection->source_bus();
        this->_output_connections.insert(std::make_pair(bus_idx, weak_connection));
    } else {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : connection does not exist in a node.");
    }

    this->update_rendering();
}

void graph_node::remove_input_connection(uint32_t const dst_bus) {
    this->_input_connections.erase(dst_bus);
    this->update_rendering();
}

void graph_node::remove_output_connection(uint32_t const src_bus) {
    this->_output_connections.erase(src_bus);
    this->update_rendering();
}

void graph_node::set_graph(graph_wptr const &graph) {
    this->_weak_graph = graph;
}

void graph_node::update_rendering() {
    if (this->_update_rendering_handler) {
        this->_update_rendering_handler();
    }
}

void graph_node::set_setup_handler(graph_node_f &&handler) {
    this->_setup_handler = std::move(handler);
}

void graph_node::set_teardown_handler(graph_node_f &&handler) {
    this->_teardown_handler = std::move(handler);
}

void graph_node::set_prepare_rendering_handler(graph_node_f &&handler) {
    this->_prepare_rendering_handler = std::move(handler);
}

void graph_node::set_update_rendering_handler(graph_node_f &&handler) {
    this->_update_rendering_handler = std::move(handler);
}

void graph_node::set_will_reset_handler(graph_node_f &&handler) {
    this->_will_reset_handler = std::move(handler);
}

graph_node_f const &graph_node::setup_handler() const {
    return this->_setup_handler;
}

graph_node_f const &graph_node::teardown_handler() const {
    return this->_teardown_handler;
}

void graph_node::prepare_rendering() {
    if (this->_prepare_rendering_handler) {
        this->_prepare_rendering_handler();
    }
}

graph_node_ptr graph_node::make_shared(graph_node_args args) {
    return graph_node_ptr(new graph_node{std::move(args)});
}
