//
//  yas_audio_graph.cpp
//

#include "yas_audio_graph.h"
#include <AVFoundation/AVFoundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <cpp_utils/yas_result.h>
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_graph_io.h"
#include "yas_audio_graph_node.h"
#include "yas_audio_io.h"

#if TARGET_OS_IPHONE
#include "yas_audio_ios_device.h"
#elif TARGET_OS_MAC
#include "yas_audio_mac_device.h"
#endif

using namespace yas;

audio::graph::graph() = default;

audio::graph::~graph() = default;

audio::graph_connection_ptr audio::graph::connect(audio::graph_node_ptr const &source_node,
                                                  audio::graph_node_ptr const &destination_node,
                                                  audio::format const &format) {
    auto source_bus_result = source_node->next_available_output_bus();
    auto destination_bus_result = destination_node->next_available_input_bus();

    if (!source_bus_result || !destination_bus_result) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : bus is not available.");
    }

    return connect(source_node, destination_node, *source_bus_result, *destination_bus_result, format);
}

audio::graph_connection_ptr audio::graph::connect(audio::graph_node_ptr const &src_node,
                                                  audio::graph_node_ptr const &dst_node, uint32_t const src_bus_idx,
                                                  uint32_t const dst_bus_idx, audio::format const &format) {
    if (!src_node->is_available_output_bus(src_bus_idx)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : output bus(" + std::to_string(src_bus_idx) +
                                    ") is not available.");
    }

    if (!dst_node->is_available_input_bus(dst_bus_idx)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : input bus(" + std::to_string(dst_bus_idx) +
                                    ") is not available.");
    }

    if (!this->_node_exists(src_node)) {
        this->_attach_node(src_node);
    }

    if (!this->_node_exists(dst_node)) {
        this->_attach_node(dst_node);
    }

    auto connection = graph_connection::make_shared(src_node, src_bus_idx, dst_node, dst_bus_idx, format);

    this->_connections.insert(connection);

    if (this->is_running()) {
        this->_add_connection_to_nodes(connection);
        this->_update_io_rendering();
    }

    return connection;
}

void audio::graph::disconnect(graph_connection_ptr const &connection) {
    std::vector<graph_node_ptr> update_nodes{connection->source_node(), connection->destination_node()};

    this->_remove_connection_from_nodes(connection);
    audio::graph_node_removable::cast(connection)->remove_nodes();

    for (auto &node : update_nodes) {
        this->_detach_node_if_unused(node);
    }

    this->_connections.erase(connection);
    
    if (this->is_running() && this->_io.has_value()) {
        audio::manageable_graph_io::cast(this->_io.value())->update_rendering();
    }
    
}

void audio::graph::disconnect(audio::graph_node_ptr const &node) {
    if (this->_node_exists(node)) {
        this->_detach_node(node);
    }
}

void audio::graph::disconnect_input(audio::graph_node_ptr const &node) {
    this->_disconnect_node_with_predicate(
        [&node](graph_connection const &connection) { return (connection.destination_node() == node); });
}

void audio::graph::disconnect_input(audio::graph_node_ptr const &node, uint32_t const bus_idx) {
    this->_disconnect_node_with_predicate([&node, bus_idx](auto const &connection) {
        return (connection.destination_node() == node && connection.destination_bus() == bus_idx);
    });
}

void audio::graph::disconnect_output(audio::graph_node_ptr const &node) {
    this->_disconnect_node_with_predicate(
        [&node](graph_connection const &connection) { return (connection.source_node() == node); });
}

void audio::graph::disconnect_output(audio::graph_node_ptr const &node, uint32_t const bus_idx) {
    this->_disconnect_node_with_predicate([&node, bus_idx](auto const &connection) {
        return (connection.source_node() == node && connection.source_bus() == bus_idx);
    });
}

audio::graph_io_ptr const &audio::graph::add_io(std::optional<io_device_ptr> const &device) {
    if (!this->_io) {
        audio::io_ptr const raw_io = audio::io::make_shared(device);
        audio::graph_io_ptr const io = audio::graph_io::make_shared(raw_io);

        this->_io_observer = raw_io->running_chain()
                                 .perform([this](auto const &method) {
                                     switch (method) {
                                         case audio::io::running_method::will_start:
                                             this->_setup_rendering();
                                             break;
                                         case audio::io::running_method::did_stop:
                                             this->_dispose_rendering();
                                             break;
                                     }
                                 })
                                 .end();

        this->_io = io;
    }

    return this->_io.value();
}

void audio::graph::remove_io() {
    if (this->_io) {
        this->_io_observer = std::nullopt;
        this->_io = std::nullopt;
    }
}

std::optional<audio::graph_io_ptr> const &audio::graph::io() const {
    return this->_io;
}

audio::graph::start_result_t audio::graph::start_render() {
    if (this->is_running()) {
        return start_result_t(start_error_t::already_running);
    }

    if (auto const &graph_io = this->_io) {
        manageable_graph_io::cast(graph_io.value())->raw_io()->start();
    }

    return start_result_t(nullptr);
}

void audio::graph::stop() {
    if (auto const &graph_io = this->_io) {
        manageable_graph_io::cast(graph_io.value())->raw_io()->stop();
    }
}

bool audio::graph::is_running() const {
    if (auto const &io = this->_io) {
        return io.value()->raw_io()->is_running();
    } else {
        return false;
    }
}

