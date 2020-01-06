//
//  yas_audio_engine.cpp
//

#include "yas_audio_engine_manager.h"
#include <AVFoundation/AVFoundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <cpp_utils/yas_result.h>
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_engine_io.h"
#include "yas_audio_engine_node.h"
#include "yas_audio_io.h"

#if TARGET_OS_IPHONE
#include "yas_audio_ios_device.h"
#elif TARGET_OS_MAC
#include "yas_audio_mac_device.h"
#endif

using namespace yas;

#pragma mark - audio::engine::manager

audio::engine::manager::manager() = default;

audio::engine::manager::~manager() = default;

audio::engine::connection_ptr audio::engine::manager::connect(audio::engine::node_ptr const &source_node,
                                                              audio::engine::node_ptr const &destination_node,
                                                              audio::format const &format) {
    auto source_bus_result = source_node->next_available_output_bus();
    auto destination_bus_result = destination_node->next_available_input_bus();

    if (!source_bus_result || !destination_bus_result) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : bus is not available.");
    }

    return connect(source_node, destination_node, *source_bus_result, *destination_bus_result, format);
}

audio::engine::connection_ptr audio::engine::manager::connect(audio::engine::node_ptr const &src_node,
                                                              audio::engine::node_ptr const &dst_node,
                                                              uint32_t const src_bus_idx, uint32_t const dst_bus_idx,
                                                              audio::format const &format) {
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

    auto connection = connection::make_shared(src_node, src_bus_idx, dst_node, dst_bus_idx, format);

    this->_connections.insert(connection);

    if (this->is_running()) {
        this->_add_connection_to_nodes(connection);
        this->_update_node_connections(src_node);
        this->_update_node_connections(dst_node);
    }

    return connection;
}

void audio::engine::manager::disconnect(connection_ptr const &connection) {
    std::vector<node_ptr> update_nodes{connection->source_node(), connection->destination_node()};

    this->_remove_connection_from_nodes(connection);
    connection->removable()->remove_nodes();

    for (auto &node : update_nodes) {
        manageable_node::cast(node)->update_connections();
        this->_detach_node_if_unused(node);
    }

    this->_connections.erase(connection);
}

void audio::engine::manager::disconnect(audio::engine::node_ptr const &node) {
    if (this->_node_exists(node)) {
        this->_detach_node(node);
    }
}

void audio::engine::manager::disconnect_input(audio::engine::node_ptr const &node) {
    this->_disconnect_node_with_predicate(
        [&node](connection const &connection) { return (connection.destination_node() == node); });
}

void audio::engine::manager::disconnect_input(audio::engine::node_ptr const &node, uint32_t const bus_idx) {
    this->_disconnect_node_with_predicate([&node, bus_idx](auto const &connection) {
        return (connection.destination_node() == node && connection.destination_bus == bus_idx);
    });
}

void audio::engine::manager::disconnect_output(audio::engine::node_ptr const &node) {
    this->_disconnect_node_with_predicate(
        [&node](connection const &connection) { return (connection.source_node() == node); });
}

void audio::engine::manager::disconnect_output(audio::engine::node_ptr const &node, uint32_t const bus_idx) {
    this->_disconnect_node_with_predicate([&node, bus_idx](auto const &connection) {
        return (connection.source_node() == node && connection.source_bus == bus_idx);
    });
}