std::unordered_set<audio::graph_node_ptr> const &audio::graph::nodes() const {
    return this->_nodes;
}

audio::graph_connection_set const &audio::graph::connections() const {
    return this->_connections;
}

void audio::graph::_prepare(graph_ptr const &shared) {
    this->_weak_graph = shared;
}

bool audio::graph::_node_exists(audio::graph_node_ptr const &node) {
    return this->_nodes.count(node) > 0;
}

void audio::graph::_attach_node(audio::graph_node_ptr const &node) {
    if (this->_nodes.count(node) > 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is already attached.");
    }

    this->_nodes.insert(node);

    manageable_graph_node::cast(node)->set_graph(this->_weak_graph);

    this->_setup_node(node);
}

void audio::graph::_detach_node(audio::graph_node_ptr const &node) {
    if (this->_nodes.count(node) == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
    }

    this->_disconnect_node_with_predicate([&node](graph_connection const &connection) {
        return (connection.destination_node() == node || connection.source_node() == node);
    });

    this->_teardown_node(node);

    manageable_graph_node::cast(node)->set_graph(graph_ptr{nullptr});

    this->_nodes.erase(node);
}

void audio::graph::_detach_node_if_unused(audio::graph_node_ptr const &node) {
    auto filtered_connection = filter(_connections, [&node](auto const &connection) {
        return (connection->destination_node() == node || connection->source_node() == node);
    });

    if (filtered_connection.size() == 0) {
        this->_detach_node(node);
    }
}

bool audio::graph::_setup_rendering() {
    for (auto &node : this->_nodes) {
        this->_setup_node(node);
    }

    for (auto const &connection : this->_connections) {
        if (!this->_add_connection_to_nodes(connection)) {
            return false;
        }
    }

    this->_update_io_rendering();

    return true;
}

void audio::graph::_dispose_rendering() {
    if (auto const &graph_io = this->_io) {
        manageable_graph_io::cast(graph_io.value())->raw_io()->stop();
    }

    for (auto const &connection : this->_connections) {
        this->_remove_connection_from_nodes(connection);
    }

    for (auto &node : this->_nodes) {
        this->_teardown_node(node);
    }

    this->_update_io_rendering();
}

void audio::graph::_disconnect_node_with_predicate(std::function<bool(graph_connection const &)> predicate) {
    auto connections =
        filter(this->_connections, [&predicate](auto const &connection) { return predicate(*connection); });

    graph_node_set update_nodes;

    for (auto connection : connections) {
        update_nodes.insert(connection->source_node());
        update_nodes.insert(connection->destination_node());
        this->_remove_connection_from_nodes(connection);
        audio::graph_node_removable::cast(connection)->remove_nodes();
    }

    for (auto node : update_nodes) {
        this->_detach_node_if_unused(node);
    }

    for (auto &connection : connections) {
        this->_connections.erase(connection);
    }
    
    if (this->is_running()) {
        this->_update_io_rendering();
    }
}

void audio::graph::_setup_node(audio::graph_node_ptr const &node) {
    if (auto const &handler = manageable_graph_node::cast(node)->setup_handler()) {
        handler();
    }
}

void audio::graph::_teardown_node(audio::graph_node_ptr const &node) {
    if (auto const &handler = manageable_graph_node::cast(node)->teardown_handler()) {
        handler();
    }
}

bool audio::graph::_add_connection_to_nodes(audio::graph_connection_ptr const &connection) {
    auto destination_node = connection->destination_node();
    auto source_node = connection->source_node();

    if (this->_nodes.count(destination_node) == 0 || this->_nodes.count(source_node) == 0) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
        return false;
    }

    connectable_graph_node::cast(destination_node)->add_connection(connection);
    connectable_graph_node::cast(source_node)->add_connection(connection);

    return true;
}

void audio::graph::_remove_connection_from_nodes(audio::graph_connection_ptr const &connection) {
    if (auto source_node = connection->source_node()) {
        connectable_graph_node::cast(source_node)->remove_output_connection(connection->source_bus());
    }

    if (auto destination_node = connection->destination_node()) {
        connectable_graph_node::cast(destination_node)->remove_input_connection(connection->destination_bus());
    }
}

audio::graph_connection_set audio::graph::_input_connections_for_destination_node(audio::graph_node_ptr const &node) {
    return filter(this->_connections,
                  [&node](auto const &connection) { return connection->destination_node() == node; });
}

audio::graph_connection_set audio::graph::_output_connections_for_source_node(audio::graph_node_ptr const &node) {
    return filter(this->_connections, [&node](auto const &connection) { return connection->source_node() == node; });
}

void audio::graph::_update_io_rendering() {
    if (this->_io.has_value()) {
        audio::manageable_graph_io::cast(this->_io.value())->update_rendering();
    }
}

audio::graph_ptr audio::graph::make_shared() {
    auto shared = graph_ptr(new graph{});
    shared->_prepare(shared);
    return shared;
}

std::string yas::to_string(audio::graph::start_error_t const &error) {
    switch (error) {
        case audio::graph::start_error_t::already_running:
            return "already_running";
        case audio::graph::start_error_t::prepare_failure:
            return "prepare_failure";
        case audio::graph::start_error_t::connection_not_found:
            return "connection_not_found";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::graph::start_error_t const &value) {
    os << to_string(value);
    return os;
}