audio::engine::io_ptr const &audio::engine::manager::add_io(std::optional<io_device_ptr> const &device) {
    if (!this->_io) {
        audio::io_ptr const raw_io = audio::io::make_shared(device);
        audio::engine::io_ptr const io = audio::engine::io::make_shared(raw_io);

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

void audio::engine::manager::remove_io() {
    if (this->_io) {
        this->_io_observer = std::nullopt;
        this->_io = std::nullopt;
    }
}

std::optional<audio::engine::io_ptr> const &audio::engine::manager::io() const {
    return this->_io;
}

audio::engine::manager::start_result_t audio::engine::manager::start_render() {
    if (this->is_running()) {
        return start_result_t(start_error_t::already_running);
    }

    if (auto const &engine_io = this->_io) {
        engine::manageable_io::cast(engine_io.value())->raw_io()->start();
    }

    return start_result_t(nullptr);
}

void audio::engine::manager::stop() {
    if (auto const &engine_io = this->_io) {
        engine::manageable_io::cast(engine_io.value())->raw_io()->stop();
    }
}

bool audio::engine::manager::is_running() const {
    if (auto const &io = this->_io) {
        return io.value()->raw_io()->is_running();
    } else {
        return false;
    }
}

std::unordered_set<audio::engine::node_ptr> const &audio::engine::manager::nodes() const {
    return this->_nodes;
}

audio::engine::connection_set const &audio::engine::manager::connections() const {
    return this->_connections;
}

void audio::engine::manager::_prepare(manager_ptr const &shared) {
    this->_weak_manager = shared;
}

bool audio::engine::manager::_node_exists(audio::engine::node_ptr const &node) {
    return this->_nodes.count(node) > 0;
}

void audio::engine::manager::_attach_node(audio::engine::node_ptr const &node) {
    if (this->_nodes.count(node) > 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is already attached.");
    }

    this->_nodes.insert(node);

    manageable_node::cast(node)->set_manager(this->_weak_manager);

    this->_setup_node(node);
}

void audio::engine::manager::_detach_node(audio::engine::node_ptr const &node) {
    if (this->_nodes.count(node) == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
    }

    this->_disconnect_node_with_predicate([&node](connection const &connection) {
        return (connection.destination_node() == node || connection.source_node() == node);
    });

    this->_teardown_node(node);

    manageable_node::cast(node)->set_manager(manager_ptr{nullptr});

    this->_nodes.erase(node);
}

void audio::engine::manager::_detach_node_if_unused(audio::engine::node_ptr const &node) {
    auto filtered_connection = filter(_connections, [&node](auto const &connection) {
        return (connection->destination_node() == node || connection->source_node() == node);
    });

    if (filtered_connection.size() == 0) {
        this->_detach_node(node);
    }
}

bool audio::engine::manager::_setup_rendering() {
    for (auto &node : this->_nodes) {
        this->_setup_node(node);
    }

    for (auto const &connection : this->_connections) {
        if (!this->_add_connection_to_nodes(connection)) {
            return false;
        }
    }

    this->_update_all_node_connections();

    return true;
}

void audio::engine::manager::_dispose_rendering() {
    if (auto const &engine_io = this->_io) {
        engine::manageable_io::cast(engine_io.value())->raw_io()->stop();
    }

    for (auto const &connection : this->_connections) {
        this->_remove_connection_from_nodes(connection);
    }

    for (auto &node : this->_nodes) {
        this->_teardown_node(node);
    }

    this->_update_all_node_connections();
}

void audio::engine::manager::_disconnect_node_with_predicate(std::function<bool(connection const &)> predicate) {
    auto connections =
        filter(this->_connections, [&predicate](auto const &connection) { return predicate(*connection); });

    std::unordered_set<node_ptr> update_nodes;

    for (auto connection : connections) {
        update_nodes.insert(connection->source_node());
        update_nodes.insert(connection->destination_node());
        this->_remove_connection_from_nodes(connection);
        connection->removable()->remove_nodes();
    }

    for (auto node : update_nodes) {
        manageable_node::cast(node)->update_connections();
        this->_detach_node_if_unused(node);
    }

    for (auto &connection : connections) {
        this->_connections.erase(connection);
    }
}

void audio::engine::manager::_setup_node(audio::engine::node_ptr const &node) {
    if (auto const &handler = manageable_node::cast(node)->setup_handler()) {
        handler();
    }
}

void audio::engine::manager::_teardown_node(audio::engine::node_ptr const &node) {
    if (auto const &handler = manageable_node::cast(node)->teardown_handler()) {
        handler();
    }
}

bool audio::engine::manager::_add_connection_to_nodes(audio::engine::connection_ptr const &connection) {
    auto destination_node = connection->destination_node();
    auto source_node = connection->source_node();

    if (this->_nodes.count(destination_node) == 0 || this->_nodes.count(source_node) == 0) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
        return false;
    }

    connectable_node::cast(destination_node)->add_connection(connection);
    connectable_node::cast(source_node)->add_connection(connection);

    return true;
}

void audio::engine::manager::_remove_connection_from_nodes(audio::engine::connection_ptr const &connection) {
    if (auto source_node = connection->source_node()) {
        connectable_node::cast(source_node)->remove_output_connection(connection->source_bus);
    }

    if (auto destination_node = connection->destination_node()) {
        connectable_node::cast(destination_node)->remove_input_connection(connection->destination_bus);
    }
}

void audio::engine::manager::_update_node_connections(audio::engine::node_ptr const &node) {
    manageable_node::cast(node)->update_connections();
}

void audio::engine::manager::_update_all_node_connections() {
    for (auto node : this->_nodes) {
        manageable_node::cast(node)->update_connections();
    }
}

audio::engine::connection_set audio::engine::manager::_input_connections_for_destination_node(
    audio::engine::node_ptr const &node) {
    return filter(this->_connections,
                  [&node](auto const &connection) { return connection->destination_node() == node; });
}

audio::engine::connection_set audio::engine::manager::_output_connections_for_source_node(
    audio::engine::node_ptr const &node) {
    return filter(this->_connections, [&node](auto const &connection) { return connection->source_node() == node; });
}

audio::engine::manager_ptr audio::engine::manager::make_shared() {
    auto shared = manager_ptr(new manager{});
    shared->_prepare(shared);
    return shared;
}

std::string yas::to_string(audio::engine::manager::start_error_t const &error) {
    switch (error) {
        case audio::engine::manager::start_error_t::already_running:
            return "already_running";
        case audio::engine::manager::start_error_t::prepare_failure:
            return "prepare_failure";
        case audio::engine::manager::start_error_t::connection_not_found:
            return "connection_not_found";
        case audio::engine::manager::start_error_t::offline_output_not_found:
            return "offline_output_not_found";
        case audio::engine::manager::start_error_t::offline_output_starting_failure:
            return "offline_output_starting_failure";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::engine::manager::start_error_t const &value) {
    os << to_string(value);
    return os;
}
